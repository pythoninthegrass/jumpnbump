# extension/

The GDExtension shim linking `core/`'s Zig ABI into Godot: a SConstruct
build linking the Zig static lib via `env.File(...)` (never a bare
`-l`/`-L` flag, so a core rebuild triggers a relink), `register_types.cpp`
with the standard godot-cpp init/terminate boilerplate, and a
`JumpnbumpWorld : RefCounted` GDCLASS whose methods forward 1:1 to `jnb_*`
calls with no game logic of its own (`TASK-012.04`). Follows the pattern in
`~/git/neo_snake/extension/`. Depends on `third_party/godot-cpp` being
vendored first (`TASK-004`).

Placeholder until `TASK-012.04` builds the shim.
