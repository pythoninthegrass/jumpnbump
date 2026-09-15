---
id: TASK-007
title: 'Refresh README, docs, and release assets'
status: To Do
assignee: []
created_date: '2026-09-15 19:12'
labels: []
milestone: m-7
dependencies: []
priority: low
type: docs
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update the README and docs/ to describe the new Zig-core + Godot architecture instead of the retired SDL 1.2 build, including build/run instructions via `task`, and prepare release assets (screenshots, changelog) for the first Godot-based release.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 README describes the current architecture and how to build/run via task, not the old ./configure-era SDL instructions
- [ ] #2 A CHANGELOG or release notes entry documents the port from SDL/C to Zig/Godot
- [ ] #3 Release assets (at least one gameplay screenshot) are attached to the GitHub release
<!-- AC:END -->
