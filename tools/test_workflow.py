"""Offline regressions for approval, crash recovery, licensing, and reviewer isolation."""

import copy
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch
import uuid

from PIL import Image

import assetctl
import gate_runtime as gate
import generate_credits
import reviewer
from asset_policy import license_status, validate_bytes
from workflow_common import ROOT, digest, read_json, write_json


class WorkflowFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.project = self.root / "project"
        self.project.mkdir()
        buffer = io.BytesIO()
        Image.new("RGBA", (32, 32), (255, 100, 0, 150)).save(buffer, format="PNG")
        self.data = buffer.getvalue()
        self.source = self.project / "asset.png"
        self.source.write_bytes(self.data)
        self.proposal = {"id": str(uuid.uuid4()), "project_root": str(self.project), "file": str(self.source),
                         "production_file": "asset.png", "sha256": digest(self.data), "asset_type": "Decal", "creator": "user:1",
                         "display_name": "Offline test", "description": "Fixture", "target_asset_id": None, "model_evidence": None,
                         "demo": True, "provenance": {"author": "Test", "provider": "project", "source_id": "test",
                         "source_url": "local:test", "license": "Project-Owned", "license_url": "local:test", "attribution_required": False, "modifications": []}}
        self.request = self.project / "request.json"
        write_json(self.request, self.proposal)
        self.store = gate.Store(self.root / "gate")
        self.record = gate.receive(self.store, self.request)

    def tearDown(self):
        self.store.db.close()
        self.temp.cleanup()


