---
id: TASK-014
title: Render the Zig sim core in Godot at parity
status: To Do
assignee: []
created_date: '2026-09-15 19:13'
labels: []
milestone: m-5
dependencies: []
priority: high
type: task
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task (Parent B). Build the Godot presentation layer that drives the Zig simulation core through the GDExtension and renders it at parity with the original game: project skeleton with the four-layer directory split (simulation/presentation/platform/content) and a machine-enforced boundary validator, a tick driver injecting delta into jnb_pump, a sprite renderer for rabbits/objects/flies/gore driven off the per-frame serialized world buffer, background+masked-foreground level layers at the original 400x256 design resolution with integer scaling, scoreboard text from the font/number atlases, and the audio bus/player/event-coalescer setup. Verified via corpus replay through the real GDExtension under gdUnit4. Depends on Phase 4 (the GDExtension) being complete — do not start until all Phase 4 tasks are Done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All seven subtasks are complete
- [ ] #2 task game:boundary-check passes: no script outside game/simulation/ references the GDExtension class
- [ ] #3 Corpus replay from Phase 1 through the real GDExtension matches checksums frame-for-frame under gdUnit4
- [ ] #4 The game renders and runs visually at the original 400x256 aspect ratio with correct scaling/letterboxing
<!-- AC:END -->
