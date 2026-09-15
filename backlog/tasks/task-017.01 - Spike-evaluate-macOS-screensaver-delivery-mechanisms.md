---
id: TASK-017.01
title: 'Spike: evaluate macOS screensaver delivery mechanisms'
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-017
priority: low
type: spike
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Before any screensaver-specific UI work begins, spike whether a Godot runtime can realistically be embedded inside a macOS ScreenSaverView subclass, and if not, evaluate the fallback of a native Swift/Metal view linking the same Zig core and exported sprite atlases directly (bypassing Godot for this one delivery path). Produce a written recommendation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The spike produces a written recommendation (in a decision doc) choosing embedded-Godot, native-Swift/Metal, or another approach, with rationale
- [ ] #2 The recommendation is made before any further screensaver task begins
<!-- AC:END -->
