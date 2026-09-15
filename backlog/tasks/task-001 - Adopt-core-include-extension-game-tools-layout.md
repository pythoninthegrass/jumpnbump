---
id: TASK-001
title: Adopt core/include/extension/game/tools layout
status: Done
assignee: []
created_date: '2026-09-15 19:12'
updated_date: '2026-09-15 19:26'
labels: []
milestone: m-0
dependencies: []
modified_files:
  - AGENTS.md
  - core/README.md
  - include/README.md
  - extension/README.md
  - game/README.md
  - tools/README.md
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
- [x] #1 `make` still builds jumpnbump, gobpack, jnbpack, jnbunpack, and jumpbump.dat with no changes to their behavior
- [x] #2 core/, include/, extension/, game/, tools/ directories exist with placeholder READMEs or initial scaffolding
- [x] #3 A short note in AGENTS.md or docs/ explains why the legacy C tree is retained permanently
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added core/, include/, extension/, game/, tools/ placeholder directories (each with a README describing its eventual contents per the backlog plan) alongside the existing legacy tree, and a \"Target layout\" section in AGENTS.md explaining why main.c/sdl/modify are retained forever (differential-test oracle for TASK-008). Verified `make` still builds jumpnbump, gobpack, jnbpack, jnbunpack, and data/jumpbump.dat unchanged — required building SDL_mixer 1.2 and SDL_net 1.2 from source on this AlmaLinux 10 dev box since only sdl12-compat is packaged there (not a repo change, just local env setup).
<!-- SECTION:FINAL_SUMMARY:END -->
