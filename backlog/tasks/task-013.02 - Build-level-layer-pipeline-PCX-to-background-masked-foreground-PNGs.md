---
id: TASK-013.02
title: 'Build level-layer pipeline: PCX to background + masked-foreground PNGs'
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
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
- [ ] #1 The pipeline produces separate background and masked-foreground PNGs for both the gameplay level and the menu screen
- [ ] #2 The masked-foreground PNG correctly encodes transparency so it composites over sprites, verified visually against the original mask.pcx semantics
- [ ] #3 Regenerating twice from source produces byte-identical PNGs
<!-- AC:END -->
