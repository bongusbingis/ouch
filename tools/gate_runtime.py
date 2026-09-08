"""Installed-only upload authority. Approval is a GUI event; uncertain writes never retry."""

import argparse
import io
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import uuid

from asset_policy import MAX_BYTES, REVIEW_VIEWS, validate_bytes
from workflow_common import atomic_write, digest, file_lock, read_json, write_json


def installed_home():
    return Path(os.environ["LOCALAPPDATA"]) / "RobloxAssetGate"


def require_installed():
    home = installed_home().resolve()
    if Path(__file__).resolve() != home / "app" / "gate_runtime.py":
        raise RuntimeError("Upload runtime may run only from the installed external gate")
    return home


class Store:
    def __init__(self, home):
        self.home = Path(home)
        for name in ("frozen", "previews", "results", "logs"):
            (self.home / name).mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(self.home / "state.sqlite3")
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        self.db.execute("CREATE TABLE IF NOT EXISTS requests (id TEXT PRIMARY KEY, record TEXT NOT NULL)")
        self.db.commit()

    def get(self, request_id):
        row = self.db.execute("SELECT record FROM requests WHERE id=?", (request_id,)).fetchone()
        if not row:
            raise ValueError("Unknown request ID")
        return json.loads(row[0])

    def all(self):
        return [json.loads(row[0]) for row in self.db.execute("SELECT record FROM requests ORDER BY id")]

    def save(self, record):
        record["sequence"] = record.get("sequence", 0) + 1
        with self.db:
            self.db.execute("INSERT INTO requests VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET record=excluded.record", (record["id"], json.dumps(record)))
        self.handoff(record)

    def handoff(self, record):
        public = {key: value for key, value in record.items() if key not in {"inbox", "frozen", "preview_files"}}
        for folder in (self.home / "results", Path(record["inbox"])):
            try:
                write_json(folder / (record["id"] + ".json"), public)
            except OSError:
                pass

    def recover(self):
        for record in self.all():
            if record["state"] == "UPLOAD_STARTING":
                record["state"] = "RECOVERY_REQUIRED"
                record["error"] = "Write may have been transmitted without a durable operation ID. Do not resubmit. Inspect Roblox manually."
                self.save(record)
            elif record["state"] == "APPROVED":
                record["state"] = "WAITING_FOR_APPROVAL"
                self.save(record)
            else:
                self.handoff(record)


def binding(record):
    fields = ("sha256", "asset_type", "creator", "display_name", "description", "target_asset_id", "provenance", "model_evidence", "demo", "preview_hashes")
    return digest(json.dumps({key: record.get(key) for key in fields}, sort_keys=True, separators=(",", ":")).encode())


def receive(store, request_file):
    proposal = read_json(request_file)
    request_id = str(uuid.UUID(proposal["id"]))
    if any(record["id"] == request_id for record in store.all()):
        existing = store.get(request_id)
        if existing["proposal_sha256"] != digest(Path(request_file).read_bytes()):
            raise ValueError("Existing request ID has different proposal bytes")
        return existing
    project = Path(proposal["project_root"]).resolve()
    source = Path(proposal["file"]).resolve()
    if not source.is_relative_to(project):
        raise ValueError("Source outside project")
    if source.stat().st_size > MAX_BYTES:
        raise ValueError("Asset exceeds supported size")
    data = source.read_bytes()
    if digest(data) != proposal["sha256"]:
        raise ValueError("Proposed asset changed; prepare a new request")
    validation = validate_bytes(data, source.name, proposal["asset_type"], proposal)
    frozen = store.home / "frozen" / (request_id + source.suffix.lower())
    atomic_write(frozen, data)
    previews, hashes = {}, {}
    if proposal["asset_type"] == "Model":
        blend = (project / proposal["model_evidence"]["source_blend"]).resolve()
        if not blend.is_relative_to(project) or blend.suffix.lower() != ".blend" or not blend.is_file():
            raise ValueError("Saved project .blend source required")
        for view in REVIEW_VIEWS:
            evidence = (project / proposal["model_evidence"][view]).resolve()
            if not evidence.is_relative_to(project):
                raise ValueError("Review evidence outside project")
            preview_data = evidence.read_bytes()
            validate_bytes(preview_data, evidence.name, "Image")
            target = store.home / "previews" / (request_id + "-" + view + evidence.suffix.lower())
            atomic_write(target, preview_data)
            previews[view], hashes[view] = str(target), digest(preview_data)
    record = {key: proposal.get(key) for key in ("asset_type", "creator", "display_name", "description", "target_asset_id", "provenance", "model_evidence", "production_file", "source", "demo")}
    if not isinstance(record["demo"], bool):
        raise ValueError("Explicit demo boolean required")
    record.update(id=request_id, sha256=digest(data), filename=source.name, frozen=str(frozen), validation=validation,
                  preview_files=previews, preview_hashes=hashes, state="WAITING_FOR_APPROVAL", sequence=0,
                  inbox=str(project / ".asset-inbox"), proposal_sha256=digest(Path(request_file).read_bytes()),
                  moderation_state="NOT_SUBMITTED", production_ready=False)
    record["binding"] = binding(record)
    store.save(record)
    return record


