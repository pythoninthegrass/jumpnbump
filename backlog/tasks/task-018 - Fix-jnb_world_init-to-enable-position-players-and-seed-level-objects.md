---
id: TASK-018
title: Fix jnb_world_init to enable/position players and seed level objects
status: To Do
assignee: []
created_date: '2026-09-18 00:47'
labels:
  - core
  - abi
  - blocking
dependencies: []
priority: high
type: bug
ordinal: 61000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Discovered while building TASK-014.07's gdUnit4 corpus-replay suite: core/abi.zig's jnb_world_init (TASK-012.02, already marked Done) never enables, positions, or seeds any player. jnb_config only carries abi_version/rng_seed/flies_enabled -- there is no jnb_* export to flip player.enabled, position a player, or seed level springs/butterflies. main.c's headless setup calls position_player() per enabled player and seeds level objects via init_level(); core/game_loop_difftest.zig's own Tier-B replay reproduces this manually, entirely bypassing the ABI.

Confirmed empirically: after jnb_world_init(), player 0 stays enabled=0 forever, even after stepping. All 10 traces in the Phase 1 corpus (tests/corpus/*.jsonl) diverge from frame 0 as a result. 3 of the 10 traces are AI-driven and hit a second, independent gap: no ai_mask exposure on the ABI either.

This blocks TASK-014.07's AC#1 (task game:test passes) and AC#3 (every corpus trace replays with matching checksums), and therefore blocks TASK-014's parent AC#3 (corpus replay matches checksums frame-for-frame under gdUnit4). game/tests/test_gdextension_present.gd's test_a_fresh_world_never_enables_any_player documents and locks in the current (broken) behavior so this fix trips it loudly when made.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 core/abi.zig exposes jnb_* export(s) to enable/position a player (mirroring main.c's position_player() call per enabled player)
- [ ] #2 core/abi.zig exposes jnb_* export(s) to seed level objects (springs/butterflies) mirroring main.c's init_level()
- [ ] #3 AI-driven players are controllable via an exposed ai_mask on the ABI
- [ ] #4 game/tests/test_corpus_replay.gd's test_every_corpus_trace_replays_with_matching_checksums passes for all 10 Phase 1 corpus traces
- [ ] #5 task game:test passes headlessly
<!-- AC:END -->
