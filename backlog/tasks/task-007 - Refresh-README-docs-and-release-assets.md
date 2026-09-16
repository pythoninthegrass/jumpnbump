---
id: TASK-007
title: 'Refresh README, docs, and release assets'
status: In Progress
assignee:
  - pythoninthegrass
created_date: '2026-09-15 19:12'
updated_date: '2026-09-15 22:26'
labels: []
milestone: m-7
dependencies: []
priority: low
type: docs
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update the README and docs/ to describe the new Zig-core + Godot architecture instead of the retired SDL 1.2 build, including build/run instructions via `task`, and prepare release assets (screenshots, changelog) for the first Godot-based release.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 README describes the current architecture and how to build/run via task, not the old ./configure-era SDL instructions
- [ ] #2 A CHANGELOG or release notes entry documents the port from SDL/C to Zig/Godot
- [ ] #3 Release assets (at least one gameplay screenshot) are attached to the GitHub release
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Scope for this pass (approved 2026-09-15): write a new README.md describing the port-in-progress honestly (task orchestration, core/build.zig steps, CI, SDL build still the only playable path), archive the legacy README verbatim to docs/legacy-readme.md. No CHANGELOG (deferred to release-please). AC#3 (release + screenshot) is blocked: no Godot build exists yet, no tags/releases exist. Phases 1-6 (TASK-008..017) are all To Do, so AC#1's "not the old SDL instructions" is satisfied by describing target architecture + honest current status, not by retiring the SDL build (it's still the only way to play). Leaving task In Progress (not Done) after this pass; AC#2/AC#3 remain unchecked with notes explaining why.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC#1 done: new README.md at repo root describes the port honestly (target architecture, current scaffolding-only status, task check / zig build steps, and the legacy SDL build as the current playable path with corrected apt package names matching taskfiles/ci.yml). Legacy README archived verbatim to docs/legacy-readme.md.

AC#2 intentionally skipped this pass per Lance: CHANGELOG will be generated later via release-please, not hand-written now.

AC#3 blocked: no Godot build exists yet to screenshot, and git tag / gh release list are both empty. Unblocks after Phase 6 (TASK-015) produces a playable Godot build. Revisit then.

Verified: `task check` builds the legacy binary successfully; `zig build --help` in core/ confirms the four step names (test, difftest, abi, abitest) match what the README documents; all relative links in README.md resolve to existing files.

Out of scope, flagged for follow-up: committed/untracked build artifacts (*.o, sdl.a, jumpnbump binary, gobpack/jnbpack/jnbunpack) sit against a 635-byte .gitignore. Not touched here.
<!-- SECTION:NOTES:END -->
