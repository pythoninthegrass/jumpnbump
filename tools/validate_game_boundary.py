#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///

"""
Fails if any .gd file outside game/simulation/ references JumpnbumpWorld,
the GDExtension class registered in extension/src/register_types.cpp
(TASK-014.01). game/simulation/world.gd is meant to be the single
pass-through wrapper over JumpnbumpWorld (TASK-014.02); everything else
(presentation/, platform/, content/, tests/) must reach the simulation only
through that wrapper, never the GDExtension class directly.

This is a different concern from tools/validate_simulation_boundary.py,
which enforces that core/*.zig (the actual simulation) never touches
presentation/audio/file-I/O APIs. This script enforces the opposite edge of
the same boundary at the Godot layer: nothing outside game/simulation/ may
reach past the wrapper into the GDExtension class itself.

The one sanctioned exception is a test asserting the class is registered by
name (a JumpnbumpWorld "present" canary, mirroring neo_snake's
test_gdextension_present.gd) -- naming the class in
ClassDB.class_exists("JumpnbumpWorld") does not depend on its API the way
instantiating or calling it does.

Usage: uv run tools/validate_game_boundary.py
"""

import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GAME_DIR = REPO_ROOT / "game"
SIM_DIR = GAME_DIR / "simulation"
EXCLUDED_DIRS = {GAME_DIR / "addons", GAME_DIR / ".godot", GAME_DIR / "reports"}

ALLOWED_LINE = re.compile(r'''ClassDB\.class_exists\(\s*["']JumpnbumpWorld["']\s*\)''')

RULES: list[tuple[str, re.Pattern[str]]] = [
    ("jumpnbump-world", re.compile(r"\bJumpnbumpWorld\b")),
]


@dataclass(frozen=True)
class Violation:
    path: Path
    line_no: int
    rule: str
    text: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line_no}: [{self.rule}] {self.text}"


def scan_file(path: Path) -> list[Violation]:
    violations = []
    for line_no, raw_line in enumerate(path.read_text().splitlines(), start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#") or ALLOWED_LINE.search(raw_line):
            continue
        for rule, pattern in RULES:
            if pattern.search(raw_line):
                violations.append(Violation(path, line_no, rule, stripped))
    return violations


def gd_files_outside_simulation() -> list[Path]:
    files = []
    for path in sorted(GAME_DIR.rglob("*.gd")):
        if path.is_relative_to(SIM_DIR) or any(path.is_relative_to(d) for d in EXCLUDED_DIRS):
            continue
        files.append(path)
    return files


def check_boundary() -> list[Violation]:
    violations = []
    for path in gd_files_outside_simulation():
        violations.extend(scan_file(path))
    return violations


def main() -> int:
    violations = check_boundary()
    for v in violations:
        print(str(v), file=sys.stderr)

    if violations:
        print(f"{len(violations)} game-boundary violation(s)", file=sys.stderr)
        return 1

    print("game boundary: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
