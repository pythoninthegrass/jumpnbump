---
id: TASK-015.02
title: Port the pixel menu to Godot Control nodes
status: Done
assignee: []
created_date: '2026-09-15 19:16'
updated_date: '2026-09-19 01:37'
labels: []
milestone: m-6
dependencies: []
parent_task_id: TASK-015
priority: high
type: task
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port menu.c's menu (player colour selection, AI toggle per player, key assignment) to Godot Control nodes, keeping menu.pcx as the visual backdrop and the original layout/interaction model, but with keyboard and gamepad navigation instead of raw mouse-click regions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The menu visually matches the original menu.pcx layout
- [x] #2 Each of the 4 player slots can be set to human (with colour choice) or AI
- [x] #3 Key assignment for human players is reachable and functional from the menu
- [x] #4 The menu is navigable by keyboard and gamepad, not only mouse
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added game/presentation/menu/menu_slots.gd (pure per-slot data: PLAYER_LABELS/PLAYER_COLORS matching ScoreboardRenderer's DOTT/JIFFY/FIZZ/MIJJI naming and rabbit_atlas.png's slot*18 colour offset, plus toggle_ai/is_ai bitmask helpers matching jnb_config.player_ai_mask) and game/presentation/menu/menu_screen.gd (a Control built entirely in code over menu_background.png/menu_foreground.png, one row per player slot with a colour swatch, Human/AI toggle button, and a Keys button that captures the next 3 physical key presses to rebind that slot via InputRouter.rebind()).

Research finding worth recording: menu.c turned out to hold only the DOS attract-mode title screen (scripted rabbit walk-in + credits scroll) -- there is no legacy colour-select/AI-toggle/key-assignment UI to port pixel-for-pixel, and jnb_config carries no colour field at all. "Colour choice" is therefore expressed as which of the 4 fixed slot colours (baked into rabbit_atlas.png, sprite_geometry.gd's rabbit_frame_index) a human occupies, not a separate colour cycle -- documented in menu_slots.gd's header comment. Keyboard/gamepad navigation (AC#4) needs no custom InputMap wiring: Godot's Control base class handles ui_up/down/left/right/accept focus traversal automatically for FOCUS_ALL nodes (Buttons default to this), so grabbing initial focus on the Start button is sufficient.

Tests: game/tests/test_menu_screen.gd (gdUnit4, 6 cases) covers the AI-toggle bitmask math, the built row/button tree shape, AI-toggle disabling the Keys button, and start_requested carrying the current ai_mask. Full `task game:test`-equivalent gdUnit4 run: 14/14 passing; tools/validate_game_boundary.py: OK. Not yet wired into main.tscn/Main -- that scene-swapping (title/menu/gameplay/scoreboard) is TASK-015.04's job; MenuScreen is a self-contained, instantiable Control ready for that.
<!-- SECTION:FINAL_SUMMARY:END -->
