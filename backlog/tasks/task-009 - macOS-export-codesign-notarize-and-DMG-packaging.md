---
id: TASK-009
title: 'macOS export, codesign, notarize, and DMG packaging'
status: To Do
assignee: []
created_date: '2026-09-15 19:13'
labels: []
milestone: m-7
dependencies: []
priority: medium
type: chore
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up the Godot macOS export preset (universal binary, hardened runtime, min macOS version), a Developer ID Application codesigning identity, notarization via notarytool with stapling, and DMG packaging, following the release.yml task pattern in ~/git/neo_snake/taskfiles/release.yml (ephemeral keychain setup, export, verify-signing at three levels, decode API key, notarize+staple, defer-based cleanup of keychain and API key regardless of failure). Depends on Phase 6 (playable macOS build) being complete — do not start until all Phase 6 tasks are Done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `task release:ship-macos` produces a signed, notarized DMG from a clean checkout
- [ ] #2 codesign --verify --deep --strict passes on the .app, the embedded GDExtension framework, and the DMG
- [ ] #3 Keychain and decoded API key are cleaned up via defer: even when export or notarization fails
- [ ] #4 Secrets (signing identity, certificate, App Store Connect API key) are read from environment variables, never committed
<!-- AC:END -->
