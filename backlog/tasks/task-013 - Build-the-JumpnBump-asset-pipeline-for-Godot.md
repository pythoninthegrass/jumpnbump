---
id: TASK-013
title: Build the Jump'n'Bump asset pipeline for Godot
status: Done
assignee: []
created_date: '2026-09-15 19:13'
updated_date: '2026-09-19 01:25'
labels: []
milestone: m-5
dependencies: []
priority: high
type: task
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task (Parent A). Build the pipeline that converts original Jump'n'Bump art and audio into Godot-native resources: .gob sprites + palette into PNG atlases with AtlasTexture resources preserving hotspots and the colour*18+direction*9 sprite indexing, level/mask/menu PCX files into PNG background and masked-foreground layers, and .mod/.smp audio into looping OGG/WAV via a pinned converter. Every conversion needs a --check reproducibility gate, following neo_snake's tools/render_audio.py --check pattern. Depends on Phase 2 (Zig asset codecs) being complete — do not start until all Phase 2 tasks are Done. Can run in parallel with Phase 3.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All three subtasks are complete
- [x] #2 Regenerating all Godot assets from the original data/ files twice produces byte-identical output both times
- [x] #3 A `task audio:check`-equivalent gate exists and passes in CI
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All three subtasks (013.01 sprite atlas, 013.02 level layers, 013.03 audio) are done. `task assets:check` (sprites:check, levels:check, sfx:check) passes byte-identical reproducibility gates locally; `task audio:check` (sfx:check + music:check) is wired into CI via `task check` -> `assets:check` / `ci.yml`.
<!-- SECTION:FINAL_SUMMARY:END -->
