#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///

"""
Self-check for tools/validate_game_boundary.py (TASK-014.01).

Runs the scanner over in-memory fixtures via tempfile instead of the repo:
one fixture that must fail (a JumpnbumpWorld reference outside
game/simulation/), one clean fixture, and the sanctioned
ClassDB.class_exists("JumpnbumpWorld") canary exception.

Usage: uv run tools/test_validate_game_boundary.py
"""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_game_boundary as boundary


def main() -> int:
    failures: list[str] = []

    violating = "func f():\n    var w = JumpnbumpWorld.new()\n"

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        (tmp_path / "presentation").mkdir()
        (tmp_path / "presentation" / "bad.gd").write_text(violating)
        (tmp_path / "presentation" / "clean.gd").write_text("func f():\n    var x = 1\n")
        (tmp_path / "presentation" / "canary.gd").write_text(
            'func test_present():\n    assert(ClassDB.class_exists("JumpnbumpWorld"))\n'
        )
        (tmp_path / "simulation").mkdir()
        (tmp_path / "simulation" / "world.gd").write_text(
            "func f():\n    var w = JumpnbumpWorld.new()\n"
        )

        orig_game_dir = boundary.GAME_DIR
        orig_sim_dir = boundary.SIM_DIR
        orig_excluded = boundary.EXCLUDED_DIRS
        boundary.GAME_DIR = tmp_path
        boundary.SIM_DIR = tmp_path / "simulation"
        boundary.EXCLUDED_DIRS = set()
        try:
            violations = boundary.check_boundary()
        finally:
            boundary.GAME_DIR = orig_game_dir
            boundary.SIM_DIR = orig_sim_dir
            boundary.EXCLUDED_DIRS = orig_excluded

    flagged = {v.path.name for v in violations}
    if "bad.gd" not in flagged:
        failures.append("bad.gd: expected a jumpnbump-world violation, scanner found none")
    if "clean.gd" in flagged:
        failures.append("clean.gd: expected no violation, scanner flagged it")
    if "canary.gd" in flagged:
        failures.append("canary.gd: ClassDB.class_exists canary should be exempt")
    if "world.gd" in flagged:
        failures.append("world.gd: game/simulation/ is exempt entirely, scanner flagged it")

    if failures:
        print("FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        return 1

    print("test_validate_game_boundary: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
