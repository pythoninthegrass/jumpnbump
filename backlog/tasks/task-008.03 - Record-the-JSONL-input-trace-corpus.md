---
id: TASK-008.03
title: Record the JSONL input-trace corpus
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-1
dependencies: []
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
- [ ] #1 The corpus is committed under a fixed path (e.g. tests/corpus/) and covers every mechanic listed in the description at least once
- [ ] #2 Each corpus file includes both the scripted inputs and the expected per-frame checksums from the C oracle
- [ ] #3 A README in the corpus directory documents the trace format and how to add new traces
<!-- AC:END -->
