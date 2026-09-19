---
id: TASK-016
title: Support custom user .dat levels
status: Done
assignee: []
created_date: '2026-09-15 19:14'
updated_date: '2026-09-19 17:01'
labels: []
milestone: m-8
dependencies: []
priority: low
type: task
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task. Add runtime loading of user-created .dat files (as documented in levelmaking/) through the Zig asset codecs, building Godot textures/atlases at runtime instead of at build time, plus an in-game level picker with drag-and-drop and validation/error reporting for malformed files. Optionally, port a Zig ProTracker (.mod) player so custom levels can ship and play their own music without a build-time OGG conversion step. Depends on Phase 6 (playable macOS) being complete — do not start until all Phase 6 tasks are Done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All three subtasks are complete
- [x] #2 A community-made .dat file from levelmaking/ examples loads and plays correctly at runtime
- [x] #3 Malformed or incompatible .dat files produce a clear in-game error rather than a crash
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All three subtasks complete:

- **TASK-016.01** (Runtime .dat loading and atlas building): core/asset_runtime.zig + extension JumpnbumpAssetLoader.load_dat() decode a custom .dat's sprites/level art/levelmap entirely at runtime through the Zig ABI, no editor re-import step. Verified against a real third-party community level (mario3.dat, aiei.ch) — correct rendering, 8.6ms load.
- **TASK-016.02** (In-game level picker): LevelPickerScreen with browse/drag-and-drop/recent-levels list, LevelValidator turning a decode-OK-but-unplayable archive into a specific in-game error, gameplay wiring so a selected custom level's art actually replaces the built-in art during play. Verified via headless-Wayland screenshot capture (all 6 states, including the real error path and pixel-identical custom-vs-builtin gameplay rendering).
- **TASK-016.03** (Optional Zig .mod player): core/mod_player.zig, a from-scratch minimal ProTracker player (no C oracle existed for this one), wired through the ABI and extension so a custom level's bundled bump.mod plays during gameplay instead of the built-in track. AC#2 (playback quality) confirmed via real listening comparison (dosbox-x, two machines): "The WAVs sound perfect."

AC#2 (community .dat loads and plays correctly) and AC#3 (malformed .dat produces a clear in-game error, not a crash) were both established by 016.01/016.02's own verification and remain true; 016.03 added no regression to either path.

`task check` passes clean at HEAD (zig test/difftest/abi/abitest, all validators, 56/56 gdUnit4 cases, extension build).
<!-- SECTION:FINAL_SUMMARY:END -->
