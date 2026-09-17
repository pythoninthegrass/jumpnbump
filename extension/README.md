# extension/

The GDExtension shim linking `core/`'s Zig ABI into Godot: a SConstruct
build linking the Zig static lib via `env.File(...)` (never a bare
`-l`/`-L` flag, so a core rebuild triggers a relink), `register_types.cpp`
with the standard godot-cpp init/terminate boilerplate, and a
`JumpnbumpWorld : RefCounted` GDCLASS whose methods forward 1:1 to `jnb_*`
calls with no game logic of its own (`TASK-012.04`). Follows the pattern in
`~/git/neo_snake/extension/`. Depends on `third_party/godot-cpp` being
vendored first (`TASK-004`).

Build with `scons target=template_debug` (or `target=template_release`)
from this directory; the linked `core/zig-out/lib/libjumpnbump.a` must
already exist (`cd ../core && zig build abi`). Produces
`game/bin/libjumpnbump.<platform>.<target>.<arch>.so`, loaded by
`game/bin/jumpnbump.gdextension` (`TASK-012.05`).

## Vendored dependency: `third_party/godot-cpp` (`TASK-004`)

`third_party/godot-cpp` is a git submodule pinned to the exact commit SHA
`507ed9d840c01a3c5b2a39af8bb4000bfac30bf5` (`git submodule status` prints
that SHA, nothing else). The pin, not the submodule URL, is the contract:
bump it by committing a new gitlink, never by moving a branch.

Why a SHA rather than a tag or a branch name:

- **No tag or branch exists for the 4.7 API line.** godot-cpp switched to
  versioning itself independently of Godot at 10.x: one branch (`master`)
  now serves Godot 4.3–4.7, and the Godot version you build against is an
  SCons *option* (`api_version=4.7`, or
  `SConscript("third_party/godot-cpp/SConstruct", {"api_version": "4.7"})`
  — the form `extension/SConstruct` will use), not a checkout. The newest
  `godot-4.x-stable` tag upstream is `godot-4.5-stable`, whose bindings
  predate 4.7 entirely, so a tag pin would pin the wrong API.
- **`4.7-stable` in the name is the Godot version, not the godot-cpp
  version.** The 4.7 bindings in this checkout come from `5ffd70e`
  ("gdextension: Sync with upstream commit 5b4e0cb… (4.7-stable)");
  `third_party/godot-cpp/gdextension/extension_api-4-7.json` carries
  `version_full_name: "Godot Engine v4.7.stable.official"`, matching the
  `godot 4.7.1-stable` pin in `.tool-versions`. The same checkout also
  carries 4.3–4.6, so the JSON file we build against has to be named by
  option, and the commit has to be named by SHA.
- **A branch pin is a moving target.** `master` (or a hypothetical `4.7`)
  moves upstream; `task check` would then mean "whatever godot-cpp looked
  like today". The differential-test story for this port (frame-by-frame
  against the C oracle, `TASK-008`) needs every input fixed, and a binding
  regeneration that changes a method signature is exactly the kind of
  drift that would otherwise show up as a simulation diff.
- **The 4.7 JSON is a file on disk, not an object the tag points at.**
  Requiring `api_version` and vendoring per-version API dumps landed in
  `9d050a9`, after `godot-4.5-stable` was cut. A SHA pin makes "this
  checkout contains the 4.7 JSON" reproducible on a clean clone.

This matches `~/git/neo_snake/third_party/godot-cpp`, which likewise
submodules godot-cpp with no `branch` key in `.gitmodules` and a detached
HEAD at one SHA (its pin predates godot-cpp 10.x, so it is on the pre-10.x
`master` that still carried the 4.7 sync).
