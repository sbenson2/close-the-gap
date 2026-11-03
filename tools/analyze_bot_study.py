"""Summarize saved headless telemetry and select an outcome-independent middle round."""
import argparse
from collections import Counter
import csv
import hashlib
import json
from pathlib import Path
from statistics import median


def analyze_study(data):
    rows = data["rounds"]
    result = {"rounds": len(rows), "controller_sha256": data.get("controller_sha256"), "maps": {}}
    for level in sorted({row["level"] for row in rows}):
        group = [row for row in rows if row["level"] == level]
        duration = sum(row["duration"] for row in group)
        unseen = 0
        for row in group:
            sniper = next(bot for bot in row["bots"] if bot["role"] == "sniper")
            unseen += row["winner_role"] == "stalker" and "knife" in row["result"].lower() and sniper["sightings"] == 0
        result["maps"][level] = {
            "rounds": len(group), "seeds": sorted({row["seed"] for row in group}),
            "wins": dict(Counter(row["winner_role"] for row in group)),
            "timeouts": sum("time expired" in row["result"].lower() for row in group),
            "unfinished": sum(row["winner_role"] == "none" for row in group),
            "unseen_knife_finishes": unseen,
            "median_duration": median(row["duration"] for row in group),
            "sniper_stationary_fraction": min(1, sum(row["sniper_stationary_seconds"] for row in group) / max(duration, 1)),
            "median_stalker_exposure_seconds": median(row["sniper_sees_seconds"] for row in group),
            "stalker_stalled_seconds": sum(row["stalker_stalled_seconds"] for row in group),
            "high_ground_violations": sum(row["high_ground_violations"] for row in group),
            "mean_path_queries": sum(bot["path_queries"] for row in group for bot in row["bots"]) / len(group),
            "max_route_ms": max((bot.get("max_route_ms", 0) for row in group for bot in row["bots"]), default=0),
        }
    return result


