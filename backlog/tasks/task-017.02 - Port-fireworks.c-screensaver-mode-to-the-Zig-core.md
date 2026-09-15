---
id: TASK-017.02
title: Port fireworks.c screensaver mode to the Zig core
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-017
priority: low
type: task
ordinal: 59000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port fireworks.c's screensaver behavior (bouncing/exploding rabbits, parallax starfield with per-pixel background caching, its own state arrays entirely separate from player[]) into the Zig simulation core, verified against the C oracle. Depends on the delivery spike being complete so the porting target (embedded Godot vs. native) is known.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The ported fireworks behavior matches the C original via a difftest-style comparison using a dedicated corpus of fireworks-mode traces
- [ ] #2 The rabbits[20] and stars[300] state arrays are represented in the Zig core exactly as separate from the main player[] simulation state, matching the original's design
<!-- AC:END -->
