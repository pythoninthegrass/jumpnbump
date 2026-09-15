---
id: TASK-015.05
title: Retire the SDL runtime path
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-6
dependencies: []
parent_task_id: TASK-015
priority: medium
type: task
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Once the Godot build is the primary, fully playable way to run Jump'n'Bump, stop building/shipping the SDL runtime binary by default. The C sources (main.c, sdl/, modify/) are kept in the repo permanently as the Phase 1 differential-test reference — this task only retires the runtime binary from the default build/release path, it does not delete any C code.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The default `task check`/release build no longer produces or ships the standalone SDL jumpnbump binary as a user-facing artifact
- [ ] #2 The SDL C build is still buildable on demand (e.g. via `make`) for use as the difftest oracle
- [ ] #3 README/docs are updated to describe the Godot build as the way to play the game
<!-- AC:END -->
