---
id: TASK-008.01
title: Headless deterministic mode for the C build
status: Done
assignee:
  - pythoninthegrass
created_date: '2026-09-15 19:14'
updated_date: '2026-09-16 14:17'
labels: []
milestone: m-1
dependencies: []
modified_files:
  - globals.pre
  - main.c
  - sdl/interrpt.c
  - sdl/sound.c
  - tests/fixtures/headless-smoke.jsonl
  - tests/fixtures/README.md
parent_task_id: TASK-008
priority: high
type: task
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a headless mode to the existing SDL C build: fixed 60Hz tick with no wall-clock dependency, scripted input read from a file instead of live keyboard/joystick, no audio/video output required, and a seeded rnd() so runs are exactly reproducible. This becomes the foundation the rest of Phase 1 builds on.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A CLI flag runs the C build headlessly with no window/audio device required
- [x] #2 Given the same seed and the same scripted input file, two runs produce byte-identical state
- [x] #3 The fixed 60Hz tick does not drift relative to wall-clock time in headless mode
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Approach

Model on the existing `is_net`/`main_info` conventions in `main.c` (chain of `stricmp(argv[c1], "-flag")` in `init_program()`, flags stored on `main_info_t`). No new abstraction layers; headless mode is a handful of `if (main_info.headless)` gates in existing functions.

### 1. CLI flags (`main.c` init_program(), ~line 3011-3069; usage text ~3082-3089)
- `-headless` : sets `main_info.headless = 1`
- `-seed <n>` : sets `main_info.headless_seed` (unsigned int, parsed with atoi/strtoul)
- `-input <path>` : sets `main_info.headless_input_path` (char*), the JSONL scripted-input file
- Add `int headless; unsigned int headless_seed; char *headless_input_path;` to `main_info_t` (globals.h:174-199).

### 2. Deterministic RNG seed
- `main.c:3000` currently `srand(time(NULL));` inside `init_program()`.
- Change to: `srand(main_info.headless ? main_info.headless_seed : (unsigned)time(NULL));`
- No change to `rnd()` itself (main.c:3410) — seeding `srand()` once is sufficient since all gameplay randomness funnels through it (confirmed: no other PRNG state).