def select_middle_round(data):
    rounds = data.get("rounds", [])
    if len(rounds) < 3:
        raise ValueError("At least three completed rounds are required to choose a middle round.")
    index = len(rounds) // 2
    chosen = rounds[index]
    scene = int(chosen["scene"])
    frames = [frame for frame in data["frames"] if int(frame["r"]) == scene]
    if len(frames) < 2:
        raise ValueError("The selected round has no complete saved state interval.")
    start, end = int(frames[0]["t"]), int(frames[-1]["t"])
    return {"scene": scene, "ordinal": index + 1, "completed_rounds": len(rounds),
            "start_tick": start, "end_tick": end, "start": start / 60,
            "seconds": (end - start) / 60, "frames": end - start,
            "result": chosen["result"], "selection_rule": "middle completed round by index, independent of outcome"}


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def validate_comparison(baseline, study):
    if baseline.get("normal_countdown") != study.get("normal_countdown"):
        raise ValueError("Cannot compare policies with different countdown settings.")
    for key, legacy in [('ruleset_id', 'classic_v1'), ('map_revision', 'ridge_v1')]:
        if baseline.get(key, legacy) != study.get(key, legacy):
            raise ValueError("Cannot compare policy outcomes across different rules or terrain revisions.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--study", type=Path, required=True)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--replay", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    upgraded = json.loads(args.study.read_text())
    report = {"upgraded": analyze_study(upgraded), "inputs": {"study_sha256": digest(args.study)}}
    if args.baseline:
        baseline = json.loads(args.baseline.read_text())
        validate_comparison(baseline, upgraded)
        keys = {(row["level"], row["seed"], row["assignment"]) for row in baseline["rounds"]}
        paired = {**upgraded, "rounds": [row for row in upgraded["rounds"] if (row["level"], row["seed"], row["assignment"]) in keys]}
        report.update(baseline=analyze_study(baseline), paired_upgraded=analyze_study(paired))
        report["inputs"]["baseline_sha256"] = digest(args.baseline)
    args.out.mkdir(parents=True, exist_ok=True)
    if args.replay:
        recording = json.loads(args.replay.read_text())
        selection = select_middle_round(recording)
        selection.update(replay=str(args.replay.resolve()), replay_sha256=digest(args.replay))
        if recording.get('level') == 'mountain':
            selection['output_stem'] = 'duel-round' if recording.get('ruleset_id') == 'duel_v2' else 'mountain-round'
        (args.out / "round-selection.json").write_text(json.dumps(selection, indent=2) + "\n")
        report["recording"] = selection
    (args.out / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    fields = ["id", "level", "seed", "assignment", "duration", "winner_role", "result",
              "sniper_sightings", "stalker_sightings", "sniper_shots", "stalker_attacks",
              "sniper_stationary_seconds", "sniper_sees_seconds", "stalker_stalled_seconds",
              "high_ground_violations", "sniper_hide_lanes", "max_route_ms"]
    with (args.out / "rounds.csv").open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        for row in upgraded["rounds"]:
            bots = {bot["role"]: bot for bot in row["bots"]}
            flat = {field: row.get(field, "") for field in fields}
            flat.update(sniper_sightings=bots["sniper"]["sightings"], stalker_sightings=bots["stalker"]["sightings"],
                        sniper_shots=bots["sniper"].get("shots", 0), stalker_attacks=bots["stalker"].get("shots", 0),
                        sniper_hide_lanes=bots["sniper"].get("hide_lanes", 0),
                        max_route_ms=max(bot.get("max_route_ms", 0) for bot in row["bots"]))
            writer.writerow(flat)
    lines = ["# Bot gameplay study", "", "Saved headless simulations at 60 physics ticks/s; telemetry sampled at 4 Hz. Both role assignments are included for each map/seed. No human balance or enjoyment claim is made.", "",
             "The paired comparison uses only the baseline's map/seed/assignment combinations. The full upgraded sample also includes the additional seeds.", "",
             "| Dataset | Map | Rounds | Stalker / sniper wins | Timeouts | Unseen knife finishes | Median round (s) |",
             "| --- | --- | ---: | ---: | ---: | ---: | ---: |"]
    for key in ["baseline", "paired_upgraded", "upgraded"]:
        for level, row in report.get(key, {}).get("maps", {}).items():
            lines.append(f"| {key} | {level} | {row['rounds']} | {row['wins'].get('stalker', 0)} / {row['wins'].get('sniper', 0)} | {row['timeouts']} | {row['unseen_knife_finishes']} | {row['median_duration']:.2f} |")
    lines += ["", "| Dataset | Map | Sniper stationary | Median stalker seen (s) | Total stalker stall (s) | High-ground violations | Mean path queries/round |", "| --- | --- | ---: | ---: | ---: | ---: | ---: |"]
    for key in ["baseline", "paired_upgraded", "upgraded"]:
        for level, row in report.get(key, {}).get("maps", {}).items():
            lines.append(f"| {key} | {level} | {row['sniper_stationary_fraction']:.1%} | {row['median_stalker_exposure_seconds']:.2f} | {row['stalker_stalled_seconds']:.2f} | {row['high_ground_violations']} | {row['mean_path_queries']:.1f} |")
    lines += ["", "Stationary time measures movement, not concealment. Concealment and usable firing peeks are separately checked against actual geometry. Seen/stall durations are sampled estimates with 0.25-second resolution. A brief stall around a turn is different from a persistent failed route; inspect trace outliers before diagnosis.", "",
              "An unseen knife finish means a knife elimination with zero sniper visual acquisitions in that round. It does not infer the stalker's private intent or prove that a human would have failed to notice it.", "",
              "Raw results, sampled positions/aims/state/evidence, seeds and controller hashes are retained for reproduction. The final policy must remain fixed across its measured batch. CPU query timings are headless query timings, not live rendering FPS."]
    if "recording" in report:
        selected = report["recording"]
        lines += ["", f"Selected round {selected['ordinal']} of {selected['completed_rounds']} by index, independent of outcome: {selected['result']} Replay ticks {selected['start_tick']}–{selected['end_tick']}, {selected['frames']} output video frames at 60 fps."]
    (args.out / "report.md").write_text("\n".join(lines) + "\n")
    print(json.dumps({"rounds": report["upgraded"]["rounds"], "maps": report["upgraded"]["maps"], "selection": report.get("recording")}), flush=True)


if __name__ == "__main__":
    main()
