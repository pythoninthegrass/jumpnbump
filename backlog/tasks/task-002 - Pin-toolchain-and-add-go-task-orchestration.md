---
id: TASK-002
title: Pin toolchain and add go-task orchestration
status: Done
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
- [x] #1 `.tool-versions` pins godot, task, scons, and node in addition to the existing entries
- [x] #2 `task check` runs and passes, initially wrapping the existing `make` build
- [x] #3 taskfiles/ directory structure exists ready to receive core.yml, extension.yml, game.yml as those subsystems are built
<!-- AC:END -->

## Evidence

- `.tool-versions` now pins godot 4.7.1-stable, task 3.49.1, pipx:scons 4.11.1 and node 24.12.0 alongside the existing prek/python/ruff/uv/zig entries (same versions and `pipx:` form as `~/git/neo_snake/.tool-versions`). `mise install` reports all tools installed; `task --version` 3.49.1, `scons --version` v4.11.1, `godot --version` 4.7.1.stable.official, `node --version` v24.12.0 all resolve through mise shims.
- `task check` runs `make` (top-level legacy build: sdl.a, modify/ packers, data/jumpbump.dat, `jumpnbump` binary) and exits 0.
- `taskfiles/` exists with a `.gitkeep` placeholder; `includes:` in `taskfile.yml` is an empty map so later phases add core.yml / extension.yml / game.yml without referencing files that don't exist yet.

## Notes

- neo_snake's `taskfile.yml` also relies on a `.env` with `TASK_X_ENV_PRECEDENCE=1` and a guard task, because its `check` chains many subsystem tasks whose PATH override must beat the OS env. This taskfile's `env:` PATH prefix works without that experiment in task 3.49.1 (verified by the passing `task check`), so no `.env` is introduced — the diff stays inside the three files this task owns. Revisit if a later phase's steps need task-level env to override an inherited one.
- Build artifacts from the verification run were cleaned with `make clean`; only `.tool-versions`, `taskfile.yml` and `taskfiles/.gitkeep` changed.
