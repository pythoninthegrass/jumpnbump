---
id: TASK-015.04
title: Complete the title-to-scores match flow with pause and clean quit
status: Done
assignee: []
created_date: '2026-09-15 19:16'
updated_date: '2026-09-19 01:46'
labels: []
milestone: m-6
dependencies: []
parent_task_id: TASK-015
priority: high
type: task
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Wire together the full match flow: title screen to menu to gameplay to scoreboard, with restart back to the menu. Add pause (gating the TickDriver, not the core) and ensure clean quit stops music before the app closes to avoid leaking audio playback objects, per the neo_snake gotcha already noted in the audio task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A full match can be played start to finish: title, menu, gameplay, scoreboard, and back to menu, with no manual intervention required between screens
- [x] #2 Pausing during gameplay freezes the simulation and resumes correctly
- [x] #3 Quitting from any screen stops music cleanly with no leaked audio objects
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Refactored Main (game/presentation/main.gd) from a gameplay-only composition root into the title -> menu -> gameplay -> scores -> menu flow controller: it now creates the persistent, screen-spanning nodes once (SfxPlayer, MusicPlayer, InputRouter, AppLifecycle) and swaps a single child under a ScreenContainer between TitleScreen, MenuScreen (TASK-015.02), a new GameplayScreen, and a new ScoresScreen.

Added:
- game/presentation/title_screen.gd -- title + Start button over menu.pcx's backdrop.
- game/presentation/gameplay/gameplay_screen.gd -- extracted the SimWorld/SpriteRenderer/ScoreboardRenderer wiring TASK-014.* built directly into Main, now parameterized by a config dict (seed, flies_enabled, level_bytes, player_count, ai_mask, no_gore, mirror_enabled) fed from GameSettings + MenuScreen's ai_mask. Applies GameSettings.mirror_transform() to its LevelLayers container. Exposes pause()/resume()/end_match() and is_paused() as the public pause API (gates TickDriver via _gate/_paused, never touches the core, per tick_driver.gd's existing contract); end_match() reads final per-player bumps via player_view_get and emits match_ended.
- game/presentation/gameplay/pause_overlay.gd -- Resume/End Match overlay shown on ui_cancel (Esc) during gameplay.
- game/presentation/scores/scores_screen.gd -- final bump tally for enabled players (jnb_player_view.bumps, the same total ScoreboardRenderer's in-match HUD already shows -- the ABI has no per-opponent bumped[] tally to show a full matrix), Continue returns to the menu.

Tests: game/tests/test_match_flow.gd (gdUnit4, 7 cases) covers TitleScreen's Start signal, ScoresScreen's enabled-slot filtering and Continue signal, GameplayScreen's node wiring, and pause/resume/end-match state transitions (called directly, not via synthesized input events -- headless runs can't deliver real InputEvents at all). Updated test_sprite_geometry.gd/test_text_geometry.gd/test_level_layers.gd, which previously instantiated main.tscn expecting gameplay nodes directly under Main, to instantiate GameplayScreen directly instead, since Main no longer builds gameplay eagerly.

Verification: full gdUnit4 suite 30/30 passing, all 5 legacy godot --script smoke tests OK, tools/validate_game_boundary.py OK. Additionally ran an ad-hoc headless script driving Main through the real flow end-to-end (title -> show_menu -> start_match -> pause -> resume -> end_match -> scores) with no runtime errors, confirming the wiring actually works, not just each screen in isolation. Could not visually verify in a real window -- this sandbox has no X11/Wayland display server (`godot --path game` fails with "Unable to create DisplayServer, all display drivers failed"); AC#1's "full match playable start to finish" is therefore verified structurally/headlessly, not by an actual play session.
<!-- SECTION:FINAL_SUMMARY:END -->
