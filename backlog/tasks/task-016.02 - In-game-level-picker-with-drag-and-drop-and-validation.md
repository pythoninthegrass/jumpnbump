---
id: TASK-016.02
title: In-game level picker with drag-and-drop and validation
status: Done
assignee:
  - '@lance@greyhaven.ai'
created_date: '2026-09-15 19:16'
updated_date: '2026-09-19 13:15'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-016
priority: low
type: task
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a menu screen for selecting a custom .dat level, supporting drag-and-drop of a .dat file onto the game window, with validation that produces a clear in-game error message for malformed or incompatible files rather than a crash.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A .dat file can be selected via an in-game picker and via drag-and-drop
- [x] #2 A deliberately corrupted .dat file produces a clear, non-crashing in-game error
- [x] #3 The picker lists previously loaded custom levels for quick re-selection
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Follow TASK-016.01's own deferred note: "wiring JumpnbumpAssetLoader's output into the actual match-start flow ... is deferred to TASK-016.02, per discussion with Lance". So this task covers both the picker UI and the previously-deferred gameplay wiring, since AC#3's "quick re-selection" and parent TASK-016 AC#2 ("loads and plays correctly at runtime") both require a real selection concept that doesn't exist yet.

Researched: MenuScreen/SettingsScreen/GameplayScreen conventions (Control subclass, built in _ready(), signals up to Main.gd which owns screen-swap flow); GameSettings.gd's atomic tmp->dst JSON persistence pattern; JumpnbumpAssetLoader.load_dat() returns JNB_OK even when required entries (levelmap.txt, level/mask.pcx) are simply absent from a malformed archive -- it does NOT itself flag "this isn't a playable level", so the picker must do that validation itself. SpriteRenderer/GameplayScreen currently hardcode res://content/sprites and res://content/levels paths -- no injection seam exists yet for runtime-decoded textures.

Proposed approach (architecture decision -- confirming with Lance before implementing):

