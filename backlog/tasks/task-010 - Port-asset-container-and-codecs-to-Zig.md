---
id: TASK-010
title: Port asset container and codecs to Zig
status: Done
assignee: []
created_date: '2026-09-15 19:13'
updated_date: '2026-09-16 16:13'
labels: []
milestone: m-2
dependencies: []
priority: high
type: task
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task. Port the .dat archive format, the .gob sprite format, 8-bit PCX decoding, and levelmap.txt parsing from C (main.c, sdl/gfx.c, modify/) to Zig, preserving every quirk of the original formats bug-for-bug so existing data files and any future user-created .dat files remain compatible. Reimplement the jnbpack/jnbunpack/gobpack CLI tools in Zig, verified byte-identical to the current C tools' output on the existing data/ assets. Depends on Phase 1 (the C oracle) being complete — do not start until all Phase 1 tasks are Done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All five subtasks are complete
- [x] #2 The Zig-built jnbpack/jnbunpack/gobpack produce byte-identical output to the C tools on all files in data/
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All five subtasks complete: .dat archive (core/dat.zig, TASK-010.01), .gob sprite format (core/gob.zig, TASK-010.02), 8-bit PCX (core/pcx.zig, TASK-010.03), levelmap.txt parser (core/levelmap.zig, TASK-010.04), and Zig rewrites of jnbpack/jnbunpack/gobpack (TASK-010.05).

Every codec was verified byte-identical against the real assets in data/ (not just synthetic fixtures): packing/unpacking jumpbump.dat's 18 entries, decoding all four .gob sprite sheets and all 8 PCX files (cross-checked against independent Python re-implementations), parsing the real levelmap.txt, and — the AC#2 gate — running the Zig-built jnbpack/gobpack CLIs against data/'s files reproduces byte-identical output to the C tools (rebuilt fresh from modify/*.c for the comparison).

modify/*.c, main.c, and sdl/gfx.c are all untouched — they remain the Tier-B/oracle reference per docs/porting-playbook.md. `zig build test`, `difftest`, `abi`, `abitest`, and `zig fmt --check .` all pass throughout core/.
<!-- SECTION:FINAL_SUMMARY:END -->
