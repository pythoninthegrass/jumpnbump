---
id: TASK-008
title: Establish the C build as the differential oracle
status: To Do
assignee: []
created_date: '2026-09-15 19:12'
labels: []
milestone: m-1
dependencies: []
priority: high
type: task
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task. Every subsystem ported to Zig in Phase 3 must be verified against the original C behavior. This phase makes that possible: run the existing SDL C build headlessly and deterministically, dump canonical state with a checksum every frame, record a corpus of input traces covering the game's mechanics, and build the differential-test harness that will compile the pre-port .c a second time under renamed symbols and diff its output against the Zig port. This phase gates all of Phase 3 — no simulation code should be ported to Zig until the oracle corpus exists.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All four subtasks are complete and the resulting corpus + harness can validate a trivial Zig stub against the C original
<!-- AC:END -->
