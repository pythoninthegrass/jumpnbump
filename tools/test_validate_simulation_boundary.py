#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///

"""
Self-check for tools/validate_simulation_boundary.py (TASK-011.08).

Runs the boundary scanner over in-memory fixtures instead of the repo: one
fixture per rule that must fail, and one clean fixture that proves the
event-classification naming this project deliberately keeps (sfxAt, sfxRecordZ,
sfxCountZ, sfxReset, sfx_trace_z, EventKind.sfx) is not flagged. Keeping the
expectations here means a denylist edit that stops catching real audio or
presentation surface fails loudly, and so does one that starts flagging the
event stream.

The clean fixture doubles as AC#2's machine-checkable statement: it is the
shape core/ is required to have, and the scanner says it is clean.

Usage: uv run --script tools/test_validate_simulation_boundary.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_simulation_boundary as boundary

SIM_ROOT = Path("/fake/core")

# Each entry: (label, source, expected rule kind or None for clean).
MUST_FAIL = [
    (
        "dj_play_sfx call",
        "pub fn jump() void {\n    dj_play_sfx(SFX_JUMP, 15000, 1000, 0, 0, -1);\n}\n",
        "audio",
    ),
    (
        "dj_set_sfx_channel_volume call",
        "pub fn swarm(n: c_int) void {\n    dj_set_sfx_channel_volume(4, @truncate(n));\n}\n",
        "audio",
    ),
    (
        "dj_* mixer init",
        "pub fn boot() void {\n    dj_init();\n}\n",
        "audio",
    ),
    (
        "Mix_* call",
        "pub fn music() c_int {\n    return Mix_PlayMusic(track, -1);\n}\n",
        "audio",
    ),
    (
        "sdl/sound.c mixer internal",
        "pub fn tick() void {\n    mix_sound(null, stream, len);\n}\n",
        "audio",
    ),
    (
        "add_pob call",
        "pub fn draw(o: *Object) void {\n    add_pob(null, o.x, o.y, o.image, null);\n}\n",
        "presentation",
    ),
    (
        "add_pobs call",
        "pub fn draw() void {\n    add_pobs(page, n);\n}\n",
        "presentation",
    ),
    (
        "draw_pobs call",
        "pub fn frame() void {\n    draw_pobs(main_info.draw_page);\n}\n",
        "presentation",
    ),
    (
        "flippage call",
        "pub fn present() void {\n    flippage(view);\n}\n",
        "presentation",
    ),
    (
        "page_info access",
        "pub fn count() c_int {\n    return page_info(0).num_pobs;\n}\n",
        "presentation",
    ),
    (
        "put_text call",
        "pub fn hud() void {\n    put_text(page, 360, 8, text, 1);\n}\n",
        "presentation",
    ),
    (
        "recalculate_gob call",
        "pub fn pal(p: []const u8) void {\n    recalculate_gob(gob, p);\n}\n",
        "presentation",
    ),
    (
        "extern fn declaration",
        "extern fn add_leftovers(which: c_int, x: c_int, y: c_int, frame: c_int, gobs: ?*anyopaque) void;\n",
        "presentation",
    ),
    (
        "@export of a draw name",
        'comptime {\n    @export(&noop, .{ .name = "add_pob" });\n}\n',
        "presentation",
    ),
    (
        "libc stdio",
        "pub fn read() void {\n    const f = fopen(path, \"rb\");\n}\n",
        "file I/O",
    ),
    (
        "Zig Filesystem API",
        "pub fn read() void {\n    const d = std.fs.cwd();\n}\n",
        "file I/O",
    ),
    (
        "Zig Dir open",
        "pub fn read() void {\n    const f = std.Io.Dir.cwd();\n}\n",
        "file I/O",
    ),
    (
        "Dir.readFileAlloc",
        "pub fn read() void {\n    const b = dir.readFileAlloc(io, p, gpa, .unlimited);\n}\n",
        "file I/O",
    ),
    (
        "banned C header",
        'const c = @cImport({\n    @cInclude("stdio.h")\n});\n',
        "file I/O",
    ),
]

# The TASK-011.07 event stream: named after what the C fired at the same moment,
# with the audio call itself dropped. None of this may be flagged.
CLEAN = """// The dj_play_sfx() call sites are where the checksummed rnd() draws happen, so
// sfxAt() evaluates the same frequency expression and drops the audio result;
// flippage(), add_pob() and put_text() stay in the renderer.
const sfx_jump: c_int = 1;
const sfx_death_freq: c_int = 20000;
pub var sfx_trace_z: [512]c_int = .{0} ** 512;

pub const EventKind = enum(c_int) {
    sfx = 1,
    object_spawn = 2,
};

inline fn sfxAt(id: c_int, freq_base: c_int, cut: c_int) void {
    const freq: c_ushort = @truncate(freq_base +% rnd(2000) -% cut);
    sfxRecordZ(id, freq);
}

extern fn sfxRecordZ(id: c_int, freq: c_int) void;
extern fn sfxResetZ() void;

pub fn sfxReset() void {
    sfx_n_z = 0;
}

pub fn sfxCountZ() usize {
    return sfx_n_z;
}

pub fn drain(events: *Events) void {
    for (0..sfxCountZ()) |i| {
        events.push(.{ .kind = .sfx, .a = sfx_trace_z[i] });
    }
    sfxReset();
}

var sfx_n_z: usize = 0;
"""


def scan_source(source: str, *, io_allowed: bool = False) -> list[str]:
    return boundary.scan(SIM_ROOT / "probe.zig", boundary.strip_comments(source), io_allowed=io_allowed)


def main() -> int:
    failures: list[str] = []

    for label, source, expected in MUST_FAIL:
        hits = scan_source(source)
        kinds = [kind for kind, _ in boundary.RULES if any(violation.startswith(f"{SIM_ROOT}/probe.zig") and kind in violation for violation in hits)]
        if not hits:
            failures.append(f"{label}: expected a {expected!r} violation, scanner found none")
        elif expected not in kinds:
            failures.append(f"{label}: expected {expected!r}, got {kinds}")

    clean_hits = scan_source(CLEAN)
    if clean_hits:
        failures.append("clean event-stream fixture: expected no violations, got:")
        failures.extend(f"  {hit}" for hit in clean_hits)

    # The asset-loading carve-out exists for file I/O only — an audio or
    # presentation call inside dat.zig must still fail.
    io_ok = scan_source("pub fn load() void {\n    _ = fopen(p, \"rb\");\n}\n", io_allowed=True)
    if io_ok:
        failures.append("dat.zig-equivalent (io_allowed): file I/O should be permitted")
    audio_in_loader = scan_source("pub fn load() void {\n    dj_play_sfx(1, 2, 3, 0, 0, 0);\n}\n", io_allowed=True)
    if not audio_in_loader:
        failures.append("dat.zig-equivalent (io_allowed): audio call must still fail")

    for failure in failures:
        print(failure, file=sys.stderr)
    if failures:
        print(f"{len(failures)} boundary self-check failure(s)", file=sys.stderr)
        return 1

    print(f"boundary self-check: {len(MUST_FAIL)} denylist cases caught, event-stream naming clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
