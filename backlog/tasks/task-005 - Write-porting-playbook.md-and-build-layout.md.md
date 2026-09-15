---
id: TASK-005
title: Write porting-playbook.md and build-layout.md
status: Done
assignee:
  - lance@greyhaven.ai
created_date: '2026-09-15 19:12'
updated_date: '2026-09-15 21:23'
labels: []
milestone: m-0
dependencies: []
modified_files:
  - docs/porting-playbook.md
  - docs/build-layout.md
  - AGENTS.md
  - .markdownlint.jsonc
priority: medium
type: docs
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write docs/porting-playbook.md adapting zelda3's incremental C-to-Zig methodology (~/git/zelda3/docs/porting-playbook.md) to Jump'n'Bump: one .c subsystem at a time, ABI-compatible exports so remaining C links unchanged, never delete the .c reference, no @import between two ported modules, three-tier verification (unit/differential/oracle). Write docs/build-layout.md documenting the target directory layout and how core/, include/, extension/, game/, and tools/ fit together, adapting ~/git/neo_snake/docs/build-layout.md.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 docs/porting-playbook.md exists and documents the incremental porting rules and verification tiers specific to Jump'n'Bump's integer-only, no-float simulation state
- [x] #2 docs/build-layout.md exists and documents the full target directory layout
- [x] #3 Both docs are linked from AGENTS.md
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Adapt zelda3's porting-playbook.md (terse, procedural, named rules) and neo_snake's build-layout.md (consolidated spec, not an append-only ledger per user decision) to Jump'n'Bump.

Confirmed decisions:

- Verification tiers are A-D (unit/differential/abi-conformance/godot-replay), matching core/build.zig's existing comments and neo_snake, not the task's looser "unit/differential/oracle" wording. Tier-B (diff vs renamed-C ref over the TASK-008 corpus) is the oracle tier.
- docs/build-layout.md is a forward-looking spec consolidating the 5 placeholder READMEs (core/include/extension/game/tools), not a per-task rationale ledger.
- In scope: add missing .markdownlint.jsonc (MD013:false) since .pre-commit-config.yaml references it but it doesn't exist; fix stale AGENTS.md:23 line about no test/linter.

Files:

1. docs/porting-playbook.md - Preamble, Procedure, Verify gauntlet, Verification tiers (A-D), Cross-module @import rule, Struct-twin rule, Globals ownership, The no-float rule (main.c has zero float/double vars; only 2 FP call sites total - main.c:1011 sqrt() in get_closest_player_to_point, main.c:2529 atan2() for particle octant selection - both need integer-exact replacements, satisfies TASK-011.08 AC#3 requirement), Core purity, Finalize.
2. docs/build-layout.md - Preamble, Directory layout (core/include/extension/game/tools/third_party + retained legacy tree), Build systems (3 siblings: build.zig/SConstruct/Makefile), zig build steps (test/difftest/abi/abitest), task check wiring, Toolchain (.tool-versions), Constraints (no-libc, single build graph).
3. AGENTS.md - add ## Docs section (after Target layout, before Build, above BACKLOG.MD MCP block) linking both docs; fix stale line 23.
4. .markdownlint.jsonc - new, MD013:false.

Verification: markdownlint, prek run --all-files, task check, cd core && zig build test && zig build abitest.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified all main.c line references (44-45, 1011, 2529) with rg before publishing the no-float section.

Ran: markdownlint via `prek run --all-files` (docs/ and AGENTS.md clean; two unrelated pre-existing failures in the machine-managed BACKLOG.MD block and .agents/skills/gnhf/SKILL.md, out of scope). `task check` (legacy make build) green. `zig build test` and `zig build abitest` in core/ both pass (empty step aggregators, as expected pre-TASK-011/012).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Wrote docs/porting-playbook.md and docs/build-layout.md, adapting zelda3's and neo_snake's reference docs to Jump'n'Bump, and linked both from a new AGENTS.md `## Docs` section.

**docs/porting-playbook.md** — terse, procedural, named-rule style matching zelda3's original: Procedure, Verify gauntlet, a four-tier verification ladder (A=unit, B=differential-vs-renamed-C-oracle, C=ABI conformance, D=Godot corpus replay — chosen over the task's looser "unit/differential/oracle" wording to match core/build.zig's existing step names and neo_snake's convention), the no-`@import`-between-ported-modules rule, struct-twin rule, globals ownership, and a Jump'n'Bump-specific "no-float rule" section: main.c/menu.c/filter.c/fireworks.c/sdl/*.c contain zero float/double variables, and the two remaining FP call sites in the whole simulation (main.c:1011 sqrt in get_closest_player_to_point, main.c:2529 atan2 for particle octant selection) are named with their replacement obligations, satisfying TASK-011.08 AC#3's requirement that the core-purity rule be documented here. Also documents Core purity and the Finalize (branch/commit) convention.

**docs/build-layout.md** — a forward-looking spec (not neo_snake's append-only per-task ledger, per explicit user decision) consolidating the five placeholder READMEs (core/include/extension/game/tools) into one directory-layout reference, the three sibling build systems, the four zig build steps with their Zig-0.16.0-specific gotchas, the target task-check ordering, toolchain pins, and standing constraints (no-libc in core/, single build graph, ABI-export ownership).

**AGENTS.md** — added a `## Docs` section (after Target layout, before Build) linking both files, and replaced the stale "no test suite and no linter" line with the current reality (core/build.zig's four steps, prek/.pre-commit-config.yaml).

**.markdownlint.jsonc** — added (MD013 disabled per the user's soft-wrap convention); .pre-commit-config.yaml already referenced this file but it didn't exist, so the markdownlint hook would have failed on first commit touching any markdown.

Verification: `prek run --all-files` (docs/ and AGENTS.md pass cleanly; two pre-existing, unrelated failures elsewhere left untouched), `task check` (legacy make build, green), `cd core && zig build test && zig build abitest` (green, steps still empty pending TASK-011/012), and every main.c line reference in the no-float section confirmed against the source with rg.
<!-- SECTION:FINAL_SUMMARY:END -->
