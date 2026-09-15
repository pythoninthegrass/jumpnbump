# game/

The Godot 4.7.1 project. A single `main.tscn`/script, everything else
assembled in code, split into four layers matching
`~/git/neo_snake/game/`'s convention:

- `simulation/` — the only layer allowed to reference the GDExtension class
- `presentation/` — sprites, level layers, scoreboard rendering
- `platform/` — input routing, settings persistence, app lifecycle
- `content/` — data-driven config (palettes, tuning, audio manifests)

A boundary-validator script fails `task check` if any script outside
`simulation/` touches the GDExtension class (`TASK-014.01`).

Placeholder until `TASK-014.01` creates the project skeleton.
