"""Mocked production transport regressions; no credential lookup or network is allowed."""

import json
from unittest.mock import MagicMock, patch

from test_workflow import WorkflowFixture
import gate_runtime as gate


class GateFailureTests(WorkflowFixture):
    def test_api_moderation_spellings_are_normalized_without_assuming_approval(self):
        for value, expected in [("Approved", "COMPLETE"), ("MODERATION_STATE_APPROVED", "COMPLETE"), ("Rejected", "FAILED"), ("Reviewing", "MODERATION_PENDING"), ("UNKNOWN", "MODERATION_PENDING")]:
            with self.subTest(value=value):
                gate.process_operation(self.store, self.record, {"done": True, "response": {"assetId": "123", "moderationResult": {"moderationState": value}}})
                self.assertEqual(self.record["state"], expected)
                self.assertEqual(self.record["production_ready"], expected == "COMPLETE")

    def test_approved_moderation_without_asset_id_remains_pending(self):
        gate.process_operation(self.store, self.record, {"done": True, "response": {"moderationResult": {"moderationState": "Approved"}}})
        self.assertEqual(self.record["state"], "MODERATION_PENDING")
        self.assertFalse(self.record["production_ready"])

    def test_broken_pending_request_does_not_block_known_operation(self):
        from pathlib import Path

        Path(self.record["frozen"]).unlink()
        known = {**self.record, "id": "other", "state": "UPLOAD_OPERATION_KNOWN", "operation": "operations/other"}
        with patch("gate_runtime.poll") as poll:
            self.assertTrue(gate.resume_requests(self.store, [self.record, known]))
        poll.assert_called_once_with(self.store, known)
        self.assertIn("resume_error", self.store.get(self.record["id"]))
        self.assertEqual(self.store.get(self.record["id"])["state"], "WAITING_FOR_APPROVAL")

    def production_action(self, transport):
        self.record["demo"] = False
        self.record["binding"] = gate.binding(self.record)
        callbacks = {}

        def button(*args, **kwargs):
            callbacks[kwargs["text"]] = kwargs["command"]
            return MagicMock()

        root = MagicMock()
        root.mainloop.side_effect = lambda: callbacks["APPROVE & UPLOAD"]()
        client = MagicMock()
        client.__enter__.return_value = client
        client.request.side_effect = transport
        with patch("tkinter.Tk", return_value=root), patch("tkinter.Text"), patch("tkinter.ttk.Frame"), patch("tkinter.ttk.Label"), patch("tkinter.ttk.Notebook"), patch("tkinter.ttk.Button", side_effect=button), patch("PIL.ImageTk.PhotoImage"), patch("tkinter.messagebox.showerror"), patch("gate_runtime.require_installed", return_value=self.store.home), patch("gate_runtime.credential", return_value="offline-test-sentinel"), patch("gate_runtime.poll"), patch("httpx.Client", return_value=client):
            gate.approval_window(self.store, self.record)
        return client

    def test_exact_preview_bytes_and_metadata_are_submitted(self):
        response = MagicMock(is_success=True, status_code=200)
        response.json.return_value = {"path": "operations/offline-test"}
        client = self.production_action(lambda *args, **kwargs: response)
        args, kwargs = client.request.call_args
        self.assertEqual(args[0], "POST")
        self.assertEqual(kwargs["files"]["fileContent"][1], self.data)
        request = json.loads(kwargs["data"]["request"])
        self.assertEqual(request["displayName"], self.proposal["display_name"])
        self.assertEqual(request["creationContext"]["creator"], {"userId": "1"})
        record = self.store.get(self.record["id"])
        self.assertEqual(record["state"], "UPLOAD_OPERATION_KNOWN")
        self.assertEqual(record["operation"], "operations/offline-test")

    def test_transport_timeout_requires_recovery_without_retry(self):
        def timeout(*args, **kwargs):
            raise TimeoutError("offline simulated timeout")

        client = self.production_action(timeout)
        self.assertEqual(client.request.call_count, 1)
        self.assertEqual(self.store.get(self.record["id"])["state"], "RECOVERY_REQUIRED")

    def test_http_error_without_operation_never_retries(self):
        response = MagicMock(is_success=False, status_code=503)
        response.json.return_value = {"message": "offline service unavailable"}
        client = self.production_action(lambda *args, **kwargs: response)
        self.assertEqual(client.request.call_count, 1)
        self.assertEqual(self.store.get(self.record["id"])["state"], "RECOVERY_REQUIRED")

    def test_known_operation_cannot_open_approval(self):
        self.record["operation"] = "operations/existing"
        with patch("tkinter.Tk", side_effect=AssertionError("GUI opened")):
            with self.assertRaises(ValueError):
                gate.approval_window(self.store, self.record)

    def test_handoff_failure_preserves_operation(self):
        self.record.update(state="UPLOAD_OPERATION_KNOWN", operation="operations/persisted")
        with patch("gate_runtime.write_json", side_effect=OSError("offline disk failure")):
            self.store.save(self.record)
        self.assertEqual(self.store.get(self.record["id"])["operation"], "operations/persisted")
