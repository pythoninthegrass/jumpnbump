#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///

"""
Converts the raw .smp sound effects (death, fly, jump, splash, spring) into
WAV files Godot's res:// filesystem can load directly (TASK-013.03).

A .smp file is not a container format -- it's the exact bytes sdl/sound.c's
dj_load_sfx() malloc/memcpy's wholesale into its playback buffer, reinterpreted
in place as little-endian 16-bit signed mono PCM samples (dj_load_sfx's
byte-shuffle loop, `temp = src[0] + (src[1] << 8)`, is a no-op on a
little-endian host, which is what every original DOS/SDL build target was --
so the file bytes already *are* the sample data, no header to skip). Sample
count is `file_length / 2`, truncating any trailing odd byte exactly like the
original.

Playback sample rate is not stored in the file; sdl/sound.c passes a fixed
per-effect rate into dj_play_sfx()'s `addsfx(...)` (globals.h's SFX_*_FREQ
constants). The random +-1000Hz pitch jitter main.c applies at each call site
(`SFX_JUMP_FREQ + rnd(2000) - 1000`) is a runtime gameplay effect, not part of
the source asset, so it is not reproduced here -- the committed WAV is
authored at the base frequency.
"""

import argparse
import struct
import sys
import wave
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data"
OUT_DIR = REPO_ROOT / "game" / "content" / "audio" / "sfx"

# globals.h SFX_*_FREQ (SFX_LAND_FREQ has no corresponding .smp asset).
SFX_FREQS = {
    "jump": 15000,
    "death": 20000,
    "spring": 15000,
    "splash": 12000,
    "fly": 12000,
}


def smp_to_wav_bytes(smp_bytes: bytes, sample_rate: int) -> bytes:
    sample_count = len(smp_bytes) // 2
    samples = struct.unpack(f"<{sample_count}h", smp_bytes[: sample_count * 2])

    import io

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(struct.pack(f"<{sample_count}h", *samples))
    return buf.getvalue()


def render_all(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, freq in SFX_FREQS.items():
        smp_bytes = (DATA_DIR / f"{name}.smp").read_bytes()
        wav_bytes = smp_to_wav_bytes(smp_bytes, freq)
        (out_dir / f"{name}.wav").write_bytes(wav_bytes)
        print(f"render_sfx: wrote {name}.wav ({freq} Hz, {len(wav_bytes)} bytes)")


def check_all(committed_dir: Path) -> int:
    failures = []
    for name, freq in SFX_FREQS.items():
        smp_path = DATA_DIR / f"{name}.smp"
        wav_bytes = smp_to_wav_bytes(smp_path.read_bytes(), freq)
        committed_path = committed_dir / f"{name}.wav"
        if not committed_path.exists():
            failures.append(
                f"{committed_path} does not exist (run `tools/render_sfx.py --all` and commit it)"
            )
            continue
        if wav_bytes != committed_path.read_bytes():
            failures.append(
                f"{committed_path} does not match a fresh render of {smp_path}"
            )
    if failures:
        print("render_sfx: check FAILED", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    print(f"render_sfx: {len(SFX_FREQS)} sfx match a fresh render byte-for-byte")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--all", action="store_true", help="render every .smp under data/"
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="diff fresh renders against --out-dir instead of writing",
    )
    parser.add_argument("--out-dir", type=Path, default=OUT_DIR)
    args = parser.parse_args()

    if not args.all:
        parser.error("--all is required (there is no single-file mode)")

    if args.check:
        return check_all(args.out_dir)
    render_all(args.out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
