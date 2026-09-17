---
id: TASK-013.02
title: 'Build level-layer pipeline: PCX to background + masked-foreground PNGs'
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
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Convert level.pcx/mask.pcx (gameplay) and menu.pcx/menumask.pcx (menu) into Godot-ready PNG layers: an opaque background layer and an alpha-keyed masked-foreground overlay layer that must draw on top of sprites, since mask_pic is a true foreground mask in the original, not part of the background.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The pipeline produces separate background and masked-foreground PNGs for both the gameplay level and the menu screen
- [x] #2 The masked-foreground PNG correctly encodes transparency so it composites over sprites, verified visually against the original mask.pcx semantics
- [x] #3 Regenerating twice from source produces byte-identical PNGs
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added tools/build_level_layers.py, using core/asset_dump_cli.zig's `pcx` subcommand to decode level.pcx/menu.pcx (each embeds its own 256-colour palette, read exactly like main.c's read_pcx(handle, background_pic, len, pal) call) and mask.pcx/menumask.pcx (loaded with pal=0, so no palette -- confirmed by hand that put_pob (sdl/gfx.c) only ever tests `mask_ptr == 0`, making it a boolean occlusion stencil, not a second picture). Background PNG is level.pcx/menu.pcx as-is (opaque); foreground PNG reuses the same background colours but with alpha=0 wherever the mask is 0 and alpha=255 wherever it's nonzero, meant to draw on top of sprites so the original "sprite hidden under foreground art" occlusion reproduces in Godot's layer order. `task assets:levels:check` regenerates into a temp dir and diffs PNG bytes for both level and menu layer sets; passes.
<!-- SECTION:FINAL_SUMMARY:END -->
