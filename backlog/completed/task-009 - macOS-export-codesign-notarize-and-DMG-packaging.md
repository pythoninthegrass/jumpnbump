---
id: TASK-009
title: 'macOS export, codesign, notarize, and DMG packaging'
status: Done
assignee: []
created_date: '2026-09-15 19:13'
updated_date: '2026-09-19 17:54'
labels: []
milestone: m-7
dependencies: []
priority: medium
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up the Godot macOS export preset (universal binary, hardened runtime, min macOS version), a Developer ID Application codesigning identity, notarization via notarytool with stapling, and DMG packaging, following the release.yml task pattern in ~/git/neo_snake/taskfiles/release.yml (ephemeral keychain setup, export, verify-signing at three levels, decode API key, notarize+staple, defer-based cleanup of keychain and API key regardless of failure). Depends on Phase 6 (playable macOS build) being complete — do not start until all Phase 6 tasks are Done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `task release:ship-macos` produces a signed, notarized DMG from a clean checkout (arm64 GDExtension embedded in a universal-engine .app -- Godot 4.7's macOS export templates only ship a universal engine binary, no arm64-only template exists)
- [x] #2 codesign --verify --deep --strict passes on the .app, the embedded GDExtension framework, and the DMG
- [x] #3 Keychain and decoded API key are cleaned up via defer: even when export or notarization fails
- [x] #4 Secrets (certificate, its password, and the App Store Connect API key) are read from environment variables (.env, gitignored), never committed. The Developer ID signing identity string in game/export_presets.cfg is committed -- it's a Common Name embedded in every signed binary regardless, not a secret.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Ported ~/git/neo_snake's taskfiles/release.yml pattern (itself mirroring ~/git/mt's) rather than inventing a new one. Scope decisions (confirmed with Lance before implementing): arm64-only GDExtension (core/build.zig and extension/SConstruct are both single-arch; a true universal build needs a second -Dtarget Zig pass + lipo, deferred); bundle identifier com.pythoninthegrass.jumpnbump; signing identity committed like neo_snake (not templated); launchctl asuser SSH-signing bridge included.

New: game/export_presets.cfg, taskfiles/release.yml, game/icon.png (+ tools/build_app_icon.py, cropped from the already-committed rabbit sprite atlas), .env.example. Extended: taskfiles/extension.yml (extension:build-macos, builds both template_debug and template_release), taskfiles/game.yml (game:import), taskfile.yml (dotenv + release include), game/project.godot (config/icon, rendering/textures/vram_compression/import_etc2_astc=true -- required for any arm64/universal macOS export), .gitignore (/game/build/, .env).

Real-world gotchas found only by actually running the pipeline (not in the neo_snake port source):
1. ETC2/ASTC texture import must be enabled in project settings or export fails outright for arm64/universal.
2. Godot 4.7.1's macOS export templates ship ONLY a universal (arm64+x86_64) engine binary -- selecting binary_format/architecture="arm64" in the preset fails with "template binary godot_macos_release.arm64 not found". Had to set architecture="universal" (matching what neo_snake's preset already does, for the same reason I initially missed). The GDExtension framework itself stays arm64-only; only the engine binary is fat.
3. export_templates/4.7.1.stable/macos.zip is downloaded but not auto-extracted on a fresh mise/godot install -- needed a one-time manual unzip before export would find the template at all.
4. The sudoers.d NOPASSWD launchctl asuser entry already existed on this host (mini) from prior neo_snake work, so the bridge worked first try once the above were fixed.

Verified end to end against live Apple infrastructure on mini: task release:ship-macos ran clean, notarization Accepted, stapling succeeded, spctl -a -vv --type open --context context:primary-signature reported accepted / source=Notarized Developer ID. Forced a mid-pipeline failure (missing architecture template, pre-fix) and confirmed keychain-cleanup's defer: ran and removed the ephemeral keychain anyway.

Documented all of the above in docs/build-layout.md's new "macOS release" section.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ported ~/git/neo_snake's macOS sign/notarize/DMG taskfile pattern to jumpnbump. New: game/export_presets.cfg, taskfiles/release.yml (ship-macos/keychain-setup/export-macos/verify-signing/notarize with defer: cleanup), game/icon.png + tools/build_app_icon.py, .env.example. Extended extension.yml/game.yml/taskfile.yml/project.godot/.gitignore.

Verified end to end against live Apple infrastructure: notarization Accepted, stapled, spctl reports accepted/Notarized Developer ID. Confirmed keychain+API-key cleanup runs via defer: even on a forced mid-pipeline failure.

Scope note: GDExtension is arm64-only (Zig core/SCons build are single-arch); the export preset's engine binary is "universal" only because Godot 4.7.1 ships no arm64-only macOS template. True universal (including the extension) is future work. Full writeup in docs/build-layout.md's "macOS release" section.
<!-- SECTION:FINAL_SUMMARY:END -->
