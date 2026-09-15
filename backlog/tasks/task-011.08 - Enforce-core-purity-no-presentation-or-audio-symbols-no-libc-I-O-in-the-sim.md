---
id: TASK-011.08
title: 'Enforce core purity: no presentation or audio symbols, no libc I/O in the sim'
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-3
dependencies: []
parent_task_id: TASK-011
priority: medium
type: task
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a build-time or CI check (following neo_snake's tools/validate_audio_boundary.py pattern) that fails if the Zig simulation core references any presentation concept (pob lists, page flipping, draw calls) or audio symbol, or performs libc file I/O outside the explicitly asset-loading paths. The sim core must be a pure, deterministic state machine.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A CI-wired check greps or symbol-scans core/ and fails on any presentation or audio symbol reference from the sim module
- [ ] #2 The check passes on the completed Phase 3 core
- [ ] #3 The check is documented in docs/porting-playbook.md as a standing rule for future changes
<!-- AC:END -->
