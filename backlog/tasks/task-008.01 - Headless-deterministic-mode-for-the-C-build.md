---
id: TASK-008.01
title: Headless deterministic mode for the C build
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-1
dependencies: []
parent_task_id: TASK-008
priority: high
type: task
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a headless mode to the existing SDL C build: fixed 60Hz tick with no wall-clock dependency, scripted input read from a file instead of live keyboard/joystick, no audio/video output required, and a seeded rnd() so runs are exactly reproducible. This becomes the foundation the rest of Phase 1 builds on.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A CLI flag runs the C build headlessly with no window/audio device required
- [ ] #2 Given the same seed and the same scripted input file, two runs produce byte-identical state
- [ ] #3 The fixed 60Hz tick does not drift relative to wall-clock time in headless mode
<!-- AC:END -->
