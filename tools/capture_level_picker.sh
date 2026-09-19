#!/usr/bin/env bash
# TASK-016.02 follow-up: real-rendered screenshots of the level picker /
# menu / gameplay screens under a headless sway compositor, since headless
# gdUnit4 alone only proves the scene tree and signal wiring, not actual
# rendering. Same sway+grim stack (and the same "real key/click injection
# into Godot doesn't reliably land" finding) as ~/git/neo_snake's
# tools/capture_parity.sh / backlog/decisions/decision-025 -- see
# game/presentation/main.gd's _maybe_drive_capture_state() for the
# --capture-state= debug hook this drives instead of simulating input.
#
# Output is PNGs for a human to eyeball -- not an automated pixel-diff
# gate. Linux + Wayland-tooling only, not part of `task check`.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$ROOT_DIR/artifacts/level_picker}"
STATES=(title menu level_picker level_picker_error gameplay_builtin gameplay_custom)

for bin in sway grim godot; do
	command -v "$bin" >/dev/null 2>&1 || {
		echo "capture_level_picker: missing required binary: $bin" >&2
		exit 1
	}
done

mkdir -p "$OUT_DIR"
WORKDIR="$(mktemp -d)"

SWAY_PID=""

cleanup() {
	[ -n "$SWAY_PID" ] && kill -9 "$SWAY_PID" >/dev/null 2>&1 || true
	rm -rf "$WORKDIR"
}
trap cleanup EXIT

SWAY_CONF="$WORKDIR/sway.conf"
cat >"$SWAY_CONF" <<EOF
output HEADLESS-1 resolution 800x512
EOF

env WLR_BACKENDS=headless WLR_RENDERER=pixman sway -c "$SWAY_CONF" >"$WORKDIR/sway.log" 2>&1 &
SWAY_PID=$!
sleep 2

SOCK="$(ls "${XDG_RUNTIME_DIR}"/wayland-[0-9]* 2>/dev/null | head -1)"
if [ -z "$SOCK" ]; then
	echo "capture_level_picker: sway produced no wayland socket -- see $WORKDIR/sway.log" >&2
	exit 1
fi
export WAYLAND_DISPLAY
WAYLAND_DISPLAY="$(basename "$SOCK")"

echo "capturing Godot states..."
for state in "${STATES[@]}"; do
	env SDL_VIDEODRIVER=wayland godot --path "$ROOT_DIR/game" \
		--rendering-driver opengl3 --rendering-method gl_compatibility \
		-- "--capture-state=$state" >"$WORKDIR/godot-$state.log" 2>&1 &
	pid=$!
	sleep 4
	grim "$OUT_DIR/$state.png"
	kill -9 "$pid" >/dev/null 2>&1 || true
	wait "$pid" 2>/dev/null || true
	sleep 1
done

echo "done -- screenshots in $OUT_DIR"
