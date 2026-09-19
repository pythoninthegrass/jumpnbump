---
id: TASK-015.01
title: Build InputRouter for 4 local players with remapping
status: Done
assignee: []
created_date: '2026-09-15 19:16'
updated_date: '2026-09-19 01:34'
labels: []
milestone: m-6
dependencies: []
parent_task_id: TASK-015
priority: high
type: task
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build game/platform/input_router.gd routing keyboard input for up to 4 local players with defaults matching the original scheme (P1 arrows+up, P2 WASD, P3 IJL, P4 numpad 4/6/8), gamepad support, and a persisted keybind codec for remapping. Be aware of the neo_snake gotcha: rebinds are applied from a save file at startup, so a later change to the coded defaults has no effect on a machine that already has a save file — document this explicitly in the implementation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Default keybindings match the original KEY_PL1..4_LEFT/RIGHT/JUMP scheme from globals.pre
- [x] #2 At least one gamepad can control a player
- [x] #3 Rebinding a key persists across restarts via a save file, and the save-file-precedence gotcha is documented in a code comment
- [x] #4 InputRouter emits direction/jump signals only; it holds no game state
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added game/platform/input_bindings.gd (persisted per-player keybind array, atomic tmp->dst write mirroring AudioSettings, defaults matching globals.pre's USE_SDL KEY_PLn_LEFT/RIGHT/JUMP scheme: P1 arrows, P2 WASD, P3 IJL, P4 numpad 4/6/8) and game/platform/input_router.gd (Node polling Input each frame, packing per-player left/right/jump into jnb_input's bitmask form -- bit i = player i -- via a pure, unit-tested compute_masks(), plus gamepad axis/button support for P1 by default and a rebind() that persists immediately). Wired InputRouter into Main: it emits input_updated(left,right,jump) each frame, Main caches the masks and forwards them into TickDriver.advance_frame instead of the hardcoded 0/0/0 placeholder.

The save-file-precedence gotcha (a save file always wins over DEFAULT_BINDINGS once it exists, so changing defaults has no effect on a machine with an existing save) is documented directly in input_bindings.gd's header comment per AC#3.

Tests: game/tests/test_input_router.gd (gdUnit4) covers default-bindings-match-globals.pre, bitmask math (including MAX_PLAYERS clamping), and InputBindings round-trip/partial-file-fill persistence -- 5/5 passing. Re-ran the full `task game:test` gdUnit4 suite (8/8 passing) and tools/validate_game_boundary.py (OK) to confirm no regression from touching main.gd. Gamepad support (AC#2) is implemented via Input.get_joy_axis/is_joy_button_pressed but not exercisable in headless CI -- verified by code path only, no physical controller available in this environment.
<!-- SECTION:FINAL_SUMMARY:END -->
