---
id: m-4
title: "Phase 4: C ABI and GDExtension"
---

## Description

Freeze a frozen C ABI header for the Zig simulation core (opaque world, caller-owned memory, two-call buffer convention, static-asserted struct sizes) and build the godot-cpp GDExtension shim that forwards 1:1 to it, including the macOS arm64 framework bundle.
