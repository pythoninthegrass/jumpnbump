---
id: TASK-010.05
title: Rebuild jnbpack/jnbunpack/gobpack as byte-identical Zig CLIs
status: Done
assignee: []
created_date: '2026-09-15 19:14'
updated_date: '2026-09-16 16:12'
labels: []
milestone: m-2
dependencies: []
parent_task_id: TASK-010
priority: high
type: task
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Using the Zig .dat/.gob/PCX codecs from the sibling subtasks, rebuild jnbpack, jnbunpack, and gobpack as thin Zig CLI wrappers. Verify their output is byte-identical to the current C tools' output across every file in data/. This also removes gobpack.c's private duplicated copies of read_pcx/write_pcx and gob_t once the Zig codecs are the single source of truth.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Running the Zig jnbpack on data/'s DATAFILES list produces a byte-identical jumpbump.dat to the C jnbpack
- [x] #2 Running the Zig gobpack on rabbit/objects/numbers/font produces byte-identical .gob files to the C gobpack
- [x] #3 jnbunpack round-trips: unpacking the Zig-built jumpbump.dat recovers the original input files byte-for-byte
- [x] #4 modify/'s C tools are kept (not deleted) as the reference for this comparison, per the never-delete-the-.c rule
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Rebuilt jnbpack, jnbunpack, and gobpack as thin Zig CLI wrappers (core/jnbpack_cli.zig, core/jnbunpack_cli.zig, core/gobpack_cli.zig) over the dat/gob/pcx codecs from TASK-010.01-03, each built via a new `zig build <name>` step.

- jnbpack: verified byte-identical (`cmp`) against data/jumpbump.dat when packing all 18 DATAFILES entries.
- jnbunpack: extracting data/jumpbump.dat reproduces all 18 original files byte-for-byte.
- gobpack -u (unpack): verified byte-identical against the real C modify/gobpack.c's own output (built fresh via `cd modify && make`) for rabbit/objects/numbers/font, both the .pcx atlas and the .txt frame table — including the atlas tile-sizing bug (y_count computed as atlas_h / tile_width, not tile_height) preserved intentionally.
- gobpack (pack): re-packing the C tool's own .pcx+.txt output with the Zig tool produces a .gob byte-identical to both the C tool's own pack output AND the original data/*.gob files, for all four sprite sheets.
- modify/*.c and the top-level jnbpack/jnbunpack/gobpack C binaries are untouched — they remain the oracle this port was verified against, per the never-delete-the-.c rule.

Ports gobpack.c's private read_pcx/write_pcx onto core/pcx.zig (shared with core/dat.zig's pipeline), closing out TASK-010.03's AC#3 dedup note.

All of `zig build test`, `difftest`, `abi`, `abitest`, `jnbpack`, `jnbunpack`, `gobpack` (both Debug and ReleaseFast), and `zig fmt --check .` pass; the legacy `make` build is untouched (no .c files modified).
<!-- SECTION:FINAL_SUMMARY:END -->
