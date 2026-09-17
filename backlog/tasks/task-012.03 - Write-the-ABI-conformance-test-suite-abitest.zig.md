---
id: TASK-012.03
title: Write the ABI conformance test suite (abitest.zig)
status: Done
assignee: []
created_date: '2026-09-15 19:15'
updated_date: '2026-09-17 17:28'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-012
priority: medium
type: task
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write core/abitest.zig, a test suite that reaches the built static library only through @cImport("jumpnbump.h") — never by directly calling internal Zig functions — to verify the C ABI surface behaves correctly end-to-end: world init/reset, input queueing, step/pump, serialization round-trips, event draining, and checksums.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 zig build abitest passes and exercises every function in include/jumpnbump.h
- [x] #2 A purity check (following neo_snake's tools/validate_abi_test_purity.py pattern) confirms abitest.zig never imports core Zig modules directly, only the C header
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Wrote core/abitest.zig: 12 tests reaching core/abi.zig exclusively through @cImport(jumpnbump.h) — ABI-version handshake, every jnb_result value reachable, two-call length-then-fill contract on jnb_objects_copy/jnb_world_dump/jnb_event_drain, @sizeOf checks on every ABI struct, jnb_step/jnb_pump determinism (identical seed+level+inputs from a fresh world reproduce identical dumps/checksums, and jnb_pump's accumulator agrees tick-for-tick with repeated jnb_step), and jnb_world_reset semantics. Added tools/validate_abi_test_purity.py (fails if abitest.zig @imports anything besides "std") and wired core/build.zig's abitest step with link_libc + addIncludePath("../include") so @cImport resolves.

Found and fixed a real bug in core/abi.zig's jnb_world_dump (TASK-012.02, in scope here since it blocked every abitest run): it built the dump via a plain `ArrayList(u8) = .empty` grown by appendSlice over a FixedBufferAllocator sized to the caller's out_capacity, which (a) could OutOfMemory even when out_capacity == jnb_world_dump_len() exactly, because ArrayList's doubling-growth strategy requests more capacity than the buffer holds at some intermediate append even though the final total fits, and (b) then did `@memcpy(buf[0..out.items.len], out.items)` where out.items already aliased buf itself, panicking "@memcpy arguments alias" whenever out_capacity > dump_len. Fixed by pre-allocating the ArrayList's capacity to exactly world.dump_len via initCapacity (so appendSlice's growth check never fires) and writing directly into the caller's buffer via a FixedBufferAllocator sized to world.dump_len (not out_capacity), removing the now-redundant self-aliasing memcpy entirely.

Documented a known ABI gap in abitest.zig's own header comment rather than hiding it: jnb_world_init does not replicate main.c's full headless-init sequence (position_player to enable/place each player, seedLevelObjects for springs/butterflies, spawn_flies) — there is no ABI entry point for any of that yet, so every test's world has every player permanently disabled and steer_players() (which skips disabled players) never moves them. The suite tests real, honest behavior (determinism, buffer contracts, result codes) rather than fabricating gameplay the ABI can't currently produce. A future task adding a player-enable/level-object-seeding ABI entry point should extend this suite with real movement/event assertions.

Verified: `zig build abitest` 12/12 pass, `zig build abi`/`test`/`difftest` still pass, `nm -g --defined-only` on libjumpnbump.a still shows only jnb_* symbols, header-check still zero warnings, both validator scripts exit 0.

Commit: feat(abi): write the ABI conformance test suite (TASK-012.03)
<!-- SECTION:FINAL_SUMMARY:END -->