class WorkflowTests(WorkflowFixture):
    def test_claude_environment_removes_credentials(self):
        parent = {"ANTHROPIC_API_KEY": "sentinel", "ANTHROPIC_AUTH_TOKEN": "sentinel", "PATH": "keep"}
        self.assertEqual(reviewer.child_environment(parent), {"PATH": "keep"})
        self.assertIn("ANTHROPIC_API_KEY", parent)

    def test_claude_invocation_has_no_tools_and_uses_stdin(self):
        help_response = MagicMock(returncode=0, stdout="--tools --strict-mcp-config --safe-mode --restricted --output-format --system-prompt --effort --verbose")
        review_response = MagicMock(returncode=0, stdout=json.dumps({"type": "result", "subtype": "success", "result": "review"}))
        with patch("reviewer.shutil.which", return_value="claude.exe"), patch("reviewer.subprocess.run", return_value=help_response), patch("reviewer.run_claude", return_value=review_response) as run:
            reviewer.claude("bounded packet", 10)
        args, kwargs = run.call_args
        self.assertEqual(args[0][:2], ["claude.exe", "-p"])
        self.assertNotIn("--bare", args[0])
        self.assertEqual(args[0][args[0].index("--tools") + 1], "")
        self.assertEqual(kwargs["input"], "bounded packet")
        self.assertNotEqual(Path(kwargs["cwd"]), ROOT)

    def test_unknown_and_restricted_license_rejected(self):
        for name in (None, "unknown", "CC-BY-NC-4.0", "CC-BY-ND-4.0", "proprietary"):
            self.assertEqual(license_status(name), "blocked")
        for name in ("CC-BY-SA-4.0", "MPL-2.0", "custom"):
            self.assertEqual(license_status(name), "manual_review")
        changed = copy.deepcopy(self.proposal)
        changed["provenance"]["license"] = "unknown"
        with self.assertRaises(ValueError):
            validate_bytes(self.data, "asset.png", "Decal", changed)

    def test_claude_timeout_reports_generation_and_terminates(self):
        script = "import json,time; print(json.dumps({'type':'system','subtype':'thinking_tokens'}),flush=True); time.sleep(10)"
        updates = []
        with self.assertRaisesRegex(TimeoutError, "last phase: generating"):
            reviewer.run_claude([sys.executable, "-c", script], input="packet", cwd=self.root, env=reviewer.child_environment(), timeout=0.5, progress=updates.append)
        self.assertEqual(updates[-1]["phase"], "generating")

    def test_claude_stream_status_excludes_review_and_reasoning(self):
        events = [{'type':'system','subtype':'init','model':'test-model'}, {'type':'system','subtype':'thinking_tokens','text':'private reasoning'}, {'type':'rate_limit_event','rate_limit_info':{'status':'allowed','private':'omitted'}}]
        status = reviewer.stream_status("\n".join(json.dumps(event) for event in events))
        self.assertEqual(status, {'model':'test-model','phase':'generating','rate_limit_status':'allowed'})

    def test_invalid_bytes_and_update_fail(self):
        with self.assertRaises(ValueError):
            validate_bytes(b"not png", "asset.png", "Unknown")
        with self.assertRaises(ValueError):
            validate_bytes(self.data, "asset.png", "Decal", {**self.proposal, "target_asset_id": "123"})

    def test_binding_invalidates_all_metadata_changes(self):
        for name in ("sha256", "asset_type", "creator", "display_name", "description", "target_asset_id"):
            changed = copy.deepcopy(self.record)
            changed[name] = "different"
            with self.assertRaises(ValueError):
                gate.verified_bytes(changed)

    def test_frozen_file_tampering_invalidates(self):
        Path(self.record["frozen"]).write_bytes(b"changed")
        with self.assertRaises(ValueError):
            gate.verified_bytes(self.record)

    def test_source_change_does_not_change_frozen_upload(self):
        self.source.write_bytes(b"new source")
        self.assertEqual(gate.verified_bytes(self.record), self.data)
        self.proposal["id"] = str(uuid.uuid4())
        write_json(self.request, self.proposal)
        with self.assertRaises(ValueError):
            gate.receive(self.store, self.request)

    def test_duplicate_receive_reuses_request(self):
        self.assertEqual(gate.receive(self.store, self.request)["id"], self.record["id"])
        self.assertEqual(len(self.store.all()), 1)
        self.proposal["display_name"] = "Mutated"
        write_json(self.request, self.proposal)
        with self.assertRaises(ValueError):
            gate.receive(self.store, self.request)

    def gui_action(self, action):
        callbacks = {}

        def button(*args, **kwargs):
            callbacks[kwargs["text"]] = kwargs["command"]
            return MagicMock()

        window = MagicMock()
        if action == "approve":
            window.mainloop.side_effect = lambda: callbacks["DEMO APPROVE — NO UPLOAD"]()
        elif action == "deny":
            window.mainloop.side_effect = lambda: callbacks["DENY"]()
        with patch("tkinter.Tk", return_value=window), patch("tkinter.Text"), patch("tkinter.ttk.Frame"), patch("tkinter.ttk.Label"), patch("tkinter.ttk.Notebook"), patch("tkinter.ttk.Button", side_effect=button), patch("PIL.ImageTk.PhotoImage"), patch("gate_runtime.credential", side_effect=AssertionError("Credential accessed")) as credential, patch("httpx.Client", side_effect=AssertionError("Network client created")) as client:
            gate.approval_window(self.store, self.record)
            credential.assert_not_called()
            client.assert_not_called()

    def test_demo_approve_has_zero_network_writes(self):
        self.gui_action("approve")
        record = self.store.get(self.record["id"])
        self.assertEqual(record["state"], "DEMO_COMPLETE")
        self.assertFalse(record["production_ready"])

    def test_production_deny_has_zero_network_writes(self):
        self.record["demo"] = False
        self.record["binding"] = gate.binding(self.record)
        self.gui_action("deny")
        self.assertEqual(self.store.get(self.record["id"])["state"], "DENIED")

    def test_popup_close_and_resume_preserves_hash(self):
        self.gui_action("close")
        self.store.recover()
        record = self.store.get(self.record["id"])
        self.assertEqual(record["state"], "WAITING_FOR_APPROVAL")
        self.assertEqual(digest(gate.verified_bytes(record)), self.proposal["sha256"])

    def test_uncertain_write_never_retries(self):
        self.record["state"] = "UPLOAD_STARTING"
        self.store.save(self.record)
        with patch("httpx.Client", side_effect=AssertionError("Network attempted")):
            self.store.recover()
        self.assertEqual(self.store.get(self.record["id"])["state"], "RECOVERY_REQUIRED")

    def test_known_operation_survives_recovery(self):
        self.record.update(state="UPLOAD_OPERATION_KNOWN", operation="operations/abc")
        self.store.save(self.record)
        self.store.recover()
        self.assertEqual(self.store.get(self.record["id"])["operation"], "operations/abc")

    def test_moderation_is_required_for_complete(self):
        for state, expected in (("UNKNOWN", "MODERATION_PENDING"), ("MODERATION_STATE_REJECTED", "FAILED"), ("MODERATION_STATE_APPROVED", "COMPLETE")):
            gate.process_operation(self.store, self.record, {"done": True, "response": {"assetId": "123", "moderationResult": {"moderationState": state}}})
            self.assertEqual(self.record["state"], expected)

    def test_crash_resilient_sqlite(self):
        worker = self.root / "crash.py"
        worker.write_text("import sys, os\nfrom pathlib import Path\nsys.path.insert(0, sys.argv[1])\nfrom gate_runtime import Store\ns=Store(Path(sys.argv[2]))\nr=s.all()[0]\nr['state']='UPLOAD_STARTING'\ns.save(r)\nos._exit(17)\n")
        result = subprocess.run([sys.executable, str(worker), str(ROOT / "tools"), str(self.store.home)])
        self.assertEqual(result.returncode, 17)
        self.store.recover()
        self.assertEqual(self.store.get(self.record["id"])["state"], "RECOVERY_REQUIRED")
        self.assertEqual(self.store.db.execute("PRAGMA integrity_check").fetchone()[0], "ok")

    def test_repository_runtime_cannot_read_credential(self):
        with patch("keyring.get_password", side_effect=AssertionError("Credential accessed")):
            with self.assertRaises(RuntimeError):
                gate.credential()

    def test_attribution_is_deterministic_and_includes_license(self):
        record = {**self.proposal["provenance"], "provider": "Iconify", "license": "MIT", "license_text": "Copyright Fixture\nPermission fixture", "attribution_required": True}
        write_json(self.project / "manifests/external-assets.json", {"assets": {"asset.png": record}})
        write_json(self.project / "manifests/assets.json", {"assets": {}})
        with patch.object(generate_credits, "ROOT", self.project):
            generate_credits.generate()
            first_manifest = (self.project / "manifests/attribution.json").read_bytes()
            first_notices = (self.project / "THIRD_PARTY_NOTICES.md").read_bytes()
            generate_credits.generate()
            self.assertEqual(first_manifest, (self.project / "manifests/attribution.json").read_bytes())
            self.assertEqual(first_notices, (self.project / "THIRD_PARTY_NOTICES.md").read_bytes())
        self.assertIn(b"Copyright Fixture", first_notices)

    def test_reconcile_applies_once(self):
        record = {**self.record, "demo": False, "state": "COMPLETE", "moderation_state": "MODERATION_STATE_APPROVED", "asset_id": "42", "production_ready": True}
        write_json(self.project / ".asset-inbox" / (record["id"] + ".json"), record)
        write_json(self.project / "manifests/assets.json", {"assets": {}, "requests": {record["id"]: {"sha256": record["sha256"], "sequence": 0, "production_file": "asset.png", "demo": False}}})
        with patch.object(assetctl, "ROOT", self.project), patch.object(assetctl, "project_path", side_effect=lambda name: self.project / name):
            assetctl.reconcile()
            first = (self.project / "manifests/assets.json").read_bytes()
            assetctl.reconcile()
            self.assertEqual(first, (self.project / "manifests/assets.json").read_bytes())
        self.assertEqual(read_json(self.project / "manifests/assets.json")["assets"]["asset.png"]["asset_id"], "42")


