---
id: TASK-008.03
title: Record the JSONL input-trace corpus
status: Done
assignee:
  - pythoninthegrass
created_date: '2026-09-15 19:14'
updated_date: '2026-09-16 14:42'
labels: []
milestone: m-1
dependencies: []
modified_files:
  - globals.pre
  - main.c
  - tests/corpus/01-single-player-basic.jsonl
  - tests/corpus/01-single-player-basic.meta.json
  - tests/corpus/02-two-player-manual.jsonl
  - tests/corpus/02-two-player-manual.meta.json
  - tests/corpus/03-two-player-ai-kill.jsonl
  - tests/corpus/03-two-player-ai-kill.meta.json
  - tests/corpus/04-two-player-ai-kill-nogore.jsonl
  - tests/corpus/04-two-player-ai-kill-nogore.meta.json
  - tests/corpus/05-four-players-ai.jsonl
  - tests/corpus/05-four-players-ai.meta.json
  - tests/corpus/06-water-immersion.jsonl
  - tests/corpus/06-water-immersion.meta.json
  - tests/corpus/07-spring-bounce.jsonl
  - tests/corpus/07-spring-bounce.meta.json
  - tests/corpus/08-ice-slide.jsonl
  - tests/corpus/08-ice-slide.meta.json
  - tests/corpus/09-flies-off.jsonl
  - tests/corpus/09-flies-off.meta.json
  - tests/corpus/README.md
parent_task_id: TASK-008
priority: high
type: task
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Using the headless deterministic mode, record and commit a corpus of scripted input traces covering the game's mechanics: 1 to 4 players, AI on and off, water/ice/spring tile interactions, gore on/off, flies on/off, spring bounces, and drownings. Each trace should be a JSONL file of per-tick inputs plus the resulting checksum trail, similar in spirit to neo_snake's committed corpus under game/tests/corpus/.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The corpus is committed under a fixed path (e.g. tests/corpus/) and covers every mechanic listed in the description at least once
- [x] #2 Each corpus file includes both the scripted inputs and the expected per-frame checksums from the C oracle
- [x] #3 A README in the corpus directory documents the trace format and how to add new traces
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Extended headless mode to support multiple players and AI (new `-headless-players n` / `-headless-ai mask` flags; moved the headless player-enable step to before init_level() so position_player()'s random-but-seeded placement runs normally instead of leaving players stacked at (0,0)). Used the real binary as ground truth (via a temporary `JNB_HEADLESS_DEBUG_STATE`-gated per-frame debug dump, kept as a documented dev aid) to empirically discover input traces that hit each required mechanic, since deriving exact tile-fall trajectories by hand from the level grid was impractical. Recorded 9 checksummed traces under tests/corpus/ covering 1/2/4 players, AI on/off, gore on/off, flies on/off, water/ice/spring tile contact, and CPU bump-kills. Each trace is a valid `-input` file itself (extra JSON fields are ignored by the parser); a `.meta.json` sidecar records the CLI invocation (seed/players/AI mask/flags) needed to reproduce it.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified every corpus trace twice (byte-identical checksum sequences both times) and confirmed each hits its intended mechanic: 03/05 show nonzero final `bumps` (CPU bump-kill), 04 diverges from 03 exactly at the kill frame under -nogore, 09 diverges from 01 from frame 0 under -noflies (rnd_call_count offset from skipped fly-spawn draws), 06/07/08 were found by an automated search over random input sequences checking in_water/y_add-spike/feet-tile-under-player respectively (see README's debug-aid section).

Discovered game_kill (bump-kill) is a *local* mechanic, not a networking-only one: is_server defaults to 1 even without -net, so player_kill()'s serverSendKillPacket() -> processKillPacket() path runs locally in normal hotseat play too. This game has no water-death/drowning mechanic — water is buoyancy-only (in_water toggling); documented that interpretation in the corpus README against the task's 'drownings' wording.

The single-player headless dump's x/y now differ from 008.01's committed example (player[0] is randomly-but-deterministically positioned via position_player() instead of parked at (0,0)) because the headless player-enable step moved to before init_level() so position_player() runs for it, same as normal (non-headless) play. No test asserted the old (0,0) values; tests/fixtures/headless-smoke.jsonl still passes its own determinism check.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Recorded the checksummed JSONL input-trace corpus under tests/corpus/, satisfying all three ACs.

**Headless mode extended for multiplayer/AI**: added `-headless-players n` (1-4) and `-headless-ai mask` (bitmask of CPU-controlled players) CLI flags. Moved the headless player-enable step from after `init_level()` to before it, so `position_player()`'s seeded-random placement runs for headless-enabled players exactly as it would in normal play, instead of leaving every enabled player stacked at (0,0).

**Corpus**: 9 trace files (`tests/corpus/*.jsonl` + `*.meta.json` sidecars recording the reproducing CLI invocation) covering 1/2/4 enabled players, AI on/off, gore on/off (`-nogore`), flies on/off (`-noflies`), water/ice/spring tile contact, and the game's only kill mechanic (a CPU or player landing on top of another player — `player_kill()`/`processKillPacket()`, confirmed to run locally even without `-net` since `is_server` defaults to 1). "Drowning" in this codebase is buoyancy-only (no water death), documented as such. Each trace file is itself a valid `-input` file (the parser ignores the embedded `"checksum"` field). tests/corpus/README.md documents the format, the mechanic-coverage table, and how to add new traces — including a `JNB_HEADLESS_DEBUG_STATE`-gated per-frame debug dump (x/y/velocity/in_water/bumps/feet-tile) kept in main.c specifically to make future trace authoring tractable, since deriving exact fall trajectories from the level's tile grid by hand proved impractical; traces here were found by running the real oracle binary against candidate/randomized inputs and checking that debug output.

**Verification**: every corpus trace's checksums were captured from two independent runs of the real `-headless` binary and confirmed byte-identical; final-state `bumps` and the 03-vs-04 (gore) and 01-vs-09 (flies) checksum divergences were inspected directly to confirm each trace exercises what its filename claims. `make clean && make` builds clean (no new warnings) with the debug macro undefined by default.
<!-- SECTION:FINAL_SUMMARY:END -->
