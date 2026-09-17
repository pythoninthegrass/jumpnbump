#!/bin/sh
# Post-link pass for `zig build abi` (TASK-012.02): core/abi.zig transitively
# @imports every ported module (via core/game_loop.zig), dragging each
# module's own pre-existing `export fn`/`export var` (steer_players, rnd,
# is_server, player_anims, pogostick, ... -- TASK-011.*'s cross-module-
# linkage convention, non-jnb_-prefixed and predating this ABI) into the
# same static archive. Zig's `export` keyword always emits a
# default-visibility global symbol and there is no way to make one
# file-local from inside Zig itself, so this demotes every defined global
# symbol not matching the frozen jnb_ ABI surface to local, in place.
# neo_snake never needed an equivalent step: its own core/ modules never use
# bare `export fn` outside abi.zig.
set -eu

archive="$1"
header="$2"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

symbols=$(mktemp)
trap 'rm -f "$symbols"' EXIT
python3 "$script_dir/../tools/generate_abi_symbols.py" "$header" > "$symbols"

objcopy --keep-global-symbols="$symbols" "$archive"
