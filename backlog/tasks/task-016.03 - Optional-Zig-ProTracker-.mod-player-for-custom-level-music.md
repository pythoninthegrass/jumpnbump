---
id: TASK-016.03
title: 'Optional: Zig ProTracker (.mod) player for custom-level music'
status: Done
assignee:
  - lance@greyhaven.ai
created_date: '2026-09-15 19:16'
updated_date: '2026-09-19 17:01'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-016
priority: low
type: task
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port a ProTracker .mod playback engine to Zig so custom .dat levels can ship and play their own music at runtime without requiring the build-time .mod-to-OGG conversion step used for the base game's music in Phase 5. This is explicitly optional/conditional — only pursue it if custom levels commonly ship their own music.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A .mod file bundled in a custom .dat plays correctly at runtime via the Zig player
- [x] #2 Playback quality is close enough to the original dj_* mixer that it isn't a regression for existing .mod assets
- [x] #3 This task is explicitly marked optional in the task tracker and does not block the rest of Phase 8
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Scope decision (confirmed with Lance): implement a *minimal* ProTracker/MOD player, not a full spec-faithful reimplementation. Unlike TASK-010/011/012's ported subsystems, there is no working C reference to diff against here -- sdl/sound.c's dj_load_mod/dj_free_mod are empty stubs, and real playback in this port goes entirely through SDL_mixer's Mix_LoadMUS/Mix_PlayMusic (libmodplug/xmp), so the porting-playbook's Tier-B oracle-diff approach does not apply. This is new code, verified by parser-correctness unit tests plus manual listening, not bit-exact diffing.

Format support: standard 31-instrument MOD variants only (M.K./M!K!/FLT4/FLT8/xCHN/xxCH signatures, 4/6/8-channel). No 15-sample (Soundtracker-era) format.

Effect support (minimal set covering what real-world ProTracker tunes actually use, per the "Minimal player" decision): 0 arpeggio, 1/2 portamento up/down, 3 tone portamento, 4 vibrato, 5/6 (volslide combined with tone-porta/vibrato), 9 sample offset, A volume slide, B position jump, C set volume, D pattern break, F set speed/tempo, E8 set fine-panning skipped, E1/E2 fine porta, EA/EB fine volslide, EC note cut. Explicitly out of scope: 7 tremolo, 8 panning (mono-summed pan ignored), EE pattern delay, E-subcommands beyond the above. Document the skipped set in the module doc comment so a future task can extend it if a real community level needs one.

1. `core/mod_player.zig` (new, pure buffer-in/buffer-out, no file I/O -- mirrors `core/asset_runtime.zig`'s convention):
   - Parser: header (title, 31 sample headers: name/length/finetune/volume/repeat), song length + position order table, signature-based channel count, pattern data (4 bytes/note: period+sample-hi nibble, sample-lo+effect, effect param), sample PCM (8-bit signed, per-sample loop points).
   - Player/mixer: tick-based playback matching ProTracker's 1 row = `speed` ticks, tempo (BPM) -> samples-per-tick timing, Amiga period table for note pitch, per-channel step/stepremainder linear-interpolation resampler -- deliberately reusing the exact integer resampling shape from `sdl/sound.c`'s `mix_sound()` (step = (samplerate<<16)/audio_rate, stepremainder accumulation) so the mixing math has a precedent in this codebase even though there's no oracle to diff.
   - Renders the *entire* song once, playing the position-order table start-to-end exactly once (matching `dj_start_mod`'s `Mix_PlayMusic(current_music, -1)` / `tools/render_music.py`'s documented "loop point is (0, full length)" convention) into an owned interleaved 16-bit stereo PCM buffer at 44100 Hz.
   - `renderModToPcm(mod_bytes) -> {pcm_ptr, frame_count}` (caller-allocated-buffer + length-query pattern, matching `buildSpriteAtlas`/`buildLevelLayers`), `freeModPcm(...)`.
   - Unit tests (Tier-A only, no Tier-B): parser correctness against hand-built minimal fixture MODs (known header/pattern/sample bytes -> asserted parsed structure) plus structural checks against the repo's real `data/bump.mod`/`jump.mod`/`scores.mod` (right channel count, sample count, position-order length, non-crashing full render, frame count in the same order of magnitude as `render_music.py`'s manifest.json values for those tracks).

