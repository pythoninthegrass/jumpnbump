---
id: decision-001
title: 'Screensaver delivery: native Swift/Metal linking core/ directly, not embedded Godot'
date: '2026-09-19 00:00'
status: Accepted
---
## Context

TASK-017.01 is the required pre-work spike before any TASK-017 screensaver-specific UI work
begins: evaluate whether a Godot runtime can realistically be embedded inside a macOS
`ScreenSaverView` subclass, or whether the documented fallback -- a native Swift/Metal view
linking the same Zig core and exported sprite atlases directly, bypassing Godot for this one
delivery path -- should be used instead.

Findings, in order of how directly they bear on the decision:

1. **Godot ships no first-party embeddable-view API for macOS.** The 4.7.1 export pipeline this
   repo already exercises (TASK-009) produces a complete, `NSApplication`-owning `.app` bundle --
   there is no supported "Godot as an `NSView`" target. Stock Godot is one process = one engine
   singleton = one window; it does not offer a way to render into a caller-provided view inside
   someone else's process.

2. **The closest real embedding path (SwiftGodotKit, by Miguel de Icaza) is third-party, not
   Godot's own, and still doesn't give true in-view rendering on macOS.** It builds a custom
   `libgodot.xcframework` (Metal-only, `scons ... library_type=shared_library`) and does support
   macOS as a target. But its own documentation flags that "true embedded rendering"
   (`--display-driver embedded`, i.e. actually drawing into the caller's view rather than opening
   its own OS window) needs a `libgodot` build that specifically "registers the embedded display
   driver" -- an unusual, non-default configuration as of Godot 4.6. The default consumption
   path still uses the plain `macos`/`headless` display driver, meaning even SwiftGodotKit's
   macOS story still has Godot owning its own window in the common case. Building and
   indefinitely maintaining a patched `libgodot` fork solely to unlock real in-view rendering is a
   large, open-ended toolchain burden -- disproportionate to shipping a fireworks screensaver.

3. **Godot's own in-progress "macOS window embedding" work (godot-proposals #11453, landed as a
   dev feature around 4.5) solves a different problem.** It lets the Godot *editor* embed a
   separately-running game process's window via inter-process framebuffer relay -- an editor UX
   feature for play-testing, not a general "embed Godot inside any third-party host app" API, and
   not something `ScreenSaverView`'s process model could use regardless (a screensaver isn't a
   process that hosts a child game process the way the editor does).

4. **`ScreenSaverView`'s execution environment is a poor fit for a full engine runtime
   independent of the above.** It's an `NSView` subclass hosted inside another process (System
   Settings' preview pane, or the `legacyScreenSaver`/loginwindow host at idle time), with no
   `NSApplication` of its own, a restricted lifecycle (`startAnimation`/`stopAnimation`/
   `animateOneFrame`, no normal app entry point), and no guarantee of being the only such view --
   System Settings can host multiple `ScreenSaverView` previews concurrently in its picker UI.
   That's exactly the multi-instance, foreign-host-process scenario stock Godot is not designed
   for.

5. **Third-party screensavers on macOS are independently precarious, regardless of the Godot
   question.** Apple has made the `ScreenSaverView` plugin path progressively more hostile since
   Catalina; first-party screensavers have already moved to a new App Extension format not yet
   available to third parties. This is a platform risk shared equally by *either* candidate
   delivery mechanism -- it doesn't favor embedded-Godot vs. native, but it's worth flagging as a
   real risk to TASK-017.03 regardless of which one is chosen.

6. **This repo already has a ready-made, Godot-independent embedding surface.**
   `include/jumpnbump.h` -- the frozen `jnb_*` C ABI `core/abi.zig` exports (TASK-012) -- is
   exactly the boundary a native Swift view would need, and it's already proven: `extension/`'s
   GDExtension shim consumes this identical header 1:1 today. A Swift target can link
   `core/zig-out/lib/libjumpnbump.a` through that same header with zero new export surface, and
   read the already-exported sprite atlas PNGs/JSON frame manifests (`game/content/sprites/*`,
   TASK-013.01) directly for rendering -- no Godot runtime, no Godot project, no third-party
   embedding SDK, and no multi-hundred-megabyte engine binary bundled inside a screensaver plugin.

## Decision

Deliver the fireworks screensaver as a **native Swift/Metal `ScreenSaverView`**, linking
`core/`'s Zig static library directly via `include/jumpnbump.h`, and reading the sprite atlas
PNGs/JSON manifests exported by TASK-013.01 directly for rendering. Do not pursue embedded Godot
for this delivery path.

## Consequences

- **TASK-017.02** (porting `fireworks.c`'s behavior into the Zig core) is unaffected by this
  choice either way -- that porting work stays scoped to `core/` and the frozen ABI exactly as
  already planned, regardless of which delivery mechanism eventually consumes it.
- **TASK-017.03** gains implied scope beyond "implement whichever the spike recommended": a new
  Swift target (a fourth sibling build graph alongside `core/build.zig`, `extension/SConstruct`,
  and the legacy `Makefile` -- see `docs/build-layout.md`'s "Build systems" section), a Swift
  wrapper around `jnb_*` calls (the Swift-side equivalent of what `extension/`'s C++ shim does via
  godot-cpp), and its own asset-loading path for the exported sprite PNGs/JSON manifests -- no
  `.tres`/`AtlasTexture` resources, those are Godot-specific.
- TASK-017.03 does **not** depend on `extension:build-macos`, `game:import`, or any part of the
  Godot `game/` project -- this delivery path never touches Godot.
- Signing/notarization for the resulting `.saver` bundle needs its own task, separate from
  `taskfiles/release.yml`'s Godot export path (TASK-009): a `.saver` isn't a Godot export
  product, so it won't use `game/export_presets.cfg`. It will need a plain Xcode-archive-and-sign
  flow, likely adapting the same ephemeral-keychain/notarize primitives `release.yml` already
  has, rather than Godot's own `codesign/notarization` preset keys.
- If the platform-level screensaver-hostility risk (finding 5) worsens enough that
  `ScreenSaverView` stops being viable on some future macOS release, that risk applies to this
  decision no more or less than it would have to embedded Godot -- it is not a reason to revisit
  this choice on its own.
