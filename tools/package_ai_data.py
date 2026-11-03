"""Package local experiment data without model archives or private network state."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "artifacts/ai-upgrade"
OUTPUT = ROOT.parent / "Close-the-Gap-AI-Data.zip"


def main():
    files = []
    for folder in ["baseline-study", "pilot-study", "pre-review-study", "route-profile-study", "final-study", "representative-baseline", "representative-study"]:
        for name in ["results.json", "trace.jsonl"]:
            path = DATA / folder / name
            if not path.is_file():
                raise SystemExit(f"Missing experiment data: {path}")
            files.append((path, Path("studies") / folder / name))
    for folder in ["analysis", "final-policy", "final-regression"]:
        for path in sorted((DATA / folder).rglob("*")):
            if path.is_file() and path.suffix in {".json", ".csv", ".md", ".gd", ".log"}:
                files.append((path, Path(folder) / path.relative_to(DATA / folder)))
    for path in sorted((DATA / "baseline/scripts").glob("*.gd")):
        files.append((path, Path("baseline-source/scripts") / path.name))
    for name in ["replays/ai-session.json", "docs/ai-gameplay-study.md", "docs/bot-ai-research.md", "docs/images/ai-middle-round.png", "LICENSE"]:
        files.append((ROOT / name, Path(name)))
    for name in ["slow-route-input.json", "slow-route-before.log", "slow-route-after.log", "profile_routes.gd",
                 "video-verification.json", "middle-motion.framemd5", "review-red.log", "review-green.log",
                 "adaptive-rear-red.log", "adaptive-rear-green.log", "budget-mutant-red.log"]:
        files.append((DATA / name, Path("evidence") / name))
    manifest = {"format": "CTG_AI_STUDY_BUNDLE", "version": 1, "files": []}
    readme = """Close the Gap — AI experiment data

Start with docs/ai-gameplay-study.md and analysis/report.md.
analysis/rounds.csv is the final 48-round spreadsheet table.
The representative-baseline and representative-study folders use normal
startup countdowns and supply the final comparison. Earlier development
batches shortened countdowns and remain available as exploratory evidence.
studies contains raw per-round JSON and 4 Hz JSONL telemetry for every batch.
replays/ai-session.json is the full five-round 20 Hz recording with 60 Hz events.
analysis/round-selection.json identifies the third completed round, selected
by index independently of outcome, with source hash and exact video ticks.
final-policy and baseline-source retain source snapshots; the separate Godot
source download supplies the unchanged art and other project files.

No video, model archives, invitations or connection credentials are included.
No service was deployed and nothing was published by this packaging command.
"""
    with zipfile.ZipFile(OUTPUT, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        archive.writestr("Close-the-Gap-AI-Data/README.txt", readme)
        for path, relative in files:
            data = path.read_bytes()
            manifest["files"].append({"path": relative.as_posix(), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
            archive.writestr("Close-the-Gap-AI-Data/" + relative.as_posix(), data)
        archive.writestr("Close-the-Gap-AI-Data/manifest.json", json.dumps(manifest, indent=2) + "\n")
    with zipfile.ZipFile(OUTPUT) as archive:
        assert archive.testzip() is None
    print(json.dumps({"file": str(OUTPUT), "bytes": OUTPUT.stat().st_size, "data_files": len(files), "crc": "pass"}))


if __name__ == "__main__":
    main()
