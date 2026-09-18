---
id: TASK-014
title: Render the Zig sim core in Godot at parity
status: Done
assignee: []
created_date: '2026-09-15 19:13'
updated_date: '2026-09-18 01:38'
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
- [x] #1 All seven subtasks are complete
- [x] #2 task game:boundary-check passes: no script outside game/simulation/ references the GDExtension class
- [x] #3 Corpus replay from Phase 1 through the real GDExtension matches checksums frame-for-frame under gdUnit4
- [x] #4 The game renders and runs visually at the original 400x256 aspect ratio with correct scaling/letterboxing
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All seven subtasks (014.01-014.07) complete: Godot project skeleton with an enforced simulation/GDExtension boundary, TickDriver/SimWorld wrapper over jnb_pump, immediate-mode sprite renderer for rabbits/objects/flies/gore, level layers with integer scaling and code-driven letterboxing, scoreboard from font/number atlases, audio buses/players/event coalescer, and gdUnit4 corpus replay through the real GDExtension. `task game:boundary-check` and `task check` both pass. All 10 Phase 1 corpus traces replay through the real GDExtension with matching checksums frame-for-frame (TASK-014.07, unblocked by TASK-018's core/abi.zig fix). Two documented, pre-existing gaps outside this task's scope: the fly-spawn sfx ding has no corresponding core event (TASK-011.06), and visual letterboxing itself could only be verified via configuration (canvas_items/keep stretch mode + code-driven window sizing), not pixel inspection, since this environment is headless-only.
<!-- SECTION:FINAL_SUMMARY:END -->
