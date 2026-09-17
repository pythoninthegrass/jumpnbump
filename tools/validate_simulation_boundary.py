#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///

"""
Fails if the Zig simulation core references a presentation or audio API, or
does file I/O outside the asset-loading paths (TASK-011.08): core/ must stay a
pure, deterministic state machine that produces an inert event stream instead
of touching a renderer, a mixer or a filesystem.

The denylists are concrete API surface, not blanket word matches. core/steer.zig,
core/collision.zig and core/game_loop.zig name their event classes after the
thing the C fired at the same moment (sfxAt, sfxRecordZ, sfxCountZ, sfxReset,
sfx_trace_z, EventKind.sfx) while keeping the checksummed rnd() draw and dropping
the audio call itself — those identifiers are the pure design this check protects,
so no bare "sfx"/"audio"/"sound"/"music" token is banned anywhere.

Comments are stripped before scanning (block and line comments), and a violation
is reported only when the banned name is followed by "(" or ".*(" — a call site,
a declaration, or an @export of that exact name. Documentation that names
add_pob() or flippage() as the concept a port deliberately drops stays readable
without tripping the check.

File I/O is banned outright in core/ except in the asset-loading paths
(IO_ALLOWLIST); the asset pipeline's own CLIs live in core/ but out of the
simulation, so they are scanned like any other file minus the I/O rule.
core/c_ref/ is exempt entirely: it is the C oracle extracted from main.c, and
relaxing the rule there is what keeps the differential honest.
"""

import re
import sys
from collections.abc import Sequence
from pathlib import Path


def alternation(names: Sequence[str]) -> str:
    # Longest-first so a prefix name (add_pob) can't shadow the longer one
    # (add_pobs) it would otherwise match as a substring.
    return "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True))

REPO_ROOT = Path(__file__).resolve().parent.parent
CORE_DIR = REPO_ROOT / "core"

# Audio API surface: main.c's dj_* layer (sdl/sound.c) and the SDL_mixer
# functions underneath it, every one of them named in main.c/menu.c/
# fireworks.c/sdl/*.c. The bare words sfx/audio/sound/music are not banned at
# all — that is the event-classification naming this check exists to protect.
AUDIO_NAMES = [
    "addsfx",
    "mix_sound",
    "dj_autodetect_sd",
    "dj_deinit",
    "dj_free_mod",
    "dj_free_sfx",
    "dj_get_sfx_settings",
    "dj_init",
    "dj_load_mod",
    "dj_load_sfx",
    "dj_mix",
    "dj_play_sfx",
    "dj_ready_mod",
    "dj_set_auto_mix",
    "dj_set_dma_time",
    "dj_set_mixing_freq",
    "dj_set_mod_volume",
    "dj_set_nosound",
    "dj_set_num_sfx_channels",
    "dj_set_sfx_channel_volume",
    "dj_set_sfx_settings",
    "dj_set_sfx_volume",
    "dj_set_stereo",
    "dj_start",
    "dj_start_mod",
    "dj_stop",
    "dj_stop_mod",
    "dj_stop_sfx_channel",
    "Mix_CloseAudio",
    "Mix_FadeOutMusic",
    "Mix_FreeMusic",
    "Mix_HaltMusic",
    "Mix_LoadMUS",
    "Mix_Music",
    "Mix_OpenAudio",
    "Mix_PlayingMusic",
    "Mix_PlayMusic",
    "Mix_QuerySpec",
    "Mix_SetMusicCMD",
    "Mix_SetPostMix",
    "Mix_VolumeMusic",
]