def verified_bytes(record):
    data = Path(record["frozen"]).read_bytes()
    if digest(data) != record["sha256"] or binding(record) != record["binding"]:
        raise ValueError("Frozen bytes or metadata changed; approval invalidated")
    for view, path in record["preview_files"].items():
        if digest(Path(path).read_bytes()) != record["preview_hashes"][view]:
            raise ValueError("Review evidence changed; approval invalidated")
    validate_bytes(data, record["filename"], record["asset_type"], record)
    return data


def credential():
    require_installed()
    import keyring

    value = keyring.get_password("roblox-asset-gate-opencloud", "api-key")
    if not value:
        raise RuntimeError("Gate credential missing in Windows Credential Manager")
    return value


def process_operation(store, record, response):
    record["response"] = response
    if not response.get("done"):
        record["state"] = "UPLOAD_OPERATION_KNOWN"
    elif response.get("error"):
        record["state"] = "FAILED"
    else:
        asset = response.get("response", {})
        record["asset_id"] = str(asset.get("assetId", ""))
        record["revision"] = asset.get("revisionId")
        moderation = asset.get("moderationResult", {}).get("moderationState", "UNKNOWN")
        record["moderation_state"] = moderation
        record["state"] = "COMPLETE" if moderation == "MODERATION_STATE_APPROVED" and record["asset_id"] else "MODERATION_PENDING"
        if "REJECTED" in moderation:
            record["state"] = "FAILED"
        record["production_ready"] = record["state"] == "COMPLETE"
    store.save(record)


def poll(store, record):
    require_installed()
    import httpx

    operation = record.get("operation")
    if record["demo"] or not operation or not re.fullmatch(r"operations/[A-Za-z0-9_-]+", operation):
        raise ValueError("Valid known production operation required for polling")
    try:
        with httpx.Client(timeout=30, trust_env=False, follow_redirects=False) as client:
            response = client.get("https://apis.roblox.com/assets/v1/" + operation, headers={"x-api-key": credential()})
            response.raise_for_status()
            process_operation(store, record, response.json())
    except Exception as exc:
        record["poll_error"] = type(exc).__name__ + "; operation retained; resume to poll again"
        store.save(record)


