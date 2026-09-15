# core/

The deterministic Zig simulation core: the game's physics, collision, scoring,
and AI logic, ported line-for-line from `main.c` and differential-tested
against it (see `TASK-008`). Builds via `zig build`, exposing `test`,
`difftest`, `abi`, and `abitest` steps (`TASK-003`). Never links against
libc I/O, SDL, or Godot — presentation and platform concerns live in `game/`
and `extension/` (`TASK-011.08`).

Placeholder until `TASK-003` sets up the build graph.
