---
id: TASK-010.02
title: Port .gob sprite format reader/writer to Zig
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
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
- [ ] #1 The Zig reader decodes rabbit.gob, objects.gob, numbers.gob, and font.gob identically to register_gob (dimensions, hotspots, pixel data)
- [ ] #2 A writer round-trips: encoding then decoding a .gob produces the same image data and hotspots
- [ ] #3 Hotspot blit-position math is unit tested against known values from at least one real sprite
<!-- AC:END -->
