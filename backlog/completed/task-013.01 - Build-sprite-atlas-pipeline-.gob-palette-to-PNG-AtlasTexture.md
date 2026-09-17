---
id: TASK-013.01
title: 'Build sprite atlas pipeline: .gob + palette to PNG/AtlasTexture'
status: Done
assignee: []
created_date: '2026-09-15 19:15'
updated_date: '2026-09-17 21:32'
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
- [x] #1 Running the pipeline produces one PNG atlas plus AtlasTexture .tres resources per source .gob, committed under game/content/
- [x] #2 Hotspot offsets are preserved in the generated resources or an accompanying metadata file, verified against known values from register_gob
- [x] #3 Regenerating the atlases twice from the same source produces byte-identical PNGs (a --check gate)
- [x] #4 The colour*18+direction*9 sprite index math is documented alongside the generated atlas so the Godot renderer can reproduce it
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added core/asset_dump_cli.zig (Phase 2 gob.zig/pcx.zig codec CLI wrapper: `asset-dump gob`/`asset-dump pcx`, dumping raw palette-index bytes + JSON manifest) and tools/build_sprite_atlas.py, which packs rabbit/objects/numbers/font.gob into PNG atlases against menu.pcx's shared global VGA palette (the same palette main.c loads once at startup for all four register_gob calls), emitting AtlasTexture .tres resources plus a JSON manifest carrying each frame's hotspot and the colour*18+direction*9 sprite-index formula (documented from main.c's `player[i].image + i*18` / `+ direction*9`). Atlas tile layout intentionally mirrors core/gobpack_cli.zig's doUnpack grid (including its y_count=atlas_h/tile_w quirk), so generated frame coordinates match the already-committed data/*.txt tables exactly -- verified by hand against data/rabbit.txt. `task assets:sprites:check` regenerates into a temp dir and diffs PNG bytes; passes.
<!-- SECTION:FINAL_SUMMARY:END -->