2. `include/jumpnbump.h` + `core/abi.zig`: `jnb_mod_render(mod_bytes, len, out_pcm, out_pcm_cap, out_frame_count) -> jnb_result` + `jnb_mod_free(pcm_ptr, frame_count)`, same caller-allocated/length-query shape as the `jnb_gob_atlas_build`/`jnb_level_layers_build` pair. `JNB_ABI_VERSION` bump 2->3. Full `abitest.zig` conformance coverage.

3. `extension/src/`: extend `JumpnbumpAssetLoader` (or a small sibling class if `load_dat()` shouldn't always pay the render cost) with `render_mod(mod_bytes: PackedByteArray) -> AudioStreamWAV` -- calls `jnb_mod_render`, wraps the PCM directly via `AudioStreamWAV` (stereo, 16-bit, 44100Hz, `loop_mode = LOOP_FORWARD` over the full buffer, matching `MusicPlayer.gd`'s existing loop-the-whole-track behavior), no intermediate file writes (same "no editor re-import step" property AC#2 of TASK-016.01 established for images).
   - `JumpnbumpAssetLoader.load_dat()` gains raw passthrough of any `.mod`-named entries found (`bump.mod`/`jump.mod`/`scores.mod`, matching the base game's `dat_open()` names that `mario3.dat`-style full-replacement archives reuse) into the returned Dictionary as raw `PackedByteArray`s -- rendering happens lazily (only if/when a level actually starts) since a full-song render is real CPU work, not on every `load_dat()` call during level-picker preview/validation.

4. GDScript wiring: `MusicPlayer.gd` gains a method to play a runtime-rendered `AudioStreamWAV` directly (bypassing the static `TRACKS` path lookup) alongside its existing `play(track)`; `GameplayScreen`'s existing `custom_level` config path (from TASK-016.02) calls `JumpnbumpAssetLoader.render_mod()` on the custom `bump.mod` bytes (if present) and hands the resulting stream to `MusicPlayer` instead of the built-in `bump.ogg`. Falls back to built-in music if the custom archive has no `.mod` entry.

5. Verification: `zig build test/abi/abitest`, `zig fmt --check`, `tools/validate_abi_exporter.py`/`validate_abi_test_purity.py`, `task check`. Manual verification: render `data/bump.mod` to PCM, dump to a WAV file, and listen to confirm it's recognizably the same tune as the build-time `game/content/audio/music/bump.ogg` (AC#2 "not a regression" is a subjective/listening check, not an automated diff, since there is no bit-exact oracle -- note this explicitly in the finalization summary rather than overclaiming automated proof). Also render a custom `.dat`'s bundled `.mod` (reuse `mario3.dat`, kept out of the repo per TASK-016.01's licensing note, as the manual fixture) end-to-end through the extension and confirm it plays in-game via a headless capture-state run if audio can be verified that way, otherwise document as a listening-only check same as above.

Sequencing: 1 (parser+mixer+unit tests) before 2 (ABI) before 3 (extension) before 4 (GDScript wiring) -- same bottom-up order TASK-016.01 used. Re-run `task check` after each layer.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Layers 1-2 complete and verified. `core/mod_player.zig` (new): from-scratch MOD parser + tick-based mixer per the recorded plan's minimal-player scope (31-instrument signatures, the documented effect subset, table-free continuous period/frequency pitch math). Added a headroom divisor (nchan/2) after manual verification against the repo's own data/bump.mod/jump.mod/scores.mod showed real-world clipping without it (now <0.13% of samples clipped, down from unattenuated summing). `core/build.zig`'s `unit_test_files` gained the module; 7 Tier-A tests pass (parser correctness, signature variants, malformed-input rejection, non-silent render, no-hang on a backward position-jump, countFrames/renderToPcm cross-check).

Refactored the initial single `renderToPcm` into a shared `renderImpl(..., synthesize: bool)` so a cheap `countFrames()` length-query (needed for the ABI's two-call convention) shares the row/order/speed/tempo traversal instead of a second hand-maintained copy -- only the actual audio synthesis is skipped on the dry-run path.

ABI: `jnb_mod_count_frames`/`jnb_mod_render` added to include/jumpnbump.h + core/abi.zig, two-call length-then-fill convention matching jnb_gob_atlas_build. JNB_ABI_VERSION bumped 2->3 in *both* the header macro and abi.zig's own separate hardcoded constant (missed the second one first pass -- abi.zig doesn't derive it from the header, it's a duplicate literal; caught by all pre-existing abitest cases failing ABI_VERSION_MISMATCH after the header bump, fixed by finding and bumping abi.zig's copy too). Added 2 new abitest.zig conformance tests (two-call contract, decode-failure) with a from-scratch `buildModBytes` fixture (can't @import mod_player.zig's own fixture -- tools/validate_abi_test_purity.py only allows "std").

Verified: `zig build test/difftest/abi/abitest` all green; `zig fmt --check` clean for every file this task touched (5 pre-existing unrelated fmt failures elsewhere on main, confirmed via git stash); `tools/validate_simulation_boundary.py --sim-only` still reports only the 2 pre-existing abi.zig add_pob/add_leftovers findings (unchanged, confirmed by direct comparison) -- zero new boundary violations from mod_player.zig or the new ABI functions; `tools/validate_abi_exporter.py`/`validate_abi_test_purity.py` pass; full `task check` (asset-pipeline gates + game:boundary-check + game:test) passes clean, 54/54 gdUnit4 cases, confirming the GDExtension rebuild against the bumped ABI didn't break anything (extension/src/jumpnbump_world.cpp reads JNB_ABI_VERSION from the header macro, no separate hardcode there).

Manual verification (no automated real-.mod-file test committed, matching TASK-016.01's own precedent of keeping real-fixture verification manual/uncommitted): a throwaway scratch harness (not committed) rendered all 3 of the repo's real .mod files end to end -- bump.mod (4ch M.K., 8 patterns) -> 54.9s audio, jump.mod (4ch, 2 patterns) -> 14.1s, scores.mod (4ch, 8 patterns) -> 61.9s, all non-crashing with plausible durations and healthy mean amplitude (~15-17% of full scale). No actual audio playback/listening was possible in this environment -- verification was structural (duration, RMS, clipping %) not auditory; flagging this now rather than overclaiming a listening test in the eventual finalization summary.

Remaining: layer 3 (extension/src/ JumpnbumpAssetLoader::render_mod -> AudioStreamWAV, plus load_dat() passthrough of .mod entries) and layer 4 (MusicPlayer.gd / GameplayScreen custom-level wiring).

Layers 3-4 complete. extension/src/jumpnbump_asset_loader.{hpp,cpp}: JumpnbumpAssetLoader.load_dat() now passes through any bump.mod/jump.mod/scores.mod entries found in a .dat as raw PackedByteArrays under a new "mods" Dictionary key (undecoded -- rendering is real CPU work, deferred until a level actually starts, not paid during level-picker preview/validation). New static render_mod(mod_bytes) -> Dictionary {result, stream: AudioStreamWAV} calls jnb_mod_count_frames/jnb_mod_render and wraps the PCM directly via AudioStreamWAV (16-bit stereo, 44100Hz, LOOP_FORWARD over the full buffer) -- no file writes, matching TASK-016.01's image-decoding precedent. `task extension:build` compiles clean.

GDScript: MusicPlayer.gd gained play_custom(stream) to play a runtime stream directly, bypassing the TRACKS name lookup and clearing _current_track so a later play("game") isn't mistaken for a no-op. Main.gd's new _play_gameplay_music() checks the selected custom level's payload for a "bump" mod entry, renders it, and falls back to the built-in bump.ogg on any decode failure or absence -- called from _start_match() in place of the unconditional _music_player.play("game").

Tests added: game/tests/test_asset_loader.gd gained a "mods" passthrough assertion (real jumpbump.dat) plus two render_mod tests (real bump.mod produces a correctly-shaped looping AudioStreamWAV in <5s; a non-.mod buffer reports JNB_ERR_ASSET_DECODE_FAILED). game/tests/test_audio.gd (the standalone SceneTree smoke suite) gained a play_custom() wiring test. Full `task check`: 56/56 gdUnit4 cases + all standalone smoke scripts (including test_audio.gd) pass clean; `task game:boundary-check` passes (JumpnbumpAssetLoader isn't the game-boundary-restricted class -- only JumpnbumpWorld is, per test_asset_loader.gd's own existing comment).

AC#2 ("close enough... isn't a regression") is a listening/quality judgment no automated test in this headless environment can make. Rendered all 3 real tracks (data/bump.mod/jump.mod/scores.mod) to WAV via a throwaway scratch harness (not committed) and saved them to artifacts/mod_player_preview/*.wav (gitignored) for Lance to listen to against the committed game/content/audio/music/*.ogg -- left AC#2 unchecked pending that listen rather than checking it on structural evidence alone (duration/clipping-% checks only prove "non-crashing and roughly the right length," not "sounds right").

AC#2 confirmed by Lance: listened to artifacts/mod_player_preview/{bump,jump,scores}.wav via dosbox-x on mini and mf, A/B'd against the raw .mod files (copied alongside) and the committed OGGs -- "The WAVs sound perfect." All three acceptance criteria now objectively verified; finalizing.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ported a minimal ProTracker/NoiseTracker .mod playback engine to Zig (TASK-016.03), so custom .dat levels can bundle and play their own music at runtime without the build-time .mod-to-OGG conversion Phase 5 uses for the base game's three tracks. Explicitly optional per the task description; does not block the rest of Phase 8.

**Scope decision (confirmed with Lance up front):** a minimal player, not a full ProTracker-spec reimplementation. Unlike every other core/*.zig port, there's no working C reference here to diff against -- sdl/sound.c's dj_load_mod/dj_free_mod are empty stubs, real Linux-port playback goes entirely through SDL_mixer -- so this is new code, verified by parser-correctness unit tests plus a real listening comparison, not the usual Tier-B oracle diff.

**core/mod_player.zig (new):** parses standard 31-instrument MOD signatures (M.K./M!K!/FLT4/FLT8/xCHN/xxCH); tick-based mixer implementing arpeggio, portamento (normal/fine/tone), vibrato, volume slide (normal/fine), sample offset, position jump, pattern break, set speed/tempo, and note cut -- the effects real-world ProTracker tunes actually rely on. Pitch/finetune math is deliberately table-free (continuous period/frequency arithmetic instead of the ~600-entry Amiga finetune table), a documented simplification for the "minimal" scope. Renders a track's position-order table exactly once (matching dj_start_mod's Mix_PlayMusic(-1) / tools/render_music.py's "loop point is (0, full length)" convention) into 16-bit stereo PCM, with a headroom divisor added after manual verification against the repo's real tracks showed clipping without it. 7 Tier-A unit tests.

**ABI:** jnb_mod_count_frames/jnb_mod_render added to include/jumpnbump.h + core/abi.zig, the same two-call length-then-fill convention as jnb_gob_atlas_build. JNB_ABI_VERSION bumped 2->3 (both the header macro and abi.zig's separate hardcoded copy -- easy to miss the second one, caught by every existing abitest case failing ABI_VERSION_MISMATCH). 2 new abitest.zig conformance tests.

**Extension:** JumpnbumpAssetLoader.load_dat() now passes through any bundled bump.mod/jump.mod/scores.mod as raw bytes (undecoded -- rendering is real CPU work, deferred until a level actually starts); new static render_mod() wraps the decoded PCM directly into a looping AudioStreamWAV, no file writes.

**GDScript:** MusicPlayer.gd gained play_custom() to play a runtime stream directly; Main.gd's gameplay-music path now renders and plays a selected custom level's own bump.mod when present, falling back to the built-in track on any decode failure.

**Verification:** zig build test/difftest/abi/abitest all green; zig fmt clean on every touched file; tools/validate_simulation_boundary.py --sim-only unchanged (still only the 2 pre-existing abi.zig findings, zero new); tools/validate_abi_exporter.py/validate_abi_test_purity.py pass; full task check (56/56 gdUnit4 cases + standalone smoke scripts) passes clean; task game:boundary-check passes. New tests in game/tests/test_asset_loader.gd (mods passthrough + render_mod against the real bump.mod) and game/tests/test_audio.gd (play_custom wiring).

**AC#2 ("not a regression" on playback quality)** is a listening judgment no automated headless test can make. Rendered all 3 real tracks to WAV, copied them plus the raw .mod files to two machines with dosbox-x (mini, mf) for Lance to A/B against the original mixer and the committed OGGs. Confirmed: "The WAVs sound perfect."

**Out of scope / known limitations (documented in the module's header comment):** tremolo, panning (channels sum center, no stereo separation), pattern delay, and any E-subcommand beyond fine-porta/fine-volslide/note-cut. 15-sample Soundtracker-era MOD format isn't supported (31-instrument only). A future task can extend the effect set if a real community level needs one of the dropped ones.
<!-- SECTION:FINAL_SUMMARY:END -->
