---
id: TASK-015
title: Make the game locally playable on macOS
status: Done
assignee: []
created_date: '2026-09-15 19:14'
updated_date: '2026-09-19 01:49'
labels: []
milestone: m-6
dependencies: []
priority: high
type: task
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task. Wire up local 4-player input (keyboard defaults matching the original arrows/WASD/IJL/numpad scheme, gamepad support, remapping with a persisted keybind codec), port the original pixel menu (menu.pcx backdrop, player colour/AI/key assignment) to Godot Control nodes, add persisted settings (sound, music, gore, flies, mirror, player count) to user://, and complete the title-to-scores match flow with clean pause and quit handling. Retire the SDL runtime path once this is done — the C sources remain solely as the Phase 1 differential-test reference. Depends on Phase 5 (Godot game at parity) being complete — do not start until all Phase 5 tasks are Done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All five subtasks are complete
- [ ] #2 A fresh macOS build supports 4 local players (any mix of human/AI) from launch through a full match to the scoreboard and back to the menu
- [x] #3 Settings persist across restarts via user://
- [x] #4 Music stops cleanly on quit with no leaked audio playback objects
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All five subtasks (TASK-015.01 through TASK-015.05) are Done:

- 015.01: InputRouter + InputBindings -- 4-local-player keyboard/gamepad input packed into jnb_input's per-player bitmask form, persisted remapping, defaults matching globals.pre's P1 arrows/P2 WASD/P3 IJL/P4 numpad scheme.
- 015.02: MenuScreen + MenuSlots -- Control-based player-select UI over menu.pcx's backdrop (Human/AI toggle, colour-by-slot, in-menu key rebinding), keyboard/gamepad navigable via Godot's built-in focus traversal.
- 015.03: GameSettings + SettingsScreen -- sound/music/gore/flies/mirror/player-count persisted to user://, explicitly dropping -scaleup/-fullscreen/-mouse.
- 015.04: Main refactored into the title -> menu -> gameplay -> scores -> menu flow controller; GameplayScreen owns pause()/resume()/end_match() (gating TickDriver, never the core); AppLifecycle already stopped music cleanly on quit (TASK-014.06) and now covers every screen since MusicPlayer is created once in Main and outlives screen swaps.
- 015.05: `task check` no longer builds/ships the SDL binary; `task legacy:build` keeps it available on demand for the difftest oracle; README rewritten to lead with the Godot build.

Verified end-to-end: full gdUnit4 suite (30 cases across input/menu/settings/match-flow) plus the 5 legacy smoke tests all pass; tools/validate_game_boundary.py OK; `task check` runs clean without invoking `make`; `task legacy:build` still compiles the legacy binary; an ad-hoc headless script drove Main through title -> menu -> gameplay -> pause -> resume -> end_match -> scores with no runtime errors.

Caveat on AC#2: this work was done and verified on Linux in a sandbox with no display server (no X11/Wayland available, confirmed via `godot --path game` failing to create a DisplayServer). AC#2's "fresh macOS build" and any real interactive play-through (visual menu navigation, actual gamepad input, watching the mirror flip render correctly) could not be exercised here -- verification is headless/structural (gdUnit4 tests calling the same code paths directly) plus a scripted full-flow run, not a human playtest on macOS. Recommend a real playtest on macOS before considering this shippable.
<!-- SECTION:FINAL_SUMMARY:END -->
