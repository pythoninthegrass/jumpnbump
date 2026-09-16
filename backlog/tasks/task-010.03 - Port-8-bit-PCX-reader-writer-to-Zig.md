---
id: TASK-010.03
title: Port 8-bit PCX reader/writer to Zig
status: Done
assignee: []
created_date: '2026-09-15 19:14'
updated_date: '2026-09-16 16:06'
labels: []
milestone: m-2
dependencies: []
parent_task_id: TASK-010
priority: high
type: task
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port 8-bit paletted PCX decoding (and the encoding used by gobpack) to Zig, covering level.pcx, mask.pcx, menu.pcx, menumask.pcx, and the *.pcx/*.txt frame-table pairs in data/. This also lets gobpack's private, duplicated read_pcx/write_pcx implementation be replaced by one shared codec.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The Zig decoder produces identical pixel data and 768-byte palette to read_pcx for every PCX file in data/
- [x] #2 A round-trip encode/decode of a PCX produces pixel-identical output
- [ ] #3 gobpack's duplicated PCX code is noted as a future dedup target once the Zig CLI replacement lands
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ported 8-bit paletted PCX decoding/encoding (sdl/gfx.c read_pcx, modify/gobpack.c's private read_pcx/write_pcx) to core/pcx.zig — a single shared codec both the .dat pipeline and (eventually) TASK-010.05's gobpack rewrite converge on.

- decode() replicates read_pcx's RLE unpacking (top-two-bits-set byte = run count + value, otherwise literal) and its "skip the 128-byte header, then optionally skip a palette marker byte and right-shift every palette byte by 2 (VGA 6-bit DAC scaling)" behavior exactly.
- Verified against all 8 PCX files in data/ (level, mask, menu, menumask, rabbit, objects, numbers, font — all 400x256): decoded pixels+palette hashed with SHA-256 and cross-checked against an independent Python re-implementation of read_pcx's exact algorithm reading the same files. All 8 hashes match.
- encode() reproduces write_pcx's header layout and RLE-escaping rule (escape any literal byte whose top two bits are already set, not just runs). encode→decode round-trips pixel-identically for all 8 real files, plus synthetic edge cases (an all-0xc1 pixel that must itself be escaped).
- AC#3 (noting gobpack's duplicated PCX code as a future dedup target) is deferred to TASK-010.05, which is where gobpack is actually rebuilt against this codec.

All of `zig build test`, `difftest`, `abi`, `abitest`, and `zig fmt --check .` pass; no .c files modified.
<!-- SECTION:FINAL_SUMMARY:END -->
