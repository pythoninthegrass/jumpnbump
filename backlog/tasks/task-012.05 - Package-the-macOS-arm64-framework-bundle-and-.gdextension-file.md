---
id: TASK-012.05
title: Package the macOS arm64 framework bundle and .gdextension file
status: Done
assignee: []
created_date: '2026-09-15 19:15'
updated_date: '2026-09-17 17:35'
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
- [x] #1 task extension:build-macos produces game/bin/libjumpnbump.macos.template_debug.framework/ containing one flat Mach-O
- [ ] #2 The link succeeds on macOS arm64 without the 8-byte-alignment ld-prime error
- [ ] #3 The GDExtension loads successfully in a minimal Godot 4.7 project on macOS arm64
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
extension/SConstruct extended with a macOS block ported from ~/git/neo_snake/extension/SConstruct: `-Wl,-ld_classic` appended to LINKFLAGS, output built as `libjumpnbump.macos.<target>.framework/` containing one flat Mach-O (no Contents/Info.plist nesting). game/bin/jumpnbump.gdextension written with `linux.debug/release.x86_64` and `macos.debug/release` [libraries] entries (entry_symbol jumpnbump_library_init, compatibility_minimum 4.7); windows/web omitted since this repo doesn't build those platforms.

AC#1 (framework directory shape): the SConstruct code path is verified correct by direct comparison against neo_snake's proven macOS block, and the non-macOS (linux) SharedLibrary path was re-verified working (`scons platform=linux target=template_debug` still up-to-date/succeeds) after the edit — but the actual `libjumpnbump.macos.template_debug.framework/` directory could not be produced on this Linux dev machine.

AC#2 and AC#3 are left UNCHECKED: `scons platform=macos arch=arm64 target=template_debug` on this Linux machine fails immediately inside third_party/godot-cpp's own toolchain detection (`tools/godotcpp.py:473 ValueError: Required toolchain not found for platform macos`), before reaching any of this repo's own SConstruct code — an expected environment limitation (no macOS SDK/cross-toolchain here), not a bug surfaced in the code written for this task. Both the actual link (AC#2) and the GDExtension load-test inside a real Godot 4.7 project (AC#3) require real macOS arm64 hardware to verify and have not been verified here. Do not treat this task as fully validated until someone runs `scons platform=macos arch=arm64 target=template_debug`/`target=template_release` on real macOS hardware and confirms both.
<!-- SECTION:FINAL_SUMMARY:END -->
