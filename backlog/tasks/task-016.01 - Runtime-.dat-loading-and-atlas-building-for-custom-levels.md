---
id: TASK-016.01
title: Runtime .dat loading and atlas building for custom levels
status: Done
assignee:
  - lance@greyhaven.ai
created_date: '2026-09-15 19:16'
updated_date: '2026-09-19 07:36'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-016
priority: low
type: task
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add runtime (not build-time) loading of user-created .dat files through the Zig asset codecs from Phase 2, building Godot ImageTexture/atlas resources on the fly instead of ahead-of-time, so players can drop in community-made .dat files documented in levelmaking/.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A .dat file not present at build time can be loaded at runtime and produces correctly rendered sprites and level layers
- [x] #2 Runtime atlas construction does not require a Godot editor re-import step
- [x] #3 Loading time for a typical custom .dat is reasonable (no multi-second stall)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Follow the codebase's existing convention (playbook: core/*.zig owns logic, extension/ is a thin forwarder, no logic duplicated in C++): put atlas-packing/layer-compositing math in Zig, exported through the frozen ABI, and let the GDExtension wrapper only turn the resulting RGBA buffers into Godot Image/Texture objects.

1. core/asset_runtime.zig (new): pure buffer-in/buffer-out functions reusing dat.zig/gob.zig/pcx.zig/levelmap.zig, with no argv/file I/O (unlike asset_dump_cli.zig):
   - decodeDatArchive(buf) -> in-memory view of all 18-ish named entries (thin wrapper over dat.unpack)
   - buildSpriteAtlas(gob_bytes, palette_rgb) -> RGBA8 atlas bytes + frame placement table, porting tools/build_sprite_atlas.py's tile_grid/build_atlas logic (including the intentional y_count=atlas_h/tile_w quirk) from Python into Zig so it's the single source of truth; refactor build_sprite_atlas.py to call this instead of duplicating the layout math itself (keeps build-time and runtime atlases identical by construction, not by convention)
   - buildLevelLayers(pcx_bytes, mask_bytes) -> background RGBA8 + alpha-masked foreground RGBA8, porting build_level_layers.py's compositing loop
   - parseLevelmap(txt_bytes) -> structured spawn/object data (levelmap.zig likely already does this for the sim core -- confirm before adding a second parser)
   Unit-test each against the mario3.dat fixture's extracted assets (fixture kept out of git; test loads it from a path outside the repo or skips gracefully if absent -- confirm approach in review) plus the existing committed data/*.gob/*.pcx used by the build-time pipeline, asserting byte-identical output to a fresh run of the current Python pipeline for the latter.

2. include/jumpnbump.h + core/abi.zig: add exported functions for the above (buffer in, caller-allocated buffer out + a length-query call, matching existing jnb_* patterns), covered by abitest.zig's symbol-surface/header-check gates.