# Presentation API surface: sdl/gfx.c's draw/page/pob routines, the main_info
# page-flip bookkeeping they read, and the gob sprite handles they take.
# register_gob is absent on purpose — core/gob.zig is the asset-codec port of it.
PRESENTATION_NAMES = [
    "pob",
    "pobs",
    "num_pobs",
    "pob_data",
    "pob_ptr",
    "pob_x",
    "pob_y",
    "pob_backbuf",
    "add_pob",
    "add_pobs",
    "put_pob",
    "put_pobs",
    "add_leftovers",
    "draw_pobs",
    "draw_leftovers",
    "draw_flies",
    "draw_begin",
    "draw_end",
    "redraw_pob_backgrounds",
    "redraw_flies_background",
    "flippage",
    "open_screen",
    "page_info",
    "draw_page",
    "view_page",
    "main_info",
    "register_background",
    "register_mask",
    "recalculate_gob",
    "pob_width",
    "pob_height",
    "pob_hs_x",
    "pob_hs_y",
    "put_text",
    "put_block",
    "get_block",
    "clear_page",
    "set_pixel",
    "get_pixel",
    "get_vgaptr",
    "setpalette",
    "fillpalette",
    "wait_vrt",
]

# libc stdio, the Zig Filesystem API, and the C headers that declare them.
FILE_IO_NAMES = [
    "fopen",
    "freopen",
    "fdopen",
    "fread",
    "fwrite",
    "fclose",
    "fflush",
    "fseek",
    "ftell",
    "rewind",
    "tmpfile",
    "std.fs",
    "std.Io.File",
    "std.Io.Dir",
    "readFileAlloc",
    "writeFile",
    "writeFileAlloc",
    "std.os.getenv",
    "std.os.setenv",
    "std.os.argsAlloc",
    "std.os.args",
]

# A banned C header include has to name the header, not merely the word.
C_HEADER_INCLUDE_RE = re.compile(r"@cInclude\s*\(\s*\"(?:stdio|fcntl|unistd|sys/stat|io)\.h\"")

RULES: tuple[tuple[str, Sequence[str]], ...] = (
    ("audio", AUDIO_NAMES),
    ("presentation", PRESENTATION_NAMES),
    ("file I/O", FILE_IO_NAMES),
)

# Files whose file I/O is the point of the module: core/dat.zig is the .dat
# archive reader (data/jumpbump.dat plus the .bz2/.gz outer files), core/
# levelmap.zig the levelmap.txt reader, and core/*_cli.zig the asset packer
# CLIs. Nothing else in core/ may reach the filesystem.
IO_ALLOWLIST = frozenset({"dat.zig", "levelmap.zig"})
IO_ALLOWLIST_SUFFIX = "_cli.zig"

# The C oracle (verbatim main.c code with renamed entry points) is not the Zig
# simulation core and keeps the C's presentation and audio call sites.
EXCLUDE_DIRS = frozenset({"c_ref"})

# Tier-B differential harnesses and Tier-A link stubs: test code that binds the
# oracle's real dj_play_sfx/add_pob symbols on purpose, which is how the C
# reference and the Zig port stay wired to one link graph. `--sim-only` scopes the
# scan to the simulation modules themselves, which is where the purity rule bites;
# the default scan reports these too rather than hiding them.
HARNESS_SUFFIX = "_difftest.zig"
STUB_PREFIX = "unit_"

# Build artefacts under core/ (.zig-cache's @cImport output is a generated .zig
# file full of libc declarations) are sources of false positives, not of purity.
EXCLUDE_DIR_NAMES = frozenset({".zig-cache", "zig-out", "node_modules"})

BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
LINE_COMMENT_RE = re.compile(r"//.*")
# The two shapes that put a symbol into a module rather than merely talking
# about it: a call/declaration `name(`, and an @export of it by string name,
# `@export(&stub, .{ .name = "name" })`. Both are checked ahead of the name with
# a full-group lookahead, so they cannot be confused with the surrounding
# alternation (a suffix appended to an alternation binds inside it and silently
# leaves the shorter alternatives unmatchable).
CALL_OR_EXPORT_AHEAD = r"(?=\s*\(|\"\s*(?:,\s*\.|\}\s*\)))"


