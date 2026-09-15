# Jump'n'Bump

Cute fluffy bunnies hop on each other's heads. Whoever bumps the most heads wins. Local
multiplayer (up to 4 players), custom levels, and UDP netplay. Originally released by
Brainchild Design in 1998; this fork is a Linux/SDL port from 2004 that's now being
re-platformed onto a Zig simulation core rendered by Godot.

## Status

This repo is **mid-port**. The target architecture (below) is scaffolding today, not a
working build:

- `core/`, `include/`, `extension/`, `game/`, `tools/` exist with the intended layout and
  `core/build.zig`'s four steps (`test`, `difftest`, `abi`, `abitest`) are wired up, but no
  simulation code has been ported yet — `core/abi.zig` is still empty.
- There is no Godot project, no GDExtension build, and no `jumpnbump.h` yet.
- **The legacy SDL 1.2 build below is the only way to actually play the game right now.**

See `backlog/tasks/` for per-task status and `docs/porting-playbook.md` /
`docs/build-layout.md` for where this is headed.

## Playing it today (legacy SDL build)

Requires SDL 1.2, SDL_mixer, SDL_net, zlib, and bzip2 dev packages. Debian/Ubuntu:

```sh
apt-get install libsdl1.2-dev libsdl-mixer1.2-dev libsdl-net1.2-dev zlib1g-dev libbz2-dev
```

(macOS: see `taskfiles/ci.yml`'s `ci:_install-macos-deps` for the Homebrew + from-source
SDL_mixer/SDL_net setup used in CI.)

Then build and run:

```sh
task check          # currently just runs `make`
./jumpnbump
```

`make install` installs to `$(PREFIX)/games` and `$(PREFIX)/share/jumpnbump`
(`PREFIX=/usr/local` by default). `make clean` cleans `sdl/`, `modify/`, `data/`, and the
top-level objects/binaries.

### Controls

| Player | Keys |
| --- | --- |
| Dott  | `a`, `w`, `d` |
| Jiffy | arrow keys |
| Fizz  | `j`, `i`, `l` |
| Mijji | numpad `4`, `8`, `6` |

`f10` toggles windowed/fullscreen, `esc`/`f12` quits.

### Custom levels, screensaver, and netplay

```sh
jumpnbump -dat levelname.dat            # load a custom level (see levelmaking/)
jumpnbump -fireworks -fullscreen        # fireworks screensaver mode

# netplay (UDP), same -dat level on every peer:
jumpnbump -port 7777 -net 0 <host_of_player2> <port_of_player2>   # player 1
jumpnbump -port 7777 -net 1 <host_of_player1> <port_of_player1>   # player 2
# -net 2/-net 3 add a 3rd/4th player the same way
```

## Building and testing

`task check` is the single documented gate — today it runs the legacy `make` build.
`taskfiles/ci.yml` wires the same command into GitHub Actions for both Linux and macOS
(`task ci:linux-check`, `task ci:macos-check`).

`core/build.zig` defines the Zig side, run from `core/` (`zig build <step>`):

- `test` — Tier-A unit tests for ported modules (empty until a `core/*.zig` module lands)
- `difftest` — Tier-B differential tests against the legacy C oracle (empty until the
  corpus/harness lands)
- `abi` — builds `core/abi.zig` as a static library
- `abitest` — Tier-C ABI conformance tests

`taskfiles/core.yml`, `taskfiles/extension.yml`, and `taskfiles/game.yml` are intentionally
not created yet — they get wired into `taskfile.yml`'s `includes:` as each corresponding
build lands.

## Architecture

| Path | Purpose |
| --- | --- |
| `core/` | Zig simulation core: physics, collision, AI, particles, game loop |
| `include/` | `jumpnbump.h`, the frozen C ABI between `core/` and `extension/` |
| `extension/` | godot-cpp GDExtension shim, forwarding 1:1 to the C ABI |
| `game/` | Godot 4.7.1 project |
| `tools/` | Asset pipeline + boundary/purity validator scripts |
| `main.c`, `sdl/`, `modify/`, `data/` | Legacy SDL/C game — retained forever as the differential-test oracle |

The legacy C tree isn't dead code to delete once the port lands: it's what the new Zig
simulation core is checked against frame-by-frame, so behavioral drift in the port shows up
as a failing diff rather than a silent regression. See `docs/build-layout.md` for the full
layout and `docs/porting-playbook.md` for the porting procedure and verification tiers.

## Credits

Original DOS game by Brainchild Design — see `readme.txt`. Linux/SDL port credits and the
upstream 2004 README are preserved in `docs/legacy-readme.md`.
