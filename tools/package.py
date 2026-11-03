#!/usr/bin/env python3
"""Create local source and desktop bundles. Does not upload or publish anything."""
import argparse
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--platform", choices=("windows", "linux"), default="windows")
parser.add_argument("--label", choices=("", "Duel", "Demo"), default="")
args = parser.parse_args()
build = ROOT / "builds" / args.platform
executable = build / ("CloseTheGap.exe" if args.platform == "windows" else "CloseTheGap.x86_64")
for required in (executable, build / "CloseTheGap.pck", build / "Godot-LICENSES.txt"):
    if not required.is_file():
        raise SystemExit(f"Missing build file: {required}")
for name in ("README.md", "CREDITS.md", "LICENSE", "START-HERE.txt"):
    shutil.copy2(ROOT / name, build / name)
shutil.copytree(ROOT / "docs", build / "docs", dirs_exist_ok=True)
for source in sorted((ROOT / "assets").rglob("*LICENSE*.txt")):
    target = build / "asset-licenses" / source.relative_to(ROOT / "assets")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
shutil.copy2(ROOT / "assets/models/SOURCES.json", build / "asset-licenses/SOURCES.json")
if (ROOT / "third_party").is_dir():
    shutil.copytree(ROOT / "third_party", build / "third_party", dirs_exist_ok=True)

prefix = "Close-the-Gap" + ("-" + args.label if args.label else "")
source_archive = ROOT.parent / f"{prefix}-Godot.zip"
with zipfile.ZipFile(source_archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(ROOT.rglob("*")):
        relative = path.relative_to(ROOT)
        if any(part in {".godot", ".git", "builds", "artifacts", "__pycache__"} for part in relative.parts):
            continue
        if path.is_file():
            archive.write(path, Path("close-the-gap") / relative)

platform_archive = ROOT.parent / f"{prefix}-{args.platform.capitalize()}.zip"
with zipfile.ZipFile(platform_archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(build.rglob("*")):
        if path.is_file():
            archive.write(path, Path("Close-the-Gap") / path.relative_to(build))
for path in (source_archive, platform_archive):
    print(f"{path.name}: {path.stat().st_size / 1024 / 1024:.1f} MiB")