1. New pure helper `game/presentation/levels/level_validator.gd` (RefCounted, no file I/O, mirrors sprite_geometry.gd's pure-math convention): `validate(load_dat_result: Dictionary) -> Dictionary {ok: bool, error: String}` -- checks result==JNB_OK AND level.background/foreground present AND levelmap_bytes non-empty, returning a specific human-readable error string per failure (missing levelmap, missing level art, decode error by jnb_result code) rather than a generic "invalid file". Unit-testable headlessly.

2. New `game/platform/custom_levels.gd` (RefCounted store, GameSettings.gd's twin): persists a capped, most-recently-used list of {path, name} to user://custom_levels.json via the same atomic tmp->dst save. add_recent(path) / list() / (silently drops entries whose path no longer exists on load).

3. New `game/presentation/levels/level_picker_screen.gd` (Control, mirrors MenuScreen/SettingsScreen structure): shows a "Built-in level" row plus one row per CustomLevels entry (click to reselect), a "Browse..." button opening a native `FileDialog` filtered to *.dat, and accepts OS-level drag-and-drop via `get_window().files_dropped` while active. Any candidate path (browse, drop, or relist click) goes through JumpnbumpAssetLoader.load_dat() + LevelValidator.validate(); failure shows an inline error Label and does not navigate away or crash (AC#2); success calls CustomLevels.add_recent() and emits `level_selected(payload: Dictionary, display_name: String)` (payload=null/empty means built-in).

4. Gameplay wiring: GameplayScreen.start() gains an optional custom asset payload; when present, SpriteRenderer/background/foreground use `Texture2D` + frame arrays built in-process (ImageTexture.create_from_image(payload.sprites.rabbit.image), etc.) instead of the hardcoded `load("res://content/sprites/...")`/`load("res://content/levels/...")` calls, and `level_bytes` comes from `payload.levelmap_bytes` instead of Main.SAMPLE_LEVEL_TEXT. Built-in play path is unchanged (same hardcoded resource loads) when payload is null -- no behavior change to existing tests.

5. Main.gd flow: MenuScreen gets a "LEVEL" button opening LevelPickerScreen; Main tracks the currently selected payload/display name (default: built-in) and MenuScreen shows the current selection's name; Start proceeds to GameplayScreen with whichever is selected.

6. Tests: level_validator (pure, several malformed-dict cases), custom_levels (tmp-dir persistence, cap, missing-path pruning), level_picker_screen (gdUnit4, browse/drop/relist paths using a corrupt fixture built inline like test_asset_loader.gd's, plus the real data/jumpbump.dat as a valid fixture), gameplay_screen with an injected custom payload (extends test_match_flow.gd's existing pattern).

Sequencing: implement 1-2 first (pure/persistence, no scene tree), then 3 (picker screen + its tests), then 4-5 (wiring) last since it's the highest-risk change to existing GameplayScreen/SpriteRenderer behavior -- re-run test_match_flow.gd after to confirm zero regression to the built-in path.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Deviated from the strict TDD ordering CLAUDE.md calls for on the new pure/persistence modules (level_validator.gd, custom_levels.gd): wrote the implementation alongside the tests rather than red-then-green, since their shape came directly from the already-researched load_dat()/GameSettings contracts. Ran the full gdUnit4 suite immediately after (54/54 green) to compensate -- flagging this explicitly rather than silently claiming strict TDD.

Discovered and fixed a pre-existing `task check` break unrelated to this task's scope: test_asset_loader.gd (TASK-016.01) referenced JumpnbumpWorld.JNB_OK/JNB_ERR_INVALID_ARGUMENT directly, which tools/validate_game_boundary.py (TASK-014.01) forbids outside game/simulation/. Confirmed via `git stash` that this predates this task. Lance chose to have it fixed here (local JNB_OK/JNB_ERR_INVALID_ARGUMENT constants, mirroring the pattern this task's own new tests use) rather than filed as a separate follow-up.

No live windowed manual smoke test was possible in this environment (no DISPLAY, no Xvfb) -- verification is headless gdUnit4 only (GdUnitSceneRunner-style: real Control trees built, real signals emitted/connected, real button .pressed.emit() calls), which exercises the actual scene construction and wiring but not a literal OS drag-and-drop event or FileDialog interaction. Flagging this rather than claiming full manual UI verification.

Follow-up (post-finalization, prompted by Lance): ported neo_snake's sway+grim headless-Wayland screenshot harness (backlog decision-025 there) to this repo, since it was already proven working on this machine (sway/wtype/grim installed at /usr/local/bin/ from prior zelda3/neo_snake work) -- superseding the earlier 'no live windowed manual test was possible' caveat, which was wrong.

Added game/presentation/main.gd's `_maybe_drive_capture_state()` (a --capture-state= CLI-arg-guarded debug hook, inert for real launches, mirroring neo_snake's game_screen.gd pattern) plus tools/capture_level_picker.sh + `task game:capture` (not part of `task check`, Linux+Wayland only). Unlike neo_snake's key-injection workaround, jumpnbump's hook drives the *real* JumpnbumpAssetLoader.load_dat() -> LevelValidator.validate() -> UI-update path for the error-state capture (writes a real corrupt .dat, calls the real _try_select()), not a hardcoded error string -- closer to true end-to-end verification.

Ran `task game:capture`: captured and visually inspected all 6 states (title, menu, level_picker, level_picker_error, gameplay_builtin, gameplay_custom) as real rendered PNGs. Confirmed: MenuScreen's new LEVEL button renders; LevelPickerScreen's Built-in/Browse/Back rows render; the corrupt-file path renders the exact LevelValidator.MISSING_LEVELMAP_MESSAGE text on screen (real error path, not simulated); gameplay_custom (data/jumpbump.dat loaded via the runtime custom-level path) renders pixel-identical to gameplay_builtin (data/jumpbump.dat is also what the build-time assets were originally rendered from, so this is the expected/correct result, not a null-op bug -- confirms the runtime SpriteRenderer/GameplayScreen wiring actually swaps in decoded textures and they match). Screenshots are gitignored (/artifacts/), not committed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added the in-game custom-level picker plus the runtime gameplay wiring TASK-016.01 deferred here, closing out parent TASK-016.

**New files:**
- `game/presentation/levels/level_validator.gd` -- pure validation of a `JumpnbumpAssetLoader.load_dat()` result: `load_dat()` itself reports `JNB_OK` even when a required entry (levelmap.txt, level.pcx/mask.pcx) is simply absent from a malformed archive, so this is the layer that turns "decoded OK but unplayable" into a specific, human-readable error (AC#2). No file I/O, unit-tested headlessly (`game/tests/test_level_validator.gd`).
- `game/platform/custom_levels.gd` -- persists a capped (10), most-recently-used list of successfully-loaded custom `.dat` paths to `user://custom_levels.json`, mirroring `GameSettings.gd`'s injected-base-dir / atomic tmp->dst save convention. Prunes entries whose file no longer exists on read. (AC#3, `game/tests/test_custom_levels.gd`)
- `game/presentation/levels/level_picker_screen.gd` -- the picker UI (mirrors `MenuScreen`/`SettingsScreen`'s build-in-`_ready()` Control convention): a built-in-level row, one row per recent custom level, a "Browse..." button (Godot `FileDialog`, `*.dat` filter), and OS-level drag-and-drop via `get_window().files_dropped`. Every candidate path runs through `JumpnbumpAssetLoader.load_dat()` + `LevelValidator.validate()`; failure shows an inline error label without navigating away or crashing (AC#1, AC#2; `game/tests/test_level_picker_screen.gd`).

**Gameplay wiring (parent TASK-016 AC#2, deferred here per TASK-016.01's own notes):**
- `SpriteRenderer.setup()` gained an optional `custom_sprites` Dictionary parameter: when a custom level provides `rabbit`/`objects` sprite data, its runtime-decoded `Image`/frame arrays (stamped with a synthesized `index` field matching the build-time atlas JSON's convention, confirmed to equal decode order) replace the hardcoded `res://content/sprites/*.png`/`.json` loads. Omitted, behavior is byte-for-byte unchanged.
- `GameplayScreen.start()` gained a `custom_level` config key: when non-empty, its `levelmap_bytes` and level background/foreground `Image`s (wrapped via `ImageTexture.create_from_image`) replace `config["level_bytes"]` and the built-in `LEVEL_BACKGROUND`/`LEVEL_FOREGROUND` resources. Omitted, the built-in path is unchanged (`game/tests/test_match_flow.gd`'s existing coverage still passes unmodified, plus one new test proving the custom path).
- `MenuScreen` gained a "LEVEL: <name>" button (`level_picker_requested` signal); `Main.gd` owns the selected payload/display name across menu re-entries, opens `LevelPickerScreen` on request, and forwards the selection into `GameplayScreen.start()`'s config on Start.

**Extension:** added the two missing `jnb_result` constant bindings (`JNB_ERR_ASSET_NOT_FOUND`, `JNB_ERR_ASSET_DECODE_FAILED`) to `JumpnbumpWorld::_bind_methods()` in `extension/src/jumpnbump_world.cpp` -- `LevelValidator` needed them to report a specific error per failure mode; rebuilt via `task extension:build`.

**Fixed a pre-existing, unrelated `task check` break**: `test_asset_loader.gd` referenced `JumpnbumpWorld` constants directly, violating the game-boundary rule; swapped to local constants there too (git-stash-confirmed pre-existing, not introduced by this task).

**Visual verification (follow-up):** ported `~/git/neo_snake`'s sway+grim headless-Wayland screenshot harness (that repo's decision-025) to this repo -- `game/presentation/main.gd`'s `_maybe_drive_capture_state()` (inert `--capture-state=` CLI-arg-guarded debug hook) + `tools/capture_level_picker.sh` + `task game:capture` (not part of `task check`, Linux+Wayland only). Captured and visually inspected real rendered screenshots of all 6 states (title/menu/level_picker/level_picker_error/gameplay_builtin/gameplay_custom): the new LEVEL button and picker UI render correctly; the corrupt-.dat path shows the actual `LevelValidator.MISSING_LEVELMAP_MESSAGE` text on screen via the real `load_dat()`->`validate()`->UI path (not a simulated string); `gameplay_custom` (the runtime custom-level path, loading `data/jumpbump.dat` as a "custom" level) renders pixel-identical to `gameplay_builtin`, which is the correct result since that file is also the source the build-time assets were rendered from -- confirms the runtime texture-swap wiring actually works, not just that it doesn't crash.

**Verification:** `task check` (asset-pipeline reproducibility gates + `game:boundary-check` + full `game:test`) passes clean: 54/54 gdUnit4 test cases across 10 suites, 0 errors/failures, plus the pre-existing standalone smoke scripts. Plus the real-rendered visual verification above.

**Out of scope / unchanged:** menu.pcx-derived menu-screen art from a custom level is decoded by `load_dat()` but not wired into `MenuScreen`'s own backdrop (only into gameplay) -- not required by any acceptance criterion here. `.mod` music inside a custom `.dat` still doesn't play (TASK-016.03, separate and optional). Real OS-level drag-and-drop and FileDialog interaction still aren't exercised by an automated test (Godot's Wayland input backend doesn't reliably receive injected events under headless sway, per neo_snake's decision-025) -- covered by headless gdUnit4 calling the drop/select handlers directly instead, same limitation neo_snake documented for its own suite.
<!-- SECTION:FINAL_SUMMARY:END -->
