---
id: TASK-017.01
title: 'Spike: evaluate macOS screensaver delivery mechanisms'
status: Done
assignee: []
created_date: '2026-09-15 19:16'
updated_date: '2026-09-19 18:02'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-017
priority: low
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Before any screensaver-specific UI work begins, spike whether a Godot runtime can realistically be embedded inside a macOS ScreenSaverView subclass, and if not, evaluate the fallback of a native Swift/Metal view linking the same Zig core and exported sprite atlases directly (bypassing Godot for this one delivery path). Produce a written recommendation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The spike produces a written recommendation (in a decision doc) choosing embedded-Godot, native-Swift/Metal, or another approach, with rationale
- [x] #2 The recommendation is made before any further screensaver task begins
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Researched rather than prototyped: building a real embedded-Godot spike would have required building a custom libgodot fork with a non-default "embedded" display driver just to test feasibility, which is disproportionate for a de-risking spike. Instead verified via Godot's own capabilities, the community SwiftGodotKit project (the only real macOS embedding path that exists), the godot-proposals macOS-window-embedding issue, and current ScreenSaverView/macOS screensaver platform constraints.

Recommendation: native Swift/Metal ScreenSaverView linking core/'s Zig static library directly via include/jumpnbump.h (the same frozen ABI extension/'s GDExtension shim already consumes), reading the exported sprite atlas PNGs/JSON manifests directly. Not embedded Godot -- no first-party embedding API exists, the only third-party path (SwiftGodotKit) still doesn't give true in-view rendering without a custom libgodot build, and ScreenSaverView's process model (no NSApplication, foreign host process, possible multiple concurrent instances) is a poor fit for a full engine runtime regardless.

Full writeup with sources/rationale: backlog/decisions/decision-001 - Screensaver-delivery-native-Swift-Metal-not-embedded-Godot.md
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike complete. Recommendation: deliver the fireworks screensaver as a native Swift/Metal ScreenSaverView linking core/'s Zig static library via include/jumpnbump.h directly, not embedded Godot. No viable first-party or even mature third-party path exists to embed Godot's renderer inside a foreign host view/process on macOS; the only community attempt (SwiftGodotKit) still requires a custom libgodot build for true in-view rendering. Full rationale in backlog/decisions/decision-001.
<!-- SECTION:FINAL_SUMMARY:END -->
