---
id: TASK-013.01
title: 'Build sprite atlas pipeline: .gob + palette to PNG/AtlasTexture'
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-013
priority: high
type: task
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Using the Zig .gob and PCX codecs from Phase 2, build a tools/ pipeline script that converts rabbit.gob, objects.gob, numbers.gob, and font.gob (with their associated palettes) into PNG sprite atlases and Godot AtlasTexture resources, preserving each sprite's hotspot and the hardcoded colour*18 + direction*9 frame-indexing scheme. This is genuinely new work — unlike neo_snake, which has no textures or atlas pipeline at all, being 100% immediate-mode Control._draw().
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Running the pipeline produces one PNG atlas plus AtlasTexture .tres resources per source .gob, committed under game/content/
- [ ] #2 Hotspot offsets are preserved in the generated resources or an accompanying metadata file, verified against known values from register_gob
- [ ] #3 Regenerating the atlases twice from the same source produces byte-identical PNGs (a --check gate)
- [ ] #4 The colour*18+direction*9 sprite index math is documented alongside the generated atlas so the Godot renderer can reproduce it
<!-- AC:END -->
