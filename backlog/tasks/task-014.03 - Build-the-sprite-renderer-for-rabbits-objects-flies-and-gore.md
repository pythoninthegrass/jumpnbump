---
id: TASK-014.03
title: 'Build the sprite renderer for rabbits, objects, flies, and gore'
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-014
priority: high
type: task
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build the presentation-layer sprite renderer in game/presentation/ that reads the per-frame serialized world buffer from JumpnbumpWorld and draws player rabbits, objects (particles), flies, and gore/leftovers using the atlases from the sibling asset-pipeline task, applying the colour*18+direction*9 frame-index and per-sprite hotspot offsets. This is new work with no neo_snake prior art (it renders via immediate-mode draws with no textures at all).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All four categories (players, particles, flies, gore) render at the correct position, frame, and hotspot offset for a range of test states
- [ ] #2 Sprite draw order matches the original layering (background under sprites, masked foreground over sprites)
- [ ] #3 Rendering logic lives in pure, Node-independent helper functions where possible, to support headless testing per neo_snake's board_geometry.gd precedent
<!-- AC:END -->
