---
id: TASK-012.04
title: Build the godot-cpp GDExtension shim
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-012
priority: high
type: task
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build extension/ following neo_snake's extension/ pattern: a SConstruct linking the Zig static lib via env.File(...) in LIBS (never a bare -l/-L flag, so a rebuilt core triggers a relink) plus env.Depends, a register_types.cpp with the standard godot-cpp init/terminate boilerplate, and a JumpnbumpWorld : RefCounted GDCLASS in extension/src/ whose every method forwards 1:1 to a jnb_* call with no game logic of its own. The world's backing memory is a std::vector<uint8_t> over-allocated by jnb_world_align()-1, with an aligned pointer carved out manually.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 scons builds a shared library on Linux that exposes JumpnbumpWorld to GDScript
- [ ] #2 Every JumpnbumpWorld method is a thin forward to exactly one jnb_* call, verifiable by reading the .cpp
- [ ] #3 custom.py sets use_static_cpp = False to avoid the static libstdc++ dependency issue neo_snake documented
<!-- AC:END -->