def rule_pattern(names: Sequence[str]) -> re.Pattern[str]:
    # Two branches, split by whether the name is dotted.
    #
    # A C-style name needs the call/export shape, so the scan reports API
    # surface instead of any identifier containing a banned word. It carries no
    # trailing \b: with `pob` listed, \b would make `add_pobs` and `draw_pobs`
    # unmatchable, since the `s` that makes those names real is exactly what a
    # \w boundary rejects. Alternation order (longest first) picks the name.
    #
    # A dotted Zig name (std.fs, std.Io.Dir) is already a member access, so its
    # usage reads `std.fs.cwd()` and no `(` ever follows the name itself — for
    # those, any code-token occurrence is the usage. Each is matched on its own
    # so its escaped `\.` delimits the branch; joining escaped dotted names into
    # one alternation lets an earlier branch run into a later name (the `\.` of
    # `std\.fs` would happily match the `.` before `fs`).
    plain = [n for n in names if "." not in n]
    dotted = [n for n in names if "." in n]
    parts = [rf"(?<!\w)(?:{alternation(plain)}){CALL_OR_EXPORT_AHEAD}"] if plain else []
    parts += [rf"(?<![\w.]){re.escape(n)}(?![\w])" for n in dotted]
    return re.compile("(?i)(?:" + "|".join(parts) + ")")


def strip_comments(text: str) -> str:
    # Block comments become the newlines they spanned so reported line numbers
    # still line up with the original file.
    text = BLOCK_COMMENT_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    return LINE_COMMENT_RE.sub("", text)


def scan(path: Path, code: str, *, io_allowed: bool) -> list[str]:
    patterns = [
        (kind, rule_pattern(names))
        for kind, names in RULES
        if not (kind == "file I/O" and io_allowed)
    ]
    violations = []
    for line_no, line in enumerate(code.splitlines(), start=1):
        for kind, pattern in patterns:
            match = pattern.search(line)
            if match:
                violations.append(f"{path}:{line_no}: {kind} reference {match.group(0).strip()!r}")
        if not io_allowed:
            header = C_HEADER_INCLUDE_RE.search(line)
            if header:
                violations.append(f"{path}:{line_no}: file I/O reference {header.group(0)!r}")
    return violations


def io_exempt(rel: Path) -> bool:
    return rel.name in IO_ALLOWLIST or rel.name.endswith(IO_ALLOWLIST_SUFFIX)


def scanned(path: Path) -> bool:
    if not path.is_file() or path.suffix not in {".zig", ".c", ".h"}:
        return False
    rel = path.relative_to(CORE_DIR)
    return not (EXCLUDE_DIRS | EXCLUDE_DIR_NAMES) & set(rel.parts)


def harness(rel: Path) -> bool:
    return rel.name.endswith(HARNESS_SUFFIX) or rel.name.startswith(STUB_PREFIX)


def sim_files() -> list[Path]:
    """core/ minus the oracle, the build cache, and the test harnesses/stubs."""
    return [p for p in CORE_DIR.rglob("*") if scanned(p) and not harness(p.relative_to(CORE_DIR))]


def scan_file(path: Path) -> list[str]:
    rel = path.relative_to(CORE_DIR)
    return scan(path, strip_comments(path.read_text()), io_allowed=io_exempt(rel))


def main(argv: list[str]) -> int:
    sim_only = "--sim-only" in argv
    files = sim_files() if sim_only else sorted(p for p in CORE_DIR.rglob("*") if scanned(p))

    violations: list[str] = []
    for path in files:
        violations.extend(scan_file(path))

    for violation in violations:
        print(violation, file=sys.stderr)

    scope = "core/ simulation modules" if sim_only else "core/ including test harnesses"
    if violations:
        print(
            f"{len(violations)} boundary violation(s) in {scope} — the sim must stay a pure "
            "state machine (docs/porting-playbook.md, Core purity)",
            file=sys.stderr,
        )
        return 1

    print(f"{scope}: clean across {len(files)} file(s) (TASK-011.08)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
