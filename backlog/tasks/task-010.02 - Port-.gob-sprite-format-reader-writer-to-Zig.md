---
id: TASK-010.02
title: Port .gob sprite format reader/writer to Zig
status: Done
assignee: []
created_date: '2026-09-15 19:14'
updated_date: '2026-09-16 16:04'
labels: []
milestone: m-2
dependencies: []
parent_task_id: TASK-010
priority: high
type: task
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port the .gob format to Zig per gob.txt: u16 num_images, u32 offset[num_images], then per-image u16 width/height/hs_x/hs_y followed by an 8-bit paletted bitmap with color 0 as the transparent key. Preserve hotspot semantics (a sprite at (x,y) blits at (x - hs_x, y - hs_y)) exactly, since sprite positioning in the simulation depends on it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The Zig reader decodes rabbit.gob, objects.gob, numbers.gob, and font.gob identically to register_gob (dimensions, hotspots, pixel data)
- [x] #2 A writer round-trips: encoding then decoding a .gob produces the same image data and hotspots
- [x] #3 Hotspot blit-position math is unit tested against known values from at least one real sprite
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ported the .gob sprite format (sdl/gfx.c register_gob, modify/gobpack.c read_gob/write_gob) to core/gob.zig.

- decode() replicates register_gob's parsing (u16 num_images, u32 offset table, per-image u16 width/height/hs_x/hs_y read as *signed* 16-bit via the C `(short)` cast, then a width*height 8-bit paletted bitmap) and is verified byte-for-byte against data/rabbit.gob, objects.gob, numbers.gob, and font.gob (72/80/10/81 images respectively).
- encode() reproduces modify/gobpack.c's write_gob layout exactly — re-encoding the decoded images from all four real .gob files round-trips to output byte-identical to the original files, not just matching image data.
- blitPosition(x, y, hs_x, hs_y) = (x - hs_x, y - hs_y) is unit tested against data/rabbit.gob's real frame-0 hotspot (width=13 height=15 hs_x=-2 hs_y=-1, cross-checked with a Python struct.unpack_from read of the file), plus a synthetic positive-hotspot case.

Widths/heights/hotspots are stored as i16 (not u16) since register_gob's `(short)` cast means a hotspot can legitimately be negative — gob.txt/gobpack.c never surface this but the C code allows it, so the port preserves it rather than silently widening to unsigned.

All of `zig build test`, `difftest`, `abi`, `abitest`, and `zig fmt --check .` pass; no .c files modified.
<!-- SECTION:FINAL_SUMMARY:END -->
