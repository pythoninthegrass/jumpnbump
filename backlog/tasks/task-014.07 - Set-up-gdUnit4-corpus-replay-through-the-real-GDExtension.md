---
id: TASK-014.07
title: Set up gdUnit4 corpus replay through the real GDExtension
status: Done
assignee: []
created_date: '2026-09-15 19:16'
updated_date: '2026-09-18 01:37'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-014
priority: high
type: task
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bootstrap gdUnit4 (matching neo_snake's tools/bootstrap.py pattern, gitignored and pinned by SHA256 rather than vendored) and write a Tier-D test suite that replays the Phase 1 JSONL corpus through the real GDExtension (not a mock), diffing canonical state/checksums frame-for-frame. Add a test_gdextension_present canary asserting the GDExtension class actually loaded, so a broken build fails fast and legibly rather than every other test failing mysteriously.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 task game:test runs headlessly via godot --headless and passes
- [x] #2 test_gdextension_present fails clearly if the GDExtension fails to load
- [x] #3 Every trace in the Phase 1 corpus replays through the real GDExtension with matching checksums frame-for-frame
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Harness built and correct (gdUnit4 bootstrapped, canary + corpus replay suite in place), but AC#1 (task game:test passes) and AC#3 (every trace matches checksums) genuinely fail: core/abi.zig's jnb_world_init never enables/positions any player or seeds level objects, so all 10 corpus traces diverge from frame 0. This is a pre-existing gap in already-Done TASK-012.02, not fixable within this subtask's scope. Filed as TASK-018 (blocking). test_every_corpus_trace_replays_with_matching_checksums is left genuinely red (not skipped/loosened) until TASK-018 lands. AC#2 (canary fails clearly) is met with a minor caveat: GDScript's parse-time class-constant resolution means removing the .so aborts test discovery for all JumpnbumpWorld-dependent files at once, not narrowly isolated to test_gdextension_present alone -- but the failure is immediate and unambiguous either way.

Update: TASK-018 fixed the blocking core/abi.zig gap (player enable/position/level-object seeding, plus two further defects it surfaced: frame_num's off-by-one and stepOneTick not zeroing keyb[] before each tick). All 10 Phase 1 corpus traces now replay through the real GDExtension with matching checksums frame-for-frame; `task game:test` and `task check` both pass end to end. AC#1 and #3 now genuinely met.
<!-- SECTION:NOTES:END -->
