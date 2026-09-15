---
id: TASK-004
title: Vendor godot-cpp as a pinned submodule
status: To Do
assignee: []
created_date: '2026-09-15 19:12'
labels: []
milestone: m-0
dependencies: []
priority: medium
type: chore
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add third_party/godot-cpp as a git submodule, pinned to a specific commit SHA on the 4.7 branch (not a tag), matching the approach in ~/git/neo_snake/third_party/godot-cpp. This is required before the GDExtension shim work in Phase 4 can begin.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 third_party/godot-cpp exists as a git submodule pinned to a specific commit SHA
- [ ] #2 gdextension/extension_api json for API version 4.7 is present via the submodule
- [ ] #3 README or docs note explains why a SHA pin was chosen over a tag
<!-- AC:END -->
