---
id: TASK-015.05
title: Retire the SDL runtime path
status: Done
assignee: []
created_date: '2026-09-15 19:16'
updated_date: '2026-09-19 01:48'
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
- [x] #1 The default `task check`/release build no longer produces or ships the standalone SDL jumpnbump binary as a user-facing artifact
- [x] #2 The SDL C build is still buildable on demand (e.g. via `make`) for use as the difftest oracle
- [x] #3 README/docs are updated to describe the Godot build as the way to play the game
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed `make` from the top-level `task check` gate (taskfile.yml) -- it now runs only `assets:check`, `game:boundary-check`, and `game:test`, none of which touch or produce the SDL `jumpnbump` binary. Added taskfiles/legacy.yml with `legacy:build` (`make`) and `legacy:clean` (`make clean`) so the SDL C build stays available on demand, exactly as before, just no longer part of the default gate. Added `game:run` (`godot --path game`) to taskfiles/game.yml as the documented way to actually play. Updated taskfiles/ci.yml's `ci:linux-check`/`ci:macos-check` to run `task legacy:build` before `task check`, so CI still proves the oracle builds on both platforms even though it's no longer inside `check` itself.

Rewrote README.md: Status now describes the Godot build as primary and the legacy C tree explicitly as oracle-only (the old text claimed no Godot project/GDExtension/jumpnbump.h existed at all, long stale); "Playing it" leads with `task game:run`; the legacy SDL section is demoted to "The legacy SDL build (oracle)" with `task legacy:build`/`task legacy:clean` in place of raw `make`/`make clean`; the Controls table's Dott/Jiffy row was previously swapped versus globals.pre's actual scheme (found during TASK-015.01's research) -- fixed to Dott=arrows, Jiffy=WASD, matching InputBindings.DEFAULT_BINDINGS; custom-levels/screensaver/netplay are labeled legacy-build-only since TASK-016/017 haven't ported them yet; the Architecture table's `game/` row now says "the primary way to play".

Verification: `task check` runs clean (exit 0, 30/30 gdUnit4 + asset checks, no `make` invoked) confirming AC#1; `task legacy:build` still compiles the `jumpnbump` binary successfully on demand confirming AC#2; README changes above satisfy AC#3. `task --list` confirms `legacy:build`/`legacy:clean`/`game:run` are registered correctly.
<!-- SECTION:FINAL_SUMMARY:END -->
