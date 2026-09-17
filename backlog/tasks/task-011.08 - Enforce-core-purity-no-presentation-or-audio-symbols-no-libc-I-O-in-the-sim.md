---
id: TASK-011.08
title: 'Enforce core purity: no presentation or audio symbols, no libc I/O in the sim'
status: Blocked
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-3
dependencies: []
parent_task_id: TASK-011
priority: medium
type: task
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a build-time or CI check (following neo_snake's tools/validate_audio_boundary.py pattern) that fails if the Zig simulation core references any presentation concept (pob lists, page flipping, draw calls) or audio symbol, or performs libc file I/O outside the explicitly asset-loading paths. The sim core must be a pure, deterministic state machine.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A CI-wired check greps or symbol-scans core/ and fails on any presentation or audio symbol reference from the sim module
- [ ] #2 The check passes on the completed Phase 3 core — **cannot pass as written; see Blocked**
- [x] #3 The check is documented in docs/porting-playbook.md as a standing rule for future changes
<!-- AC:END -->

## Implementation Notes

Added `tools/validate_simulation_boundary.py` (PEP 723 / `uv run --script`, following
`~/git/neo_snake/tools/validate_audio_boundary.py`) plus
`tools/test_validate_simulation_boundary.py`, both wired into
`.pre-commit-config.yaml` as `repo: local` / `language: system` hooks with
`pass_filenames: false` + `always_run: true`, so the check runs on every commit rather
than only when `core/` is staged. Verified wired: `prek run --hook-stage manual
validate-simulation-boundary-selftest` → Passed, and
`validate-simulation-boundary` runs and exits 1 on the violations below.

**Denylist design (AC#1).** Three rules over `core/**.{zig,c,h}`, comment-stripped, with a
name reported only in a call, declaration or `@export` position:

- *audio* — main.c's `dj_*` layer and the SDL_mixer functions under it (`dj_play_sfx`,
  `dj_set_sfx_channel_volume`, `dj_start_mod`, `dj_mix`, `Mix_OpenAudio`, `Mix_PlayMusic`,
  …) and `sdl/sound.c`'s `addsfx`/`mix_sound`.
- *presentation* — `sdl/gfx.c`'s entry points and the `main_info` page-flip bookkeeping they
  read (`add_pob`/`add_pobs`, `add_leftovers`, `draw_pobs`, `draw_begin`/`draw_end`,
  `flippage`, `page_info`, `draw_page`/`view_page`, `register_background`, `register_mask`,
  `recalculate_gob`, `put_text`, `pob_width`, `setpalette`, …). `register_gob` is deliberately
  absent: `core/gob.zig` is the asset-codec port of it.
- *file I/O* — libc stdio, the Zig Filesystem API (`std.fs`, `std.Io.Dir`, `readFileAlloc`),
  and the C headers that declare them; allowed only in `dat.zig`, `levelmap.zig` and the
  `*_cli.zig` asset packagers.

No bare `sfx`/`audio`/`sound`/`music` token is banned, so the TASK-011.07 event stream
(`sfxAt`, `sfxRecordZ`, `sfxCountZ`, `sfxReset`, `sfx_trace_z`, `EventKind.sfx`) stays clean.
The self-check pins both directions — 19 denylist cases must be caught and the event-stream
fixture must not be — because getting this right took several attempts: a `\w` boundary made
`add_pobs`/`draw_pobs` unmatchable, `re.escape`d dotted names corrupt when joined into one
alternation, and Zig's `std.fs.cwd()` never has `(` after the name. `zig build test` /
`zig fmt` do not cover any of that, which is why the fixture suite is a checked-in gate too.
`core/c_ref/` (the extracted C oracle) and `.zig-cache`/`zig-out` are excluded; `--sim-only`
narrows to the simulation modules and skips `*_difftest.zig` / `unit_*.zig`.

## Blocked

**AC#2 cannot be satisfied by this task alone.** The check finds real audio and presentation
calls in two already-merged simulation modules, and they are load-bearing, not leftovers.
Measured on the unmodified base commit `c48882d` (so this is pre-existing, not introduced
here) — 28 findings over all of `core/`, 14 of them in sim modules:

- `core/objects.zig:99,100` declare `extern fn add_pob`/`add_leftovers`; called at 226, 240,
  256, 284, 301, 431, 432, 456, 459 — the C's draw call sites.
- `core/flies.zig:100` declares `extern fn dj_set_sfx_channel_volume`; called at 187 (the fly
  swarm volume), with a weak capture stub at 318.

These are calls, not comments, so they are genuine violations of the rule AC#2 asserts is
already met. Two facts make them a design question rather than a deletion:

1. **They carry verification coverage.** `objects_difftest.zig:215` `compareDraws()` fails a
   tick on any differing captured `(kind,x,y,image)`, and that is the *only* thing that makes
   the `TASK-011.04` octant/atan2 replacement observable; `steer_difftest.zig:152` /
   `collision_difftest.zig:105`'s `dj_play_sfx` sinks are what `compareSfx()` compares. The
   `TASK-011.07` event stream classifies sfx and object spawns but emits no draw events, so
   dropping the `add_pob` calls would silently lose the fur-rotation check.
2. **Deleting them does not obviously lose parity** — `game_loop.zig:10-13` already argues the
   pob/page bookkeeping is never checksummed and never feeds back — but settling that needs
   the corpus rerun, and the draw-stream comparison argues the other way for the fur frame.

Resolving it means editing `core/objects.zig`, `core/flies.zig` and their difftests, which
this task's brief explicitly puts out of scope ("do not touch any file under `core/`"; a real
violation in merged core is a report, not a side-effect patch). `--sim-only` and the default
scan therefore both exit 1 today, and the pre-commit hook blocks commits until then.

Suggested follow-up (one decision, then mechanical): decide whether the port needs a
`draw`/`sprite_frame` event class in the `TASK-011.07` stream. If yes, emit draw events from
`update_objects()` and replace the `add_pob` externs with event pushes, and route the fly
volume the same way — after which AC#2 and this gate go green together. If no, the draw-stream
comparison in `objects_difftest.zig` needs an explicit rationale for what coverage is given up.

Honest state of the gates: `zig build test` passes (161/162 tests, 1 pre-existing
`game_loop_difftest` failure — `data/jumpbump.dat` is git-ignored and not built in this
worktree, so `dat.loadDatafile` gets `FileNotFound`). The new check is wired and running; it
is red because the thing it checks for is actually there.