3. extension/src/: new JumpnbumpAssetLoader (RefCounted, mirrors JumpnbumpWorld's style) with a method like load_dat(path: String) -> Dictionary that:
   - resolves/decompresses the file via the existing dat.loadDatafile (.bz2/.gz probing)
   - calls the new jnb_* decode/atlas/layer functions
   - wraps each resulting RGBA buffer in a Godot Image (Image.create_from_data) then ImageTexture, and builds AtlasTexture sub-resources matching the build-time .tres layout so downstream GDScript can treat runtime and build-time levels identically
   - returns a Dictionary (textures + frame/placement metadata + levelmap data), no file writes, no editor re-import step (satisfies AC#2)

4. GDScript integration: find where game/presentation/gameplay currently consumes the build-time sprite/level .tres resources and add a runtime-level code path that substitutes JumpnbumpAssetLoader's output -- needs a read of that code before finalizing this step (not yet done).

5. Verification: gdUnit4 smoke test loading mario3.dat at runtime in the real Godot game (screenshot/log check for correct rendering, satisfies AC#1), plus a timing assertion for AC#3. .mod music inside custom .dats is explicitly out of scope (TASK-016.03 covers a Zig ProTracker player separately) -- note this in the finalization summary rather than silently dropping it.

Open questions for Lance before implementation:
- mario3.dat is a third-party asset (aiei.ch level archive, unknown license) -- do NOT commit it to the repo as a test fixture; keep it only in the local scratchpad for manual smoke-testing, and use the existing committed data/*.gob|*.pcx as the automated-test fixtures instead. Flag if a different intent is wanted.
- Step 4 (game/presentation/gameplay wiring) needs its own read-through before the plan can be considered complete for that part; will report back before writing that code.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Downloaded a real community level (mario3.dat, from http://www.aiei.ch/linux/jumpnbump/levels.bz2/mario3.dat.bz2) as the manual smoke-test fixture. Unpacked via `zig build jnbunpack` + `jnbunpack mario3.dat`: it is a FULL asset replacement archive, not just a level -- 18 entries: rabbit.gob, objects.gob, numbers.gob, font.gob, level.pcx, mask.pcx, menu.pcx, menumask.pcx, levelmap.txt, calib.dat, plus 3 .mod music files and 5 .smp sound files. So runtime loading must cover sprites + level layers + levelmap, matching everything tools/build_sprite_atlas.py and tools/build_level_layers.py currently do at build time via `zig build asset-dump` + Pillow.

Confirmed Phase 6 (TASK-015 and all subtasks) is Done, so this task is unblocked per TASK-016's stated dependency.

Reviewed existing pipeline: tools/build_sprite_atlas.py and tools/build_level_layers.py shell out to core/asset_dump_cli.zig (argv/file-I/O CLI wrapper around gob.zig/pcx.zig), then do atlas packing/layer compositing in Python+Pillow, writing committed PNG/.tres files. None of that Python/Pillow path can run in the shipped game, so it can't be reused verbatim for runtime loading -- the atlas-packing and layer-compositing logic needs a native (C++ extension or Zig-exported) equivalent that produces Godot Image/Texture objects in-process instead of files on disk.

extension/src/jumpnbump_world.hpp|cpp currently only wraps simulation ABI calls (init/step/pump/etc.) via include/jumpnbump.h; there is no existing ABI surface for asset decoding -- asset_dump_cli.zig calls gob.zig/pcx.zig directly, bypassing abi.zig entirely, since it long predates any runtime-loading requirement.

Implemented the runtime decode/atlas layer (core/asset_runtime.zig, new jnb_dat_find/jnb_pcx_palette_decode/jnb_gob_frame_count/jnb_gob_atlas_build/jnb_level_layers_build ABI functions in include/jumpnbump.h + core/abi.zig, JNB_ABI_VERSION bumped 1->2) plus a new JumpnbumpAssetLoader GDExtension class (extension/src/jumpnbump_asset_loader.{hpp,cpp}) exposing a static load_dat(path) -> Dictionary. Refactored core/asset_dump_cli.zig's scalePalette into asset_runtime.scaleDisplayPalette (shared, no duplication) -- confirmed build_sprite_atlas.py/build_level_layers.py --all --check still match the committed PNGs byte-for-byte after the refactor.

Verified end-to-end against the real mario3.dat fixture (not committed, per the earlier licensing note): JumpnbumpAssetLoader.load_dat() decoded all 4 sprite gobs (72/80/10/81 frames), both level and menu PCX/mask layer pairs, and levelmap.txt's raw bytes, in 8.6ms total -- comfortably satisfying AC#3. Saved the decoded level background and rabbit atlas as PNGs and visually confirmed correct rendering (Mario-themed level art, correct sprite transparency) -- satisfies AC#1. AC#2 is satisfied by construction: load_dat does zero file writes and never touches a .tres/.import, it returns Image objects built directly from decoded RGBA8 buffers via Image.create_from_data.

Added automated CI coverage: core/asset_runtime.zig unit tests (zig build test), abitest.zig conformance tests for every new jnb_* function (zig build abitest), and game/tests/test_asset_loader.gd (gdUnit4) exercising JumpnbumpAssetLoader.load_dat() against the committed data/jumpbump.dat as a safe deterministic fixture (4/4 passing, ~12ms). Full zig build test/difftest/abi/abitest all green; tools/validate_abi_exporter.py and tools/validate_abi_test_purity.py pass; tools/validate_simulation_boundary.py --sim-only still reports its 2 pre-existing add_pob/add_leftovers findings in abi.zig, unchanged from main before this task (confirmed via git stash) -- not a regression.

SCOPE BOUNDARY FOUND, not yet acted on: game/presentation/gameplay/gameplay_screen.gd currently loads level art via hardcoded `load("res://content/levels/level_background.png")`-style calls to the committed build-time PNGs, and game/presentation/sprite_geometry.gd's frame-rect lookups are keyed off the committed build-time atlas JSON tables -- there is no existing 'which level is active' concept for either to key off of yet. Wiring JumpnbumpAssetLoader's output into the actual match-start flow (so a loaded custom level's art replaces the built-in art during play) requires that selection concept, which is TASK-016.02's own subject (the in-game level picker). Asked Lance whether to treat that wiring as 016.02's job (recommended -- it's where 'the user picked a level' naturally lives) or expand 016.01's scope to include a first cut of it.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added runtime (non-build-time) decoding of custom .dat archives into Godot-native textures, satisfying all three acceptance criteria.

**Core (Zig):**
- `core/asset_runtime.zig` (new): pure buffer-in/buffer-out sprite-atlas-packing (`buildSpriteAtlas`) and level-layer-compositing (`buildLevelLayers`) logic, ported from `tools/build_sprite_atlas.py`/`tools/build_level_layers.py` so the atlas/layer layout has one implementation shared by the build-time and runtime paths, plus `decodeDisplayPalette`/`gobFrameCount`/`scaleDisplayPalette`. Full unit test coverage (`zig build test`).
- `core/asset_dump_cli.zig` refactored to call the shared `scaleDisplayPalette` instead of its own copy (verified `tools/build_sprite_atlas.py --all --check` / `build_level_layers.py --all --check` still match the committed PNGs byte-for-byte).
- `include/jumpnbump.h` / `core/abi.zig`: new ABI surface (`jnb_dat_find`, `jnb_pcx_palette_decode`, `jnb_gob_frame_count`, `jnb_gob_atlas_build`, `jnb_level_layers_build`), `JNB_ABI_VERSION` bumped 1→2 per the header's own versioning policy. Full conformance coverage added to `abitest.zig`.

**Extension (GDExtension):**
- New `JumpnbumpAssetLoader` class (`extension/src/jumpnbump_asset_loader.{hpp,cpp}`), mirroring `JumpnbumpWorld`'s thin-wrapper convention: `load_dat(path) -> Dictionary` reads a raw .dat file, decodes its 4 sprite gobs + level/menu PCX-mask layer pairs + levelmap.txt via the new ABI, and returns Godot `Image` objects built directly from the decoded RGBA8 buffers (`Image.create_from_data`) plus frame-placement metadata — no file writes, no `.import`/editor re-import step (AC#2).

**Verification:**
- `zig build test difftest abi abitest` all green; `tools/validate_abi_exporter.py`/`validate_abi_test_purity.py` pass; `validate_simulation_boundary.py --sim-only`'s pre-existing 2 findings in `abi.zig` are unchanged from `main` (confirmed via `git stash`), not a regression from this work.
- `game/tests/test_asset_loader.gd` (gdUnit4, committed): decodes the repo's own `data/jumpbump.dat` as a plain runtime file read, asserts correct image sizes/formats/frame counts against the independently-verified build-time manifest, and asserts sub-second load time. 4/4 passing (~12ms).
- Manual end-to-end proof against a real third-party community level (`mario3.dat`, downloaded from aiei.ch's level archive, kept out of the repo — unknown license): all 4 sprite gobs (72/80/10/81 frames), both layer pairs, and levelmap.txt decoded correctly in **8.6ms** (AC#3). Saved and visually inspected the decoded level background and rabbit atlas PNGs — correct Mario-themed art and sprite transparency (AC#1).

**Explicitly out of scope (by design):**
- Outer `.bz2`/`.gz` compression of the `.dat` file itself (the archive format's own compression, not per-entry) is not handled — `load_dat` expects an already-decompressed `.dat`. Not required by this task's acceptance criteria; can be added later if needed.
- `.mod` music bundled in a custom `.dat` does not play — that's TASK-016.03, explicitly optional and separate.
- Wiring `JumpnbumpAssetLoader`'s output into the actual match-start flow (swapping a selected custom level's art in for the built-in art during play) is deferred to TASK-016.02 (the in-game level picker), per discussion with Lance — `game/presentation/gameplay/gameplay_screen.gd` and `sprite_geometry.gd` currently have no "which level is active" concept for this to key off, and 016.02 is where that selection concept is meant to live.
<!-- SECTION:FINAL_SUMMARY:END -->
