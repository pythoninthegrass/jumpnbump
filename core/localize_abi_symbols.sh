#!/bin/sh
# Post-link pass for `zig build abi` (TASK-012.02): core/abi.zig transitively
# @imports every ported module (via core/game_loop.zig), dragging each
# module's own pre-existing `export fn`/`export var` (steer_players, rnd,
# is_server, player_anims, pogostick, ... -- TASK-011.*'s cross-module-
# linkage convention, non-jnb_-prefixed and predating this ABI) into the
# same static archive. Zig's `export` keyword always emits a
# default-visibility global symbol and there is no way to make one
# file-local from inside Zig itself, so this demotes every defined global
# symbol not matching the frozen jnb_ ABI surface to local. neo_snake never
# needed an equivalent step: its own core/ modules never use bare
# `export fn` outside abi.zig.
#
# The archive has two members: abi.o (abi.zig plus everything it @imports)
# and abi_globals.o (core/abi_globals.zig's real player_raw/objects_raw/
# ban_map_raw/keyb/no_gore storage, kept as its own object rather than
# @imported directly -- see that file's header comment). abi.o references
# several of abi_globals.o's symbols (keyb, etc.) as `extern`, resolved only
# when a later consumer links this archive -- .a members are never linked
# against each other, just stored side by side. If symbols were demoted to
# local per member (the original approach here), abi_globals.o's globals
# would already be local by the time any consumer links against them, and a
# local symbol in one object can never satisfy an extern reference from a
# different object, archive or not (TASK-014.02 hit this as a genuine
# "undefined symbol: keyb" failure loading the GDExtension .so, even with
# --whole-archive forcing both members into the link). So this merges every
# member into one relocatable object first (ld -r), which resolves those
# inter-member references immediately, then localizes the merged object's
# remaining global symbols, then re-archives it as the single-member .a
# `zig build abi`'s consumers already expect.
set -eu

archive="$1"
header="$2"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# GNU objcopy isn't part of Xcode/Command Line Tools on macOS (only
# clang/lld's own toolchain), so on that platform this needs LLVM's
# objcopy (`brew install llvm`, keg-only so not on PATH by default) or
# Homebrew's GNU binutils (`brew install binutils`, whose `gobjcopy` is
# unprefixed to avoid clashing with the system's own `as`/`ld`). Both
# accept the same --keep-global-symbols flag GNU objcopy does.
objcopy=""
for candidate in objcopy llvm-objcopy gobjcopy; do
	if command -v "$candidate" >/dev/null 2>&1; then
		objcopy=$candidate
		break
	fi
done
if [ -z "$objcopy" ] && command -v brew >/dev/null 2>&1; then
	llvm_prefix=$(brew --prefix llvm 2>/dev/null || true)
	if [ -n "$llvm_prefix" ] && [ -x "$llvm_prefix/bin/llvm-objcopy" ]; then
		objcopy="$llvm_prefix/bin/llvm-objcopy"
	fi
fi
if [ -z "$objcopy" ]; then
	echo "error: no objcopy-compatible tool found (objcopy, llvm-objcopy, or gobjcopy)." >&2
	echo "       on macOS: brew install llvm (or binutils), then retry." >&2
	exit 1
fi

archive_abspath=$(CDPATH= cd -- "$(dirname -- "$archive")" && pwd)/$(basename -- "$archive")

# mktemp's default TMPDIR (/tmp) isn't guaranteed writable/executable in
# every sandbox this runs in; a sibling of the archive itself always is.
symbols=$(mktemp -p "$(dirname -- "$archive_abspath")")
workdir=$(mktemp -d -p "$(dirname -- "$archive_abspath")")
trap 'rm -f "$symbols"; rm -rf "$workdir"' EXIT
python3 "$script_dir/../tools/generate_abi_symbols.py" "$header" > "$symbols"

(cd "$workdir" && ar x "$archive_abspath")
# Zig's own archiver stores members with mode 000 (readable via `ar x`
# itself, since ar doesn't apply the stored mode to its own reads, but not
# via any other tool touching the extracted files directly).
chmod u+rw "$workdir"/*.o
ld -r "$workdir"/*.o -o "$workdir/merged.o"
"$objcopy" --keep-global-symbols="$symbols" "$workdir/merged.o"

rm -f "$archive_abspath"
(cd "$workdir" && ar rcs "$archive_abspath" merged.o)
