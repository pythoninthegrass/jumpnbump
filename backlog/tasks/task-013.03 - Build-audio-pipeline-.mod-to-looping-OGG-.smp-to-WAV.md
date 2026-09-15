---
id: TASK-013.03
title: 'Build audio pipeline: .mod to looping OGG, .smp to WAV'
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-013
priority: high
type: task
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build a tools/ pipeline script that renders bump.mod, jump.mod, and scores.mod to looping OGG Vorbis files using a pinned openmpt123 build (version pinned in .tool-versions or a toolchain lock file, matching neo_snake's tools/game_toolchain.lock pattern), with real loop points since the originals loop indefinitely. Convert the raw .smp sound effects (death, fly, jump, splash, spring) to WAV. Add a --check reproducibility gate following neo_snake's audio:check/audio:music-check pattern (note: OGG Vorbis encoding is not guaranteed bit-identical across platforms, so gate that check to one platform as neo_snake does).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 bump.mod/jump.mod/scores.mod are rendered to looping OGG files with correct loop points, committed under game/content/audio/
- [ ] #2 death.smp/fly.smp/jump.smp/splash.smp/spring.smp are converted to WAV with correct sample rate and are committed alongside
- [ ] #3 A --check gate verifies WAV output is byte-identical on rebuild; the OGG check is documented as single-platform only, matching the neo_snake precedent
- [ ] #4 openmpt123's exact version is pinned, not resolved from PATH
<!-- AC:END -->
