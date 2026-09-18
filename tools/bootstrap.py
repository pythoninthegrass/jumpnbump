#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///

"""
Bootstrap pinned local game tooling: today, just gdUnit4 (the Tier-D test
framework, TASK-014.07). Godot itself is installed via mise (.tool-versions
pins godot@4.7.1-stable) and already runs headless on every platform this
repo builds on, so unlike ~/git/neo_snake's bootstrap.py there is no
fallback-binary/export-template download path here -- add one only if a
future platform's mise asset turns out not to be headless-capable.

gdUnit4 is a checksum-verified download, extracted to game/addons/gdUnit4
(gitignored, not vendored). All pins live in tools/game_toolchain.lock,
overridable per-entry via same-named environment variables.

Usage:
    ./tools/bootstrap.py game [all|gdunit4]
"""

import hashlib
import os
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
LOCK_FILE = Path(__file__).resolve().parent / "game_toolchain.lock"
DOWNLOADS_DIR = REPO_ROOT / ".tools" / "game" / "downloads"


def die(message: str) -> None:
    raise SystemExit(message)


def load_pins() -> dict[str, str]:
    pins: dict[str, str] = {}
    for line in LOCK_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        pins[key.strip()] = value.strip().strip('"')
    for key in pins:
        if key in os.environ:
            pins[key] = os.environ[key]
    return pins


def require_pin(pins: dict[str, str], key: str) -> str:
    if key not in pins:
        die(f"{key} is not set in tools/game_toolchain.lock (or the environment).")
    return pins[key]


def download_verified(url: str, sha256: str, destination: Path) -> None:
    if destination.exists():
        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
        if digest == sha256:
            print(f"Reusing verified {destination.name}")
            return
        destination.unlink()
    print(f"Downloading {url}")
    try:
        with urllib.request.urlopen(url) as response:
            data = response.read()
    except OSError as e:
        die(f"Could not download {url}: {e}")
    digest = hashlib.sha256(data).hexdigest()
    if digest != sha256:
        die(f"Checksum mismatch for {url}\n  expected {sha256}\n  got      {digest}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)


def install_gdunit4(pins: dict[str, str]) -> None:
    version = require_pin(pins, "GDUNIT4_VERSION")
    archive = DOWNLOADS_DIR / f"gdUnit4-{version}.zip"
    download_verified(require_pin(pins, "GDUNIT4_URL"), require_pin(pins, "GDUNIT4_SHA256"), archive)

    addon_dir = REPO_ROOT / "game" / "addons" / "gdUnit4"
    staging = DOWNLOADS_DIR / f".staging-gdUnit4-{version}"
    shutil.rmtree(staging, ignore_errors=True)
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(staging)
    source_dir = next(staging.glob("gdUnit4-*/addons/gdUnit4"))
    addon_dir.parent.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(addon_dir, ignore_errors=True)
    shutil.move(str(source_dir), str(addon_dir))
    shutil.rmtree(staging, ignore_errors=True)
    print(f"gdUnit4 {version} is ready beneath {addon_dir}")


def bootstrap_game(component: str) -> None:
    if component not in ("all", "gdunit4"):
        die("Usage: bootstrap.py game [all|gdunit4]")
    if component in ("all", "gdunit4"):
        install_gdunit4(load_pins())


COMMANDS = {
    "game": lambda args: bootstrap_game(args[0] if args else "all"),
}


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        die(f"Usage: {sys.argv[0]} <{'|'.join(COMMANDS)}> [component]")
    COMMANDS[sys.argv[1]](sys.argv[2:])


if __name__ == "__main__":
    try:
        main()
    except (OSError, zipfile.BadZipFile) as e:
        die(str(e))
