"""Offline regressions for missing evidence, inconsistent verdicts and stale visual acceptance."""

import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import visual_review as visual
from workflow_common import write_json


class VisualReviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        for name in ["src/UI.luau", "before.jpg", "after.jpg", *visual.POLICY]:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture: " + name)
        self.packet = {
            "schema_version": 1, "purpose": "milestone", "scope": "Buttons", "requirement": "Match the family",
            "coverage_limits": "Idle fixture only; no device claims", "sources": ["src/UI.luau"],
            "capture_sources": {"src/UI.luau": visual.file_hash(self.root / "src/UI.luau")},
            "required_cases": ["desktop"],
            "cases": [{"id": "desktop", "device": "Desktop", "state": "Idle", "before": "before.jpg", "after": "after.jpg"}],
            "families": [{"id": "buttons", "targets": "Join", "peers": "Shop, Backpack", "target_names": ["Join"], "peer_names": ["Shop", "Backpack"], "relationship": "Filled actions", "reference": "desktop:before"}],
        }
        self.packet_path = self.root / "packet.json"
        write_json(self.packet_path, self.packet)
        self.contract = visual.prepare(self.packet_path, self.root)
        self.result = {"verdict": "PASS", "findings": [], "checks": [
            {"case": "desktop", "category": category, "status": "pass", "observation": f"Observed candidate {category} detail",
             "comparison": f"Compared {category} with named peers", "evidence": ["desktop:before", "desktop:after"], "family": "buttons", "compared_peers": ["Shop", "Backpack"]}
            for category in visual.CHECKS
        ]}

    def validate(self, result):
        return visual.validate_result(json.dumps(result), self.contract)

    def save_review(self):
        path = self.root / ".review/final"
        write_json(path / "visual-contract.json", self.contract)
        write_json(path / "review.json", self.result)
        write_json(path / "state.json", {
            "state": "ADVISORY_PASS",
            "visual_contract_sha256": visual.file_hash(path / "visual-contract.json"),
            "review_sha256": visual.file_hash(path / "review.json"),
        })
        return path

    def test_complete_review_is_advisory_only(self):
        self.assertEqual(visual.check_review(self.save_review(), root=self.root)["verdict"], "PASS")

    def test_missing_peer_context_is_rejected(self):
        for mutation in (lambda p: p.pop("families"), lambda p: p["families"][0].pop("peers")):
            packet = copy.deepcopy(self.packet)
            mutation(packet)
            write_json(self.packet_path, packet)
            with self.assertRaises(ValueError):
                visual.prepare(self.packet_path, self.root)

    def test_missing_required_case_is_rejected(self):
        self.packet["required_cases"].append("phone")
        write_json(self.packet_path, self.packet)
        with self.assertRaises(ValueError):
            visual.prepare(self.packet_path, self.root)

    def test_old_capture_cannot_be_bound_to_new_source(self):
        (self.root / "src/UI.luau").write_text("new source after capture")
        with self.assertRaisesRegex(ValueError, "Capture does not match"):
            visual.prepare(self.packet_path, self.root)

    def test_candidate_cannot_serve_as_its_own_before(self):
        self.packet["cases"][0]["before"] = "after.jpg"
        write_json(self.packet_path, self.packet)
        with self.assertRaisesRegex(ValueError, "distinct captures"):
            visual.prepare(self.packet_path, self.root)

    def test_target_cannot_be_its_own_peer(self):
        self.packet["families"][0]["peer_names"] = ["Join", "Shop"]
        write_json(self.packet_path, self.packet)
        with self.assertRaisesRegex(ValueError, "own peer"):
            visual.prepare(self.packet_path, self.root)

    def test_family_cannot_omit_named_peer(self):
        self.result["checks"][0]["compared_peers"] = ["Shop"]
        with self.assertRaisesRegex(ValueError, "every named peer"):
            self.validate(self.result)

    def test_duplicate_boilerplate_cannot_stand_in_for_an_audit(self):
        self.result["checks"][1].update(observation=self.result["checks"][0]["observation"], comparison=self.result["checks"][0]["comparison"])
        with self.assertRaisesRegex(ValueError, "boilerplate"):
            self.validate(self.result)

    def test_each_named_family_must_be_reviewed(self):
        self.contract["manifest"]["families"].append({**self.packet["families"][0], "id": "brand"})
        with self.assertRaisesRegex(ValueError, "omitted"):
            self.validate(self.result)

    def test_plain_approved_is_not_a_visual_review(self):
        with self.assertRaises(ValueError):
            visual.validate_result("VERDICT: APPROVED\nBLOCKING None\nIMPORTANT None\nOPTIONAL None\nEVIDENCE Looks good", self.contract)

    def test_blank_missing_duplicate_and_invented_checks_fail(self):
        mutations = [lambda r: r["checks"].pop(), lambda r: r["checks"].append(r["checks"][0]),
                     lambda r: r["checks"][0].update(comparison=""),
                     lambda r: r["checks"][0].update(evidence=["imaginary:after"]),
                     lambda r: r["checks"][0].update(evidence=["desktop:before"]),
                     lambda r: r["checks"][0].update(family="invented")]
        for mutate in mutations:
            result = copy.deepcopy(self.result)
            mutate(result)
            with self.assertRaises(ValueError):
                self.validate(result)

    def test_pass_with_minor_defect_or_unknown_state_fails(self):
        for category in visual.CHECKS:
            for status in ("fail", "unverified"):
                result = copy.deepcopy(self.result)
                row = next(r for r in result["checks"] if r["category"] == category)
                row["status"] = status
                with self.assertRaises(ValueError):
                    self.validate(result)
        result = copy.deepcopy(self.result)
        result["findings"] = [{"id": "F1", "case": "desktop", "category": "family", "detail": "Minor mismatch"}]
        with self.assertRaises(ValueError):
            self.validate(result)

    def test_changes_required_is_valid_but_cannot_pass_readiness(self):
        self.result["verdict"] = "CHANGES_REQUIRED"
        self.result["checks"][0]["status"] = "fail"
        self.assertEqual(self.validate(self.result)["verdict"], "CHANGES_REQUIRED")
        with self.assertRaises(ValueError):
            visual.check_review(self.save_review(), root=self.root)

    def test_source_capture_and_policy_changes_invalidate_review(self):
        for name in ("src/UI.luau", "after.jpg", "docs/ART_STYLE.md"):
            path = self.root / name
            original = path.read_text()
            directory = self.save_review()
            path.write_text(original + "edited")
            with self.assertRaises(ValueError):
                visual.check_review(directory, root=self.root)
            path.write_text(original)

    def test_new_runtime_file_outside_selected_sources_invalidates_review(self):
        directory = self.save_review()
        (self.root / "src/OtherScreen.luau").write_text("new visual dependency")
        with self.assertRaises(ValueError):
            visual.check_review(directory, root=self.root)

    def test_result_or_contract_edits_invalidate_review(self):
        for name in ("review.json", "visual-contract.json"):
            directory = self.save_review()
            with (directory / name).open("a") as stream:
                stream.write(" ")
            with self.assertRaises(ValueError):
                visual.check_review(directory, root=self.root)

    def test_legacy_and_interrupted_states_are_blocked(self):
        directory = self.save_review()
        for state in ("COMPLETE", "RUNNING", "FAILED", "PREPARED"):
            write_json(directory / "state.json", {"state": state})
            with self.assertRaises(ValueError):
                visual.check_review(directory, root=self.root)

    def test_milestone_cannot_be_promoted_to_release(self):
        with self.assertRaisesRegex(ValueError, "milestone"):
            visual.check_review(self.save_review(), release=True, root=self.root)

    def test_release_requires_acceptance_bound_to_result_and_contract(self):
        self.contract["manifest"]["purpose"] = "release"
        directory = self.save_review()
        with self.assertRaisesRegex(ValueError, "sign-off"):
            visual.check_review(directory, release=True, root=self.root)
        acceptance = self.root / "acceptance.json"
        owner = {"decision": "ACCEPT", "statement": "Offline owner fixture", "review_sha256": visual.file_hash(directory / "review.json"),
                 "contract_sha256": visual.file_hash(directory / "visual-contract.json")}
        write_json(acceptance, owner)
        visual.check_review(directory, release=True, acceptance=acceptance, root=self.root)
        owner["review_sha256"] = "stale"
        write_json(acceptance, owner)
        with self.assertRaises(ValueError):
            visual.check_review(directory, release=True, acceptance=acceptance, root=self.root)

    def test_gemini_loose_packet_fails_before_any_api_call(self):
        import reviewer
        with patch("sys.argv", ["reviewer.py", "gemini", "--task", "Looks good?"]), patch("reviewer.gemini") as api:
            with self.assertRaises(SystemExit):
                reviewer.main()
            api.assert_not_called()


if __name__ == "__main__":
    unittest.main()
