"""Offline checks for the live-config source parser and its known unresolved key."""

import subprocess
import sys
import unittest

import liveconfig


class LiveConfigSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registry = liveconfig.parse_registry(liveconfig.REGISTRY.read_text(encoding="utf-8"))
        cls.by_key = {entry["key"]: entry for entry in cls.registry}

    def test_paths_resolve_from_repository_root(self):
        self.assertEqual(liveconfig.REGISTRY, liveconfig.REPO_ROOT / "src/config/LiveConfig.luau")
        self.assertTrue(liveconfig.REGISTRY.is_file())
        self.assertEqual(
            liveconfig.MODULE_SOURCES["Progression"],
            liveconfig.REPO_ROOT / "src/config/Progression/Data.luau",
        )
        self.assertTrue(liveconfig.MODULE_SOURCES["Progression"].is_file())

    def test_all_progression_baked_values_keep_integer_bounds(self):
        expected = {
            "ProgressionXP.MatchComplete": (25, 1, 200),
            "ProgressionXP.Win": (100, 1, 500),
            "ProgressionXP.Elim": (20, 0, 100),
            "ProgressionXP.Catch": (15, 0, 100),
            "ProgressionBonks.MatchComplete": (75, 1, 400),
            "ProgressionBonks.Win": (100, 1, 500),
            "ProgressionBonks.Elim": (10, 0, 100),
            "ProgressionBonks.Catch": (15, 0, 100),
        }
        source = liveconfig.MODULE_SOURCES["Progression"].read_text(encoding="utf-8")
        clean = liveconfig.strip_noise(source)
        rows = [entry for entry in self.registry if entry["key"].startswith("Progression.")]
        self.assertEqual(len(rows), len(expected))
        for suffix, (value, minimum, maximum) in expected.items():
            key = "Progression." + suffix
            row = self.by_key[key]
            self.assertTrue(row["integer"], key)
            self.assertEqual((row["minimum"], row["maximum"]), (minimum, maximum), key)
            literal = liveconfig.read_leaf(clean, source, suffix.split("."), key)
            self.assertEqual(liveconfig.coerce(row, literal), value, key)

    def test_other_baked_values_and_symbolic_bound(self):
        combat_key = "Combat.Dodgeball.ThrowSpeed"
        source = liveconfig.MODULE_SOURCES["Combat"].read_text(encoding="utf-8")
        literal = liveconfig.read_leaf(
            liveconfig.strip_noise(source), source, ["Dodgeball", "ThrowSpeed"], combat_key
        )
        self.assertEqual(liveconfig.coerce(self.by_key[combat_key], literal), 140)
        self.assertEqual(self.by_key["Matchmaking.MatchTargetPlayers"]["maximum"], 20)

    def test_malformed_metadata_and_baked_integer_fail_clearly(self):
        for field, value, expected in (
            ("Integer", "maybe", "Integer must be true or false"),
            ("Minimum", "unknown", "Minimum has unsupported numeric bound"),
            ("Maximum", "GameModes.Unknown", "Progression.X.Maximum: expected exactly one 'Unknown ='"),
        ):
            row = '{ Key = "Progression.X", Type = "number", ' + field + " = " + value + " }"
            with self.subTest(field=field, value=value), self.assertRaises(liveconfig.ConfigError) as caught:
                liveconfig.parse_registry(row)
            self.assertIn(expected, str(caught.exception))
        row = self.by_key["Progression.ProgressionXP.MatchComplete"]
        with self.assertRaisesRegex(liveconfig.ConfigError, "must be an integer"):
            liveconfig.coerce(row, "1.5")
        with self.assertRaisesRegex(liveconfig.ConfigError, "below its declared minimum"):
            liveconfig.coerce(row, "0")
        with self.assertRaisesRegex(liveconfig.ConfigError, "above its declared maximum"):
            liveconfig.coerce(row, "201")

    def test_dry_run_stops_at_existing_matchmaking_leaf(self):
        expected = (
            "Matchmaking.MatchTargetPlayers: expected exactly one "
            "'MatchTargetPlayers =' in the returned table, found 0"
        )
        with self.assertRaises(liveconfig.ConfigError) as caught:
            liveconfig.collect_entries()
        self.assertEqual(str(caught.exception), expected)
        completed = subprocess.run(
            [sys.executable, str(liveconfig.REPO_ROOT / "tools/liveconfig.py"), "--dry-run"],
            cwd=liveconfig.REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(completed.stderr.strip(), "error: " + expected)
        self.assertEqual(completed.stdout, "")


if __name__ == "__main__":
    unittest.main()
