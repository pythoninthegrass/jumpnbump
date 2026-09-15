---
id: TASK-001
title: Adopt core/include/extension/game/tools layout
status: To Do
assignee: []
created_date: '2026-09-15 19:12'
labels: []
milestone: m-0
dependencies: []
priority: high
type: chore
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Introduce the target directory layout (core/, include/, extension/, game/, tools/) alongside the existing top-level C sources, sdl/, and modify/ without breaking `make`. The existing SDL C build must keep working throughout this whole port — main.c, sdl/, and modify/ are retained forever as the differential-test reference and are never deleted.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `make` still builds jumpnbump, gobpack, jnbpack, jnbunpack, and jumpbump.dat with no changes to their behavior
- [ ] #2 core/, include/, extension/, game/, tools/ directories exist with placeholder READMEs or initial scaffolding
- [ ] #3 A short note in AGENTS.md or docs/ explains why the legacy C tree is retained permanently
<!-- AC:END -->