### 3. Skip video/audio/joystick init in headless mode
- `sdl/gfx.c:173,182` (`open_screen()`): guard `SDL_Init(...)` and `SDL_SetVideoMode(...)` behind `if (!main_info.headless)`; still need `SDL_Init(SDL_INIT_TIMER)` alone in headless mode? No — headless tick will not use `SDL_GetTicks`/`SDL_Delay` at all (see #4), so no SDL subsystem is required in headless mode. `open_screen()` becomes a no-op when headless.
- `sdl/sound.c:258-269` (`dj_init()`): already checks `main_info.no_sound` before `Mix_OpenAudio`; add `main_info.headless` to that same short-circuit (headless implies no_sound-equivalent behavior for audio open), and skip the unconditional `open_screen()` call at sdl/sound.c:258 when headless.
- `game_loop()` rendering block (`main.c:1328-1393`: `draw_pobs`, `flippage`, `draw_leftovers`, `redraw_pob_backgrounds`) and audio mix calls (`main.c:1291,1295,1305,1311` `dj_mix()`): wrap in `if (!main_info.headless)`, following the existing `if (is_net) { ... }` conditional style already in this function.

### 4. Fixed 60Hz tick with no wall-clock dependency
- `intr_sysupdate()` (`sdl/interrpt.c:303-462`) currently paces via `SDL_GetTicks()`/`SDL_Delay()` diffs against real time.
- Add a headless branch at the top of `intr_sysupdate()`: no `SDL_PollEvent`, no `SDL_GetTicks`, no `SDL_Delay`; load the next scripted-input record (see #5) into `keyb[]`; always `return 1` (exactly one 60Hz tick per call, satisfies AC#3 by construction — there is no wall clock to drift from).

### 5. Scripted input file (JSONL, decided format)
- One JSON object per line: `{"frame": N, "keys": ["p1_left", "p1_jump", ...]}` listing which of the 12 player key slots (p1..p4 × left/right/jump, mapping to `KEY_PL1_LEFT`..`KEY_PL4_JUMP` in globals.h:95-113) are held that frame. Omitted keys are up.
- Headless tick reads the record for the current frame index, resets the 12 relevant `keyb[]` slots, sets the listed ones via the existing `addkey()`-equivalent (`keyb[key & 0x7fff] = 1/0`) — then falls through to the unchanged `update_player_actions()`/`steer_players()` path, so jump-edge detection and joystick-OR logic are exercised exactly as in normal play.
- Missing frame record (file exhausted) => treat as all-keys-up (or stop the run — decide during implementation based on what's easiest to keep deterministic; leaning toward all-keys-up so trace length doesn't have to match run length exactly).
- Minimal JSON parsing: hand-roll a tiny line-oriented parser (no new dependency) since the format is fixed and flat — consistent with the "no libc file I/O outside asset-loading paths" spirit for `core/`, though this code lives in the legacy `sdl/`/`main.c` tree so that rule doesn't strictly apply here.

### 6. Verification (maps to AC#1-3)
- AC#1: `./jumpnbump -headless -seed 1 -input trace.jsonl` runs to completion (or a frame-count limit) with no SDL window/audio device opened — verify via `SDL_WasInit()` returning 0 for VIDEO/AUDIO, or simply that it runs in a headless CI container with no X server / no ALSA device.
- AC#2: add a canonical-state dump (minimal for this subtask — e.g. dump `player[]` positions to stdout or a file at end of run) sufficient to diff two runs; full checksum-per-frame dumping is TASK-008.02's job, but 008.01 needs *some* way to prove byte-identical output for its own acceptance criterion. Run twice with the same seed+trace, diff the two dumps.
- AC#3: with no wall-clock read in the headless path, tick count is purely a function of frames processed — verify by running a fixed-length trace and confirming exact same number of ticks/frames every time regardless of host machine speed (e.g. artificially slow the host with `nice`/cpu load and confirm identical frame count/output).

### Files touched
- `main.c` (CLI parsing, srand, game_loop rendering/audio gates, headless input load point)
- `globals.h` (`main_info_t` new fields, maybe small headless-input struct/prototypes)
- `sdl/gfx.c` (`open_screen()` gate)
- `sdl/sound.c` (`dj_init()` gate)
- `sdl/interrpt.c` (`intr_sysupdate()` headless branch, scripted-input loader)
- New: minimal JSONL reader (small static function, likely in `sdl/interrpt.c` or a new tiny `sdl/headless.c` if it gets big enough — decide during implementation, default to keeping it in `interrpt.c` unless it exceeds ~80 lines)

### Test plan
- Manual: build with `make`, run `-headless -seed 1 -input <sample trace>` twice, diff dumps.
- No automated test harness exists yet for the C build (that's TASK-008.04); this subtask's own verification is manual/CLI-based per AC text.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Discovered globals.h is generated from globals.pre (make regenerates it); edited globals.pre for the main_info_t additions, not globals.h directly.

Discovered and fixed a pre-existing bug while adding -headless: the -v/-h argv parsing checked argv[1] (fixed) instead of argv[c1] (current arg), and used loose strstr substring matching instead of exact comparison. This caused false positives once a flag/value containing '-h' appeared as the first argument (e.g. -headless itself, or a -input path containing '-h' like a scratch dir name) — fixed both checks to stricmp(argv[c1], ...) == 0, matching every other flag in the chain.

menu()'s interactive walk-in sequence is what normally sets player[c1].enabled=1; headless mode skips menu() entirely (no video), so it enables player 0 directly right before game_loop(). Only single-player headless runs are supported by this subtask — multi-player headless setup is left for whoever needs it (008.03 corpus or later) since it wasn't required by the ACs.

The post-game 'scores' screen (put_text/flippage loop waiting for ESC) is UI-only and unconditionally ran after game_loop() returned; gated it out entirely in headless mode and return immediately after printing a minimal player-state dump (enabled/x/y/x_add/y_add/anim/frame/image/bumps) to stdout — sufficient to prove AC#2 by diffing two runs.

Verified AC#1: runs with DISPLAY/SDL_VIDEODRIVER/SDL_AUDIODRIVER all unset, exit 0, no window. Verified AC#2: two runs with same seed+trace produce byte-identical stdout (diff clean). Verified AC#3: intr_sysupdate()'s headless branch never calls SDL_GetTicks/SDL_Delay, so tick pacing is purely input-driven — confirmed output is identical when the run is artificially CPU-starved (nice -19 + two `yes` processes) vs an unloaded run.

Added tests/fixtures/headless-smoke.jsonl + README as a smoke-test fixture (distinct from tests/corpus/, which is TASK-008.03's real checksummed corpus).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a `-headless` mode to the C build, satisfying all three ACs.

**CLI**: `-headless` (no video/audio/joystick, forces `main_info.no_sound`/`joy_enabled=0`), `-seed <n>` (seeds `srand()` deterministically instead of `time(NULL)`), `-input <path>` (JSONL scripted input, one line per frame: `{"frame":N,"keys":["p1_left",...]}` for the 12 player key slots).

**Video/audio/joystick skip**: `open_screen()`'s `SDL_Init`/`SDL_SetVideoMode` and `Mix_OpenAudio` never run in headless mode; the interactive menu, the joystick-calibration screen, and the post-game "scores" screen (all UI-only, all touch `jnb_surface`) are skipped entirely. `menu()`'s walk-in sequence is what normally flips `player[c1].enabled` on, so headless mode sets `player[0].enabled = 1` directly before `game_loop()` — single-player only for now.

**Deterministic 60Hz tick**: `intr_sysupdate()` gets a headless branch that never touches `SDL_GetTicks`/`SDL_Delay`/`SDL_PollEvent` — it just loads the next trace line into `keyb[]` and returns 1 tick, so pacing has no wall-clock dependency at all (confirmed byte-identical output under artificial CPU load).

**Side fix**: found and fixed a pre-existing argv-parsing bug in `init_program()` — the `-h`/`-v` checks used `strstr(argv[1], ...)` (always the *first* arg, substring match) instead of `stricmp(argv[c1], ...) == 0` like every other flag. This silently broke as soon as any flag or value containing `-h` was the first argument (`-headless` itself, or an `-input` path containing `-h`), so it had to be fixed to make the new flag usable at all.

**Verification** (manual, since no test harness exists yet — that's TASK-008.04):
- AC#1: ran with `DISPLAY`/`SDL_VIDEODRIVER`/`SDL_AUDIODRIVER` all unset, exit 0, no window/audio device touched.
- AC#2: two runs with the same seed + `tests/fixtures/headless-smoke.jsonl` produce byte-identical stdout (a minimal player-state dump added for this purpose; full per-frame checksums are TASK-008.02's job).
- AC#3: same run repeated under `nice -19` plus two `yes` CPU-hogs produces identical output — no wall-clock read exists in the headless path to drift.

Full `make clean && make` succeeds with no new warnings/errors.

**Follow-ups left for later tasks** (not gaps in this one, just noted for context): multi-player headless setup (only player 0 auto-enabled), and the real checksummed corpus under `tests/corpus/` (TASK-008.03) plus the differential harness (TASK-008.04).
<!-- SECTION:FINAL_SUMMARY:END -->
