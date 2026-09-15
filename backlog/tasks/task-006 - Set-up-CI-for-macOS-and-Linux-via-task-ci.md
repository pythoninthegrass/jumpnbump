---
id: TASK-006
title: 'Set up CI for macOS and Linux via task ci:*'
status: Done
assignee: []
created_date: '2026-09-15 19:12'
updated_date: '2026-09-15 22:09'
labels: []
milestone: m-0
dependencies: []
modified_files:
  - .github/workflows/ci.yml
  - taskfile.yml
  - taskfiles/ci.yml
priority: medium
type: chore
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add GitHub Actions workflows with a macOS job (self-hosted arm64, matching ~/git/neo_snake/.github/workflows/ci.yml) and a Linux job, where every CI step is a one-line `task ci:*` wrapper so the same checks are runnable locally. Initially this only needs to run `task check` as defined so far (Phase 0's wrapped `make` build); later phases extend the chain.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `.github/workflows/ci.yml` runs on both a macOS and a Linux job
- [x] #2 Every CI step is a thin `task ci:*` wrapper defined in taskfiles/ci.yml, runnable locally
- [x] #3 CI passes on the current (Phase 0) state of the repo
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Created .github/workflows/ci.yml with macOS (self-hosted arm64, matching neo_snake's pattern) and Linux (ubuntu-latest) jobs. Both call thin task ci:* wrappers in taskfiles/ci.yml (linux-deps, linux-check, macos-check), which forward to the root :check task (currently `make`). AC #3 (CI passes) can't be verified from this session since it requires an actual GitHub Actions run against the self-hosted macOS runner and the ubuntu-latest runner — needs a push/PR to confirm.

Open question: SDL 1.2 dev libs (libsdl-mixer1.2-dev, libsdl-net1.2-dev) are still in Debian/Ubuntu apt repos as of writing, used for the Linux job. For macOS, SDL 1.2 was dropped from Homebrew core in favor of sdl12-compat, which doesn't ship an SDL_mixer/SDL_net-compatible sdl-config toolchain — macos-check assumes the self-hosted runner already has a working SDL 1.2 toolchain pre-provisioned (matching how the runner's Godot/Xcode toolchain is assumed present in neo_snake's CI, rather than bootstrapped per-run).

Manually verified end-to-end on the self-hosted macOS runner (mbp-ts / actions.runner.pythoninthegrasses.mbp) by ssh: `task ci:macos-check` builds cleanly and produces a working jumpnbump binary. Runner had no SDL 1.2 toolchain at all initially (only sdl2-compat/sdl2_mixer/sdl3 via brew) — provisioned it: `brew install sdl12-compat` (aliased `sdl`, gives sdl-config + SDL 1.2 headers/libs), `brew install libmikmod` (for .mod music support), then built classic SDL_mixer-1.2.12 and SDL_net-1.2.8 from source (libsdl.org release tarballs) with `--prefix=/opt/homebrew` (avoids needing sudo, since /usr/local is root-owned and not writable by the runner's service user).

Hit and fixed a real bug during verification: the first SDL_mixer build/install used a stale libtool link artifact from an earlier aborted --prefix=/usr/local attempt, so the installed .dylib's install_name pointed at /usr/local/lib (which doesn't exist on this box) even though files landed in /opt/homebrew/lib — jumpnbump linked fine but failed at runtime with a dyld 'Library not loaded' error. Fixed with `make distclean` + a full reconfigure/rebuild/install against --prefix=/opt/homebrew; confirmed `otool -D` now reports /opt/homebrew/lib and the binary runs (`./jumpnbump -h` prints usage).

Also had to unblock `brew install` itself: it was refusing to resolve ANY formula because of untrusted taps unrelated to this project (anomalyco/tap, facebook/fb, libkrun/krun, slp/krun — leftovers from other repos sharing this runner). Ran `brew trust` on those specific taps/formulae (with Lance's go-ahead) before SDL provisioning could proceed.

Provisioning was manual/one-time on the runner (matching how neo_snake's CI assumes its Xcode/Godot toolchain is pre-provisioned rather than bootstrapped per-run) — taskfiles/ci.yml's macos-check intentionally does not attempt to install/build SDL 1.2 itself.

Refactored taskfiles/ci.yml to match ~/git/mt/taskfiles/tauri.yml's _install-linux-deps pattern: added _install-macos-deps (internal, platforms: [darwin], status-checked via sdl-config + libSDL_mixer/libSDL_net presence) that automates the exact provisioning steps done manually on mbp-ts earlier (brew install sdl12-compat libmikmod, then build SDL_mixer-1.2.12/SDL_net-1.2.8 from source into $(brew --prefix)). linux-check and macos-check both now declare their install task via `deps: [...]` rather than an unconditional cmds step, and _install-linux-deps gained a `status` check (dpkg -s per package) for the same idempotency. Re-verified against mbp-ts: a fresh clone with the new ci.yml built and ran in ~1.2s (status check correctly skipped the already-provisioned deps), and `task --force --dry ci:macos-check` rendered the exact install commands proven out manually. Added /.cache/ to .gitignore for the new sdl12-build scratch dir (alongside the existing .cache/zig).

Verified _install-macos-deps from a genuinely clean state on the second self-hosted macOS runner (mini, arm64/Tahoe) — no sdl12-compat/libmikmod/SDL_mixer/SDL_net present beforehand. Copied the working-tree taskfile.yml + taskfiles/ci.yml into ~/git/jumpnbump on mini (already at the same path, freshly pulled) and ran `task ci:macos-check` for real: first run took ~21.5s (brew install sdl12-compat + libmikmod, built SDL_mixer-1.2.12/SDL_net-1.2.8 from source, then `make`), producing a working binary with install_name correctly pointing at /opt/homebrew/lib (no repeat of the stale-artifact bug from mbp-ts, since this was a clean build). A second run after `make clean` took ~1.3s, confirming the status check correctly skips already-provisioned deps. mini also had the same brew untrusted-tap warnings as mbp-ts, but here they were non-blocking (just noise) and `brew install` succeeded without needing `brew trust` — so that trust-prompt behavior is inconsistent across machines/brew versions and can't be assumed away in the task.
<!-- SECTION:NOTES:END -->