def approval_window(store, record):
    import tkinter as tk
    from tkinter import ttk, messagebox
    from PIL import Image, ImageDraw, ImageTk

    if record["state"] != "WAITING_FOR_APPROVAL" or record.get("operation"):
        raise ValueError("Only an unsubmitted pending request can open approval")
    data = verified_bytes(record)
    root = tk.Tk()
    root.title(("DEMO — ZERO ROBLOX WRITES | " if record["demo"] else "HUMAN APPROVAL | ") + record["id"])
    root.geometry("1050x850")
    root.minsize(760, 600)
    frame = ttk.Frame(root, padding=12)
    frame.pack(fill="both", expand=True)
    buttons = ttk.Frame(frame)
    buttons.pack(side="bottom", fill="x")
    ttk.Label(frame, text="HUMAN ROBLOX COMPLIANCE REVIEW REQUIRED.", font=("Segoe UI", 15, "bold"), foreground="#9b1515").pack(anchor="w")
    ttk.Label(frame, wraplength=980, text="Approving confirms that you have personally reviewed the displayed asset and upload metadata for suitability, rights/licensing, and Roblox policy compliance. Roblox moderation still applies.").pack(anchor="w", pady=8)
    notebook = ttk.Notebook(frame)
    notebook.pack(fill="both", expand=True)
    photo_refs = []
    image_inputs = [("Frozen asset", data)] if record["asset_type"] != "Model" else [(view, Path(path).read_bytes()) for view, path in record["preview_files"].items()]
    for label, content in image_inputs:
        image = Image.open(io.BytesIO(content)).convert("RGBA")
        image.thumbnail((930, 420))
        checker = Image.new("RGBA", image.size, "white")
        draw = ImageDraw.Draw(checker)
        for y in range(0, image.height, 16):
            for x in range(0, image.width, 16):
                if (x // 16 + y // 16) % 2:
                    draw.rectangle((x, y, x + 15, y + 15), fill="#c8c8c8")
        checker.alpha_composite(image)
        photo = ImageTk.PhotoImage(checker)
        photo_refs.append(photo)
        tab = ttk.Frame(notebook)
        notebook.add(tab, text=label)
        ttk.Label(tab, image=photo).pack(expand=True)
    detail_frame = ttk.Frame(frame)
    detail_frame.pack(fill="both", expand=True, pady=8)
    details = tk.Text(detail_frame, height=14, wrap="word")
    scrollbar = ttk.Scrollbar(detail_frame, orient="vertical", command=details.yview)
    scrollbar.pack(side="right", fill="y")
    details.configure(yscrollcommand=scrollbar.set)
    details.pack(side="left", fill="both", expand=True)
    shown = {key: record.get(key) for key in ("filename", "sha256", "asset_type", "creator", "display_name", "description", "target_asset_id", "validation", "provenance", "model_evidence", "demo")}
    details.insert("1.0", json.dumps(shown, indent=2, ensure_ascii=False))
    details.configure(state="disabled")

    def deny():
        record["state"] = "DENIED"
        store.save(record)
        root.destroy()

    decision_taken = False

    def approve():
        nonlocal decision_taken
        if decision_taken:
            return
        decision_taken = True
        try:
            upload_data = verified_bytes(record)
            if upload_data != data:
                raise ValueError("Preview bytes changed")
            record["state"] = "APPROVED"
            store.save(record)
            if record["demo"]:
                record.update(state="DEMO_COMPLETE", moderation_state="DEMO_NOT_SUBMITTED", production_ready=False, network_writes=0)
                store.save(record)
                root.destroy()
                return
            require_installed()
            import httpx

            api_key = credential()
            kind, creator_id = record["creator"].split(":")
            metadata = {"assetType": record["asset_type"], "displayName": record["display_name"], "description": record["description"], "creationContext": {"creator": {kind + "Id": creator_id}}}
            target = record.get("target_asset_id")
            if target:
                metadata["assetId"] = target
            record["state"] = "UPLOAD_STARTING"
            store.save(record)
            root.destroy()
            with httpx.Client(timeout=60, trust_env=False, follow_redirects=False) as client:
                response = client.request("PATCH" if target else "POST", "https://apis.roblox.com/assets/v1/assets" + ("/" + target if target else ""),
                    headers={"x-api-key": api_key}, data={"request": json.dumps(metadata)},
                    files={"fileContent": (record["filename"], upload_data, record["validation"]["content_type"])})
            record["http_status"] = response.status_code
            try:
                record["response"] = response.json()
            except ValueError:
                record["response"] = {"error": "Non-JSON upload response"}
            operation = record["response"].get("path", "")
            if response.is_success and re.fullmatch(r"operations/[A-Za-z0-9_-]+", operation):
                record["operation"] = operation
                record["state"] = "UPLOAD_OPERATION_KNOWN"
            else:
                record["state"] = "RECOVERY_REQUIRED"
                record["error"] = "No durable operation ID; inspect response and Roblox before any new request"
            store.save(record)
            if record.get("operation"):
                poll(store, record)
        except Exception as exc:
            if record.get("operation"):
                record["state"] = "UPLOAD_OPERATION_KNOWN"
            elif record["state"] == "UPLOAD_STARTING":
                record["state"] = "RECOVERY_REQUIRED"
            else:
                record["state"] = "WAITING_FOR_APPROVAL"
            record["error"] = type(exc).__name__ + "; inspect gate status; no automatic upload retry"
            store.save(record)
            try:
                messagebox.showerror("Gate stopped", record["error"], parent=root)
            except tk.TclError:
                pass

    ttk.Button(buttons, text="DENY", command=deny).pack(side="left")
    ttk.Button(buttons, text="DEMO APPROVE — NO UPLOAD" if record["demo"] else "APPROVE & UPLOAD", command=approve).pack(side="right")
    root.protocol("WM_DELETE_WINDOW", root.destroy)
    def foreground_request():
        root.deiconify()
        root.attributes("-topmost", True)
        root.lift()
        root.focus_force()
        root.after(500, lambda: root.attributes("-topmost", False))

    root.after_idle(foreground_request)
    root.mainloop()


def resume_requests(store, records):
    failed = False
    for record in records:
        try:
            if record.get("operation") and record["state"] in {"UPLOAD_OPERATION_KNOWN", "MODERATION_PENDING"}:
                poll(store, record)
            elif record["state"] == "WAITING_FOR_APPROVAL":
                approval_window(store, record)
        except (ValueError, OSError) as exc:
            record["resume_error"] = type(exc).__name__ + "; inspect frozen files and metadata before resuming this request"
            store.save(record)
            print(f"Request {record['id']} could not resume: {record['resume_error']}", file=sys.stderr)
            failed = True
    return failed


def main():
    home = require_installed()
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list")
    commands.add_parser("doctor")
    resume = commands.add_parser("resume")
    resume.add_argument("request_id", nargs="?")
    status = commands.add_parser("status")
    status.add_argument("request_id")
    accept = commands.add_parser("receive")
    accept.add_argument("request_file")
    args = parser.parse_args()
    with file_lock(home / "gate.lock"):
        store = Store(home)
        store.recover()
        if args.command == "doctor":
            try:
                has_key = bool(credential())
            except Exception:
                has_key = False
            print(json.dumps({"installed": True, "credential_present": has_key, "sqlite": store.db.execute("PRAGMA integrity_check").fetchone()[0], "pending": sum(r["state"] not in {"COMPLETE", "DEMO_COMPLETE", "DENIED", "FAILED"} for r in store.all())}))
        elif args.command == "list":
            print(json.dumps([{k: r.get(k) for k in ("id", "state", "sha256", "demo", "asset_id")} for r in store.all()], indent=2))
        elif args.command == "status":
            print(json.dumps({k: v for k, v in store.get(args.request_id).items() if k not in {"inbox", "frozen", "preview_files"}}, indent=2))
        elif args.command == "receive":
            record = receive(store, args.request_file)
            print(record["id"], flush=True)
            if record["state"] == "WAITING_FOR_APPROVAL":
                approval_window(store, record)
        else:
            records = [store.get(args.request_id)] if args.request_id else store.all()
            failed = resume_requests(store, records)
            store.db.close()
            return 1 if failed else 0
        store.db.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Gate stopped: {type(error).__name__}", file=sys.stderr)
        raise SystemExit(1)
