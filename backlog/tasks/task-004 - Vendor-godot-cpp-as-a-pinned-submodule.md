---
id: TASK-004
title: Vendor godot-cpp as a pinned submodule
status: Done
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
- [x] #1 third_party/godot-cpp exists as a git submodule pinned to a specific commit SHA
- [x] #2 gdextension/extension_api json for API version 4.7 is present via the submodule
- [x] #3 README or docs note explains why a SHA pin was chosen over a tag
<!-- AC:END -->

## Notes

<!-- SECTION:NOTES:BEGIN -->
Pinned at `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5` (godot-cpp `master`,
2026-09-15), detached HEAD, `git submodule status` clean. `extension_api-4-7.json`
under the submodule reports `Godot Engine v4.7.stable.official`, matching the
`godot 4.7.1-stable` pin in `.tool-versions`. Rationale for a SHA pin is in
`extension/README.md`.

Deviation from the task text: godot-cpp has no `4.7` branch. Since 10.x it versions
itself independently of Godot (one `master` branch for Godot 4.3-4.7; the Godot
version is the `api_version` SCons option), and the newest `godot-4.x-stable` tag is
`godot-4.5-stable`, whose bindings predate 4.7. Verified with
`git ls-remote --heads https://github.com/godotengine/godot-cpp`: branches stop at
`4.5`. The pin is therefore the SHA on `master` that carries the 4.7 API JSON — same
URL and detached-SHA approach as `~/git/neo_snake`, whose own pin (`6cceaf6`, also
carrying `extension_api-4-7.json`) is likewise not a tag or a 4.7 branch.
`task check` (the documented gate, currently `make`) passes with the submodule added.
<!-- SECTION:NOTES:END -->
