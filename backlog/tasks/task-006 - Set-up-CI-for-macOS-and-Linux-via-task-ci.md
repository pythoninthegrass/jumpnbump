---
id: TASK-006
title: 'Set up CI for macOS and Linux via task ci:*'
status: To Do
assignee: []
created_date: '2026-09-15 19:12'
labels: []
milestone: m-0
dependencies: []
priority: medium
type: chore
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add GitHub Actions workflows with a macOS job (self-hosted arm64, matching ~/git/neo_snake/.github/workflows/ci.yml) and a Linux job, where every CI step is a one-line `task ci:*` wrapper so the same checks are runnable locally. Initially this only needs to run `task check` as defined so far (Phase 0's wrapped `make` build); later phases extend the chain.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `.github/workflows/ci.yml` runs on both a macOS and a Linux job
- [ ] #2 Every CI step is a thin `task ci:*` wrapper defined in taskfiles/ci.yml, runnable locally
- [ ] #3 CI passes on the current (Phase 0) state of the repo
<!-- AC:END -->
