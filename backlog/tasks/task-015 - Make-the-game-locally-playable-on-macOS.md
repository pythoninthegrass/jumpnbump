---
id: TASK-015
title: Make the game locally playable on macOS
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
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
- [ ] #1 All five subtasks are complete
- [ ] #2 A fresh macOS build supports 4 local players (any mix of human/AI) from launch through a full match to the scoreboard and back to the menu
- [ ] #3 Settings persist across restarts via user://
- [ ] #4 Music stops cleanly on quit with no leaked audio playback objects
<!-- AC:END -->
