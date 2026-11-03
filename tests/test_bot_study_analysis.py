import importlib.util
from pathlib import Path
import unittest


class BotStudyAnalysisTests(unittest.TestCase):
    def module(self):
        path = Path(__file__).resolve().parents[1] / "tools/analyze_bot_study.py"
        self.assertTrue(path.exists(), "study analysis and middle-round selection are implemented")
        spec = importlib.util.spec_from_file_location("bot_study_analysis", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_reports_role_outcomes_and_actual_hidden_finishes(self):
        rows = [
            {"level": "forest", "seed": 71, "duration": 40, "winner_role": "stalker", "result": "Knife elimination.",
             "sniper_stationary_seconds": 30, "stalker_stalled_seconds": 1, "high_ground_violations": 0,
             "sniper_sees_seconds": 0, "bots": [{"role": "sniper", "sightings": 0, "path_queries": 2}, {"role": "stalker", "path_queries": 8}]},
            {"level": "forest", "seed": 208, "duration": 60, "winner_role": "sniper", "result": "Rifle elimination.",
             "sniper_stationary_seconds": 50, "stalker_stalled_seconds": 0, "high_ground_violations": 0,
             "sniper_sees_seconds": 3, "bots": [{"role": "sniper", "sightings": 1, "path_queries": 4}, {"role": "stalker", "path_queries": 6}]},
        ]
        result = self.module().analyze_study({"rounds": rows})["maps"]["forest"]
        self.assertEqual(result["wins"], {"stalker": 1, "sniper": 1})
        self.assertEqual(result["unseen_knife_finishes"], 1)
        self.assertEqual(result["median_duration"], 50)
        self.assertEqual(result["sniper_stationary_fraction"], 0.8)
        self.assertEqual(result["high_ground_violations"], 0)

    def test_selects_actual_third_round_independently_of_winner(self):
        data = {"scenes": [{"index": i} for i in range(5)],
                "rounds": [{"scene": i, "result": "Time expired." if i == 2 else "Knife elimination."} for i in range(5)],
                "frames": [{"r": i, "t": i * 600 + offset} for i in range(5) for offset in [0, 300, 597]]}
        selection = self.module().select_middle_round(data)
        self.assertEqual(selection["scene"], 2)
        self.assertEqual(selection["ordinal"], 3)
        self.assertEqual(selection["start_tick"], 1200)
        self.assertEqual(selection["end_tick"], 1797)
        self.assertEqual(selection["frames"], 597)
        self.assertEqual(selection["result"], "Time expired.")

    def test_rejects_a_session_without_a_middle_completed_round(self):
        with self.assertRaisesRegex(ValueError, "three"):
            self.module().select_middle_round({"rounds": [{"scene": 0}], "scenes": [], "frames": []})

    def test_rejects_comparisons_with_different_startup_timing(self):
        module = self.module()
        if not hasattr(module, "validate_comparison"):
            self.fail("comparison validates startup timing before reporting policy differences")
        with self.assertRaisesRegex(ValueError, "countdown"):
            module.validate_comparison({"normal_countdown": True}, {"normal_countdown": False})
        module.validate_comparison({"normal_countdown": True}, {"normal_countdown": True})

    def test_rejects_comparison_between_different_rules_or_terrain(self):
        module = self.module()
        baseline = {"normal_countdown": True, "ruleset_id": "classic_v1", "map_revision": "ridge_v1"}
        with self.assertRaisesRegex(ValueError, "rules|terrain|revision"):
            module.validate_comparison(baseline, {**baseline, "ruleset_id": "duel_v2"})
        with self.assertRaisesRegex(ValueError, "rules|terrain|revision"):
            module.validate_comparison(baseline, {**baseline, "map_revision": "ridge_v2"})


if __name__ == "__main__":
    unittest.main()
