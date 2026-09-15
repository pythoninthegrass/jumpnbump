---
id: TASK-005
title: Write porting-playbook.md and build-layout.md
status: To Do
assignee: []
created_date: '2026-09-15 19:12'
labels: []
milestone: m-0
dependencies: []
priority: medium
type: docs
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write docs/porting-playbook.md adapting zelda3's incremental C-to-Zig methodology (~/git/zelda3/docs/porting-playbook.md) to Jump'n'Bump: one .c subsystem at a time, ABI-compatible exports so remaining C links unchanged, never delete the .c reference, no @import between two ported modules, three-tier verification (unit/differential/oracle). Write docs/build-layout.md documenting the target directory layout and how core/, include/, extension/, game/, and tools/ fit together, adapting ~/git/neo_snake/docs/build-layout.md.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 docs/porting-playbook.md exists and documents the incremental porting rules and verification tiers specific to Jump'n'Bump's integer-only, no-float simulation state
- [ ] #2 docs/build-layout.md exists and documents the full target directory layout
- [ ] #3 Both docs are linked from AGENTS.md
<!-- AC:END -->
