"""Prepare requests and reconcile non-secret results; cannot retrieve upload credentials."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import uuid

from asset_policy import validate_bytes
from workflow_common import ROOT, digest, file_lock, project_path, read_json, write_json


def gate_command(*args):
    home = Path(os.environ["LOCALAPPDATA"]) / "RobloxAssetGate"
    python = home / "venv/Scripts/python.exe"
    if not python.exists() or not (home / "run.py").exists():
        raise RuntimeError("Install the gate: .\\.agent-venv\\Scripts\\python.exe tools\\install_asset_gate.py")
    return [str(python), "-I", str(home / "run.py"), *map(str, args)]


def prepare(args):
    path = project_path(args.file)
    data = path.read_bytes()
    relative = path.relative_to(ROOT).as_posix()
    catalog = read_json(ROOT / "manifests/external-assets.json", {"assets": {}})["assets"]
    record = catalog.get(relative) or read_json(ROOT / "manifests/assets.json", {"assets": {}})["assets"].get(relative)
    if args.provenance:
        provenance = read_json(project_path(args.provenance))
    elif record:
        provenance = record.get("provenance", record)
    elif args.command == "demo":
        provenance = {"author": "Splat Brawl project", "provider": "project", "source_id": "approval-demo", "source_url": "local:tools/assetctl.py", "license": "Project-Owned", "license_url": "local:demo-only", "attribution_required": False, "modifications": []}
    else:
        raise ValueError("Record provenance in the manifest or provide --provenance JSON")
    proposal = {"id": str(uuid.uuid4()), "project_root": str(ROOT), "file": str(path), "production_file": relative,
                "sha256": digest(data), "asset_type": args.asset_type, "creator": args.creator,
                "display_name": args.display_name, "description": args.description, "target_asset_id": args.target_asset_id,
                "provenance": provenance, "demo": args.command == "demo",
                "model_evidence": read_json(project_path(args.model_evidence)) if args.model_evidence else None,
                "source": record.get("source") if record else None}
    proposal["validation"] = validate_bytes(data, path.name, args.asset_type, proposal)
    destination = ROOT / ".asset-requests" / (proposal["id"] + ".json")
    write_json(destination, proposal)
    with file_lock(ROOT / ".agent-cache/manifests.lock"):
        manifest = read_json(ROOT / "manifests/assets.json")
        manifest["requests"][proposal["id"]] = {"state": "PREPARED", "sha256": proposal["sha256"], "production_file": relative, "demo": proposal["demo"], "sequence": 0}
        write_json(ROOT / "manifests/assets.json", manifest)
    return destination


def reconcile():
    with file_lock(ROOT / ".agent-cache/manifests.lock"):
        manifest = read_json(ROOT / "manifests/assets.json")
        for path in sorted((ROOT / ".asset-inbox").glob("*.json")):
            result = read_json(path)
            previous = manifest["requests"].get(result["id"])
            if not previous or result.get("sha256") != previous["sha256"]:
                raise ValueError("Result does not match a prepared request")
            if result["sequence"] <= previous.get("sequence", 0):
                continue
            if result["production_file"] != previous["production_file"] or result["demo"] != previous["demo"]:
                raise ValueError("Result request metadata mismatch")
            manifest["requests"][result["id"]] = result
            if result["state"] == "COMPLETE" and not result["demo"]:
                production = project_path(result["production_file"])
                if digest(production.read_bytes()) != result["sha256"]:
                    manifest["requests"][result["id"]]["reconcile_error"] = "Production bytes changed; result retained but asset mapping not applied"
                    continue
                if result.get("moderation_state") != "MODERATION_STATE_APPROVED" or not result.get("asset_id"):
                    raise ValueError("Completed result lacks approved moderation and asset ID")
                manifest["assets"][result["production_file"]] = result
        write_json(ROOT / "manifests/assets.json", manifest)
    print("Reconciled results atomically; repeated records are ignored.")


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("submit", "demo"):
        command = commands.add_parser(name)
        command.add_argument("--file", required=name == "submit")
        command.add_argument("--asset-type", default="Decal")
        command.add_argument("--display-name", default="Disposable approval demo")
        command.add_argument("--description", default="Disposable workflow validation asset")
        command.add_argument("--creator", required=name == "submit", default="user:1")
        command.add_argument("--target-asset-id")
        command.add_argument("--provenance")
        command.add_argument("--model-evidence")
        command.add_argument("--prepare-only", action="store_true")
    commands.add_parser("status")
    commands.add_parser("reconcile")
    args = parser.parse_args()
    if args.command == "reconcile":
        reconcile()
    elif args.command == "status":
        print(json.dumps(read_json(ROOT / "manifests/assets.json")["requests"], indent=2))
        subprocess.run(gate_command("list"), check=True)
    else:
        if args.command == "demo" and not args.file:
            from PIL import Image, ImageDraw

            path = ROOT / ".review/approval-demo.png"
            path.parent.mkdir(parents=True, exist_ok=True)
            image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            draw = ImageDraw.Draw(image)
            draw.rounded_rectangle((48, 48, 464, 464), radius=96, fill="#ffce32")
            draw.text((155, 242), "DEMO - NO UPLOAD", fill="#222222")
            image.save(path)
            args.file = str(path)
        request = prepare(args)
        print(f"Prepared: {request}", flush=True)
        if not args.prepare_only:
            subprocess.run(gate_command("receive", request), check=True)


if __name__ == "__main__":
    main()
