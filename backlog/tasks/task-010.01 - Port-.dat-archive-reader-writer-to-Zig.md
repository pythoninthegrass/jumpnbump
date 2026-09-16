---
id: TASK-010.01
title: Port .dat archive reader/writer to Zig
status: Done
assignee: []
created_date: '2026-09-15 19:14'
updated_date: '2026-09-16 16:03'
labels: []
milestone: m-2
dependencies: []
parent_task_id: TASK-010
priority: high
type: task
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port the .dat archive format to Zig: u32 entry count, entries of {char[12] name, u32 offset, u32 size}, followed by concatenated payloads, with transparent gzip/bzip2 decompression of the outer file. Preserve the prefix-match lookup behavior of dat_open (strnicmp against strlen(file_name), not equality) bug-for-bug, since real .dat files and menu.c depend on it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The Zig reader opens data/jumpbump.dat and returns byte-identical payloads to dat_open/dat_filelen for every named entry
- [x] #2 The prefix-match lookup quirk (querying "menu" can match "menumask.pcx") is preserved and covered by a test
- [x] #3 gzip and bzip2 outer-file decompression both work
- [x] #4 A writer can round-trip: pack then unpack produces byte-identical files to the C jnbpack output
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ported the .dat archive format (main.c dat_open/dat_filelen, modify/jnbpack.c, modify/jnbunpack.c) to core/dat.zig.

- find()/open()/filelen() replicate dat_open/dat_filelen's linear scan and the case-insensitive PREFIX-match quirk (strnicmp against strlen(file_name)) bug-for-bug — covered by a unit test and verified against the real data/jumpbump.dat ("menu" resolves to the same entry as "menu.pcx").
- pack() reproduces modify/jnbpack.c's directory-then-payload layout byte-for-byte: verified by packing all 18 files in data/'s DATAFILES list and diffing against the shipped data/jumpbump.dat (367,799 bytes, identical).
- unpack() round-trips every entry in the packed archive byte-identically back to the original source files (verified against real data/ assets, not just synthetic fixtures).
- loadDatafile() transparently decompresses a .bz2 or .gz outer file (probed in that order, matching main.c's BZLIB_SUPPORT/ZLIB_SUPPORT order) via libbz2 (BZ2_bzBuffToBuffDecompress, cImport'd) and std.compress.flate (gzip container); both paths are unit tested with real compressed fixtures, plus a "prefers .bz2 over the plain sibling" test.

Zig 0.16's new std.Io/std.Io.Dir API (dir/io-parameterized file ops, no more bare std.fs.cwd()) required loadDatafile to take an explicit `io: std.Io, dir: std.Io.Dir` rather than reaching for a global cwd — this also made it trivially testable against std.testing.tmpDir instead of the real filesystem.

All of `zig build test`, `difftest`, `abi`, `abitest`, and `zig fmt --check .` pass; the legacy `make` build is untouched (no .c files modified).
<!-- SECTION:FINAL_SUMMARY:END -->
