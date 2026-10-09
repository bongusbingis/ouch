"""Native Tk demo callback smoke tests; hardcoded synthetic records and network traps only."""

import io
import json
from pathlib import Path
import tempfile
import tkinter as tk
from tkinter import ttk
from unittest.mock import patch
import uuid

from PIL import Image
import gate_runtime as gate
from workflow_common import ROOT, digest, write_json


def main():
    results = []
    with tempfile.TemporaryDirectory(prefix="gate-demo-gui-") as directory:
        project = Path(directory) / "project"
        project.mkdir()
        buffer = io.BytesIO()
        Image.new("RGBA", (64, 64), (255, 204, 40, 150)).save(buffer, format="PNG")
        source = project / "fixture.png"
        source.write_bytes(buffer.getvalue())
        store = gate.Store(Path(directory) / "gate")
        try:
            for action, expected in (("approve", "DEMO_COMPLETE"), ("deny", "DENIED"), ("close", "WAITING_FOR_APPROVAL")):
                proposal = {"id": str(uuid.uuid4()), "project_root": str(project), "file": str(source), "production_file": "fixture.png", "sha256": digest(source.read_bytes()),
                    "asset_type": "Decal", "creator": "user:1", "display_name": "Native DEMO test", "description": "No Roblox writes", "demo": True,
                    "provenance": {"author": "Test", "provider": "project", "source_id": "fixture", "source_url": "local:fixture", "license": "Project-Owned", "license_url": "local:fixture", "attribution_required": False, "modifications": []}}
                request = project / "request.json"
                write_json(request, proposal)
                record = gate.receive(store, request)
                real_tk = tk.Tk
                observed = {}

                def test_window():
                    window = real_tk()

                    def decide():
                        observed["mapped"] = bool(window.winfo_ismapped())
                        observed["focused"] = window.focus_displayof() is not None
                        observed["title"] = window.title()
                        if record["demo"] is not True:
                            raise RuntimeError("Synthetic GUI test cannot approve production")
                        if action == "close":
                            window.destroy()
                            return

                        def visit(widget):
                            for child in widget.winfo_children():
                                if isinstance(child, ttk.Button) and child.cget("text") == ("DEMO APPROVE — NO UPLOAD" if action == "approve" else "DENY"):
                                    child.invoke()
                                    return True
                                if visit(child):
                                    return True
                            return False

                        if not visit(window):
                            window.destroy()
                            raise RuntimeError("Expected demo button not found")

                    window.after(750, decide)
                    return window

                with patch("tkinter.Tk", side_effect=test_window), patch("gate_runtime.credential", side_effect=AssertionError("Credential access forbidden")), patch("httpx.Client", side_effect=AssertionError("Network forbidden")):
                    gate.approval_window(store, record)
                saved = store.get(record["id"])
                if saved["state"] != expected or not observed.get("mapped") or not observed.get("focused"):
                    raise RuntimeError("Native GUI smoke test failed")
                results.append({"action": action, "state": saved["state"], "mapped_window": observed["mapped"], "focused_window": observed["focused"], "network_writes": 0})
        finally:
            store.db.close()
    write_json(ROOT / ".review/native-gui-tests.json", results)
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