class AnimationGateTests(WorkflowFixture):
    def setUp(self):
        super().setUp()
        self.rbxm = b"<roblox!\x89\xff\r\n\x1a\n\x00\x00" + b"\x00" * 16 + b"INST" + b"\x00" * 16 + b"END\x00" + b"\x00" * 12 + b"</roblox>"
        self.clip = self.project / "assets/animations/locomotion/LocoTest.rbxm"
        self.clip.parent.mkdir(parents=True)
        self.clip.write_bytes(self.rbxm)
        review = self.project / ".review/animations"
        review.mkdir(parents=True)
        (review / "LocoTest-sheet.png").write_bytes(self.data)
        (review / "studio.png").write_bytes(self.data)
        blend = self.project / "assets/source/blender/test.blend"
        blend.parent.mkdir(parents=True)
        blend.write_bytes(b"BLENDER")
        self.evidence = {"source_blend": "assets/source/blender/test.blend", "sheet": ".review/animations/LocoTest-sheet.png",
                         "studio": ".review/animations/studio.png", "statistics": {"keyframes": 44, "duration": 0.7, "looped": True, "joints": 16}}
        self.animation = {**self.proposal, "id": str(uuid.uuid4()), "file": str(self.clip), "production_file": "assets/animations/locomotion/LocoTest.rbxm",
                          "sha256": digest(self.rbxm), "asset_type": "Animation", "model_evidence": self.evidence}

    def test_animation_validates_with_evidence(self):
        result = validate_bytes(self.rbxm, "LocoTest.rbxm", "Animation", self.animation)
        self.assertEqual(result["content_type"], "model/x-rbxm")
        self.assertEqual(result["model_statistics"]["keyframes"], 44)

    def test_animation_rejects_xml_bad_header_updates_and_missing_evidence(self):
        with self.assertRaises(ValueError):
            validate_bytes(self.rbxm, "LocoTest.rbxmx", "Animation", self.animation)
        with self.assertRaises(ValueError):
            validate_bytes(b"<roblox xmlns=\"x\">" + b"\x00" * 64, "LocoTest.rbxm", "Animation", self.animation)
        with self.assertRaises(ValueError):
            validate_bytes(self.rbxm[:-30], "LocoTest.rbxm", "Animation", self.animation)
        with self.assertRaises(ValueError):
            validate_bytes(self.rbxm, "LocoTest.rbxm", "Animation", {**self.animation, "target_asset_id": "5"})
        for missing in ("sheet", "studio", "statistics", "source_blend"):
            evidence = dict(self.evidence)
            evidence.pop(missing)
            with self.assertRaises(ValueError):
                validate_bytes(self.rbxm, "LocoTest.rbxm", "Animation", {**self.animation, "model_evidence": evidence})
        with self.assertRaises(ValueError):
            validate_bytes(self.rbxm, "LocoTest.rbxm", "Animation", {**self.animation, "model_evidence": {**self.evidence, "statistics": {"keyframes": 1, "duration": 0.7, "looped": True, "joints": 16}}})

    def test_animation_receive_freezes_review_evidence(self):
        request = self.project / "animation.json"
        write_json(request, self.animation)
        record = gate.receive(self.store, request)
        self.assertEqual(sorted(record["preview_files"]), ["sheet", "studio"])
        self.assertEqual(record["validation"]["content_type"], "model/x-rbxm")
        gate.verified_bytes(record)
        Path(record["preview_files"]["sheet"]).write_bytes(b"tampered")
        with self.assertRaises(ValueError):
            gate.verified_bytes(record)


if __name__ == "__main__":
    unittest.main()
