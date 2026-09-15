---
id: TASK-002
title: Pin toolchain and add go-task orchestration
status: To Do
assignee: []
created_date: '2026-09-15 19:12'
labels: []
milestone: m-0
dependencies: []
priority: high
type: chore
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend .tool-versions (currently prek, python, ruff, uv, zig 0.16.0) to add godot 4.7.1-stable, task (go-task), scons, and node, matching the pins used by the neo_snake reference project at ~/git/neo_snake/.tool-versions. Add a taskfile.yml plus taskfiles/ that will host per-subsystem task files as later phases add core/, extension/, and game/ builds. `task check` should exist from the start as the single verification gate, even if it only runs the existing `make` build initially — later phases append steps to it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `.tool-versions` pins godot, task, scons, and node in addition to the existing entries
- [ ] #2 `task check` runs and passes, initially wrapping the existing `make` build
- [ ] #3 taskfiles/ directory structure exists ready to receive core.yml, extension.yml, game.yml as those subsystems are built
<!-- AC:END -->
