---
id: TASK-015.03
title: 'Add persisted settings: sound, music, gore, flies, mirror, player count'
status: Done
assignee: []
created_date: '2026-09-15 19:16'
updated_date: '2026-09-19 01:39'
labels: []
milestone: m-6
dependencies: []
parent_task_id: TASK-015
priority: medium
type: task
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Surface the original CLI-flag-controlled options (-nosound, -musicnosound, -nogore, -noflies, -mirror, player count) as an in-game settings UI, persisted to user://. Deliberately drop -scaleup, -fullscreen, and -mouse as obsolete — Godot's display handling and gamepad support supersede them.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Sound, music, gore, flies, and mirror-mode settings are all toggleable in-game and persist across restarts
- [x] #2 Player count (1-4) is configurable and persists
- [x] #3 No -scaleup/-fullscreen/-mouse equivalents are exposed; this omission is noted in the settings UI's implementation notes
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added game/platform/game_settings.gd (persists sound_enabled/music_enabled/gore_enabled/flies_enabled/mirror_enabled/player_count to user://game_settings.json, atomic tmp->dst write mirroring AudioSettings, player_count clamped to 1-4) and game/presentation/settings/settings_screen.gd (a Control with one toggle row per boolean setting plus a +/- player-count stepper, each change saved immediately). apply_to_audio_server() mutes the SFX/Music buses per sound/music toggle (independent of AudioSettings' own per-bus dB level); no_gore()/flies_enabled/player_count map straight onto jnb_config's matching fields for SimWorld.init. mirror_transform() is a pure Transform2D helper for main.c's -mirror flip, left for TASK-015.04's match-flow scene to apply to the level-layers container it owns (SettingsScreen itself has no game-state container to flip).

-scaleup/-fullscreen/-mouse are not exposed anywhere in this UI or GameSettings (AC#3), noted in game_settings.gd's header comment.

Tests: game/tests/test_settings_screen.gd (gdUnit4, 9 cases) covers GameSettings defaults/round-trip/player-count clamping, no_gore inversion, mirror_transform's identity/flip math, and the settings screen's toggle-persists / stepper-clamps-and-persists / back-emits-current-settings behavior. Full gdUnit4 suite: 23/23 passing; tools/validate_game_boundary.py: OK. Not yet wired into main.tscn/Main -- TASK-015.04 owns assembling the actual screen flow and applying these settings (audio server mute, jnb_config fields, mirror transform) when a match starts.
<!-- SECTION:FINAL_SUMMARY:END -->
