"""Bounded source regression runner; network integration remains a separate command."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SUITES = ["rules", "gameplay", "forest_handgun", "bot_duel", "high_ground", "stealth",
          "forest_wildlife", "replay", "invites", "connection_lifecycle", "model_assets",
          "bot_awareness", "bot_tactics", "study_recording", "featured_session", "mountainside", "mountain_bots", "bot_information", "duel_slice", "replay_duel", "duel_interface", "ridge_revision", "practice_lessons", "relay_rules", "demo_game", "demo_ui", "demo_replay", "demo_field", "field_journal", "demo_recording"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts/ai-upgrade/regression")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    results = []
    for name in SUITES + ["bot_study_analysis"]:
        command = ([os.sys.executable, str(ROOT / "tests/test_bot_study_analysis.py")] if name == "bot_study_analysis" else
                   [args.godot, "--headless", "--fixed-fps", "60", "--path", str(ROOT), "--script", f"res://tests/test_{name}.gd"])
        log = args.out / (name + ".log")
        code = -1
        with log.open("w") as output:
            try:
                code = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=90, cwd=ROOT).returncode
            except subprocess.TimeoutExpired:
                output.write("\nFAIL: suite exceeded 90 seconds\n")
        lines = log.read_text().splitlines()
        errors = [line for line in lines if line.startswith(("FAIL:", "ERROR:", "SCRIPT ERROR:"))]
        summary = [line for line in lines if re.match(r"^[A-Z_]+_RESULT checks=", line) or line.startswith("Rules:") or line.startswith("Ran ") or line == "OK"]
        item = {"suite": name, "exit": code, "summary": summary, "errors": errors}
        results.append(item)
        print(json.dumps(item), flush=True)
    (args.out / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    raise SystemExit(0 if all(item["exit"] == 0 and not item["errors"] and item["summary"] for item in results) else 1)


if __name__ == "__main__":
    main()
