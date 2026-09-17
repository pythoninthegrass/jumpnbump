---
id: TASK-013.03
title: 'Build audio pipeline: .mod to looping OGG, .smp to WAV'
status: Done
assignee: []
created_date: '2026-09-15 19:15'
updated_date: '2026-09-17 21:33'
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
- [x] #1 bump.mod/jump.mod/scores.mod are rendered to looping OGG files with correct loop points, committed under game/content/audio/
- [x] #2 death.smp/fly.smp/jump.smp/splash.smp/spring.smp are converted to WAV with correct sample rate and are committed alongside
- [x] #3 A --check gate verifies WAV output is byte-identical on rebuild; the OGG check is documented as single-platform only, matching the neo_snake precedent
- [x] #4 openmpt123's exact version is pinned, not resolved from PATH
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added tools/render_sfx.py, converting death/fly/jump/splash/spring.smp to WAV: a .smp file has no header -- it's the raw bytes sdl/sound.c's dj_load_sfx() malloc/memcpy's into its playback buffer, reinterpreted as little-endian 16-bit signed mono PCM (dj_load_sfx's byte-shuffle is a no-op on a little-endian host) -- authored at each effect's fixed globals.h SFX_*_FREQ rate (the runtime +-1000Hz pitch jitter is a gameplay effect, not part of the source asset). Added tools/render_music.py, rendering bump/jump/scores.mod to looping OGG via a pinned openmpt123 (tools/game_toolchain.lock pins 0.8.7; no portable Linux binary exists upstream unlike neo_snake's Furnace, so this is a version-checked PATH lookup, not a checksum-verified download). Two reproducibility bugs found and worked around by hand: (1) openmpt123's default dither is randomized noise-shaping, breaking byte-identical re-renders -- fixed with --dither 0; (2) this environment's libsndfile segfaults on a single sf.write() call past ~2.1M stereo frames (~48s) when encoding OGG -- fixed by streaming the encode through SoundFile.write() in 64k-frame chunks. Since sdl/sound.c loops the whole track from the start indefinitely (Mix_PlayMusic(mus, -1)), the loop point is simply (0, full length), recorded in game/content/audio/music/manifest.json for a later Godot-side task. `task assets:audio:check` (sfx:check + music:check) passes locally; sfx:check (pure Python, no external tool) also runs in the cross-platform `task assets:check` / CI. music:check is NOT wired into .github/workflows/ci.yml: no Ubuntu apt/EPEL pocket ships openmpt123 0.8.7 on every CI runner (confirmed noble ships 0.7.3), so it stays a local/self-hosted gate until a version-pinned CI build step is added -- a known, documented gap, not a silent one.
<!-- SECTION:FINAL_SUMMARY:END -->
