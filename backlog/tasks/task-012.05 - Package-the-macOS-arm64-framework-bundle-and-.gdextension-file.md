---
id: TASK-012.05
title: Package the macOS arm64 framework bundle and .gdextension file
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-012
priority: high
type: task
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend the SConstruct to build the macOS variant as a bare *.framework directory (one flat Mach-O of the same name, no Contents/Info.plist nesting) with -Wl,-ld_classic appended to LINKFLAGS (required because Zig's archiver doesn't 8-byte-align archive members and Xcode 26's ld-prime rejects that). Pin arch=arm64 explicitly since a bare scons invocation on macOS defaults to arch=universal and fails against the single-arch Zig .a. Write game/bin/jumpnbump.gdextension with linux/macos/windows library paths matching neo_snake's format.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 task extension:build-macos produces game/bin/libjumpnbump.macos.template_debug.framework/ containing one flat Mach-O
- [ ] #2 The link succeeds on macOS arm64 without the 8-byte-alignment ld-prime error
- [ ] #3 The GDExtension loads successfully in a minimal Godot 4.7 project on macOS arm64
<!-- AC:END -->
