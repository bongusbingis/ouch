"""Non-secret native workflow diagnostics; delegates gate credential checks to the gate."""

import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

from assetctl import gate_command
from validate_assets import manifest_errors
from workflow_common import ROOT, read_json, write_json


def main():
    report = {"python": {"executable": sys.executable, "version": platform.python_version(), "virtualenv": sys.prefix != sys.base_prefix},
              "packages": {name: importlib.util.find_spec(name) is not None for name in ("httpx", "keyring", "PIL", "resvg_py", "google.genai", "tkinter")},
              "tools": {name: shutil.which(name) for name in ("git", "claude", "rojo", "lune", "stylua", "selene", "wally")},
              "anthropic_environment_presence": {name: name in os.environ for name in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")}}
    try:
        import keyring

        report["gemini_credential_present"] = bool(keyring.get_password("roblox-agent-gemini", "api-key"))
    except Exception as exc:
        report["gemini_credential_check"] = type(exc).__name__
    config = read_json(ROOT / "tools/workflow.json")
    report["gemini_model"] = config["gemini_model"]
    report["figma"] = {"file": config["figma_file_url"], "expectation": "Authenticated remote MCP; file inspect/write smoke test required in agent session"}
    report["studio"] = "Roblox Studio MCP must expose the intended place; inspect-only smoke test in agent session"
    report["blender"] = {"expectation": "Computer Use only; closed application is normal, not a permanent failure",
                         "detected": [str(p) for root in (Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Blender Foundation", Path(os.environ.get("LOCALAPPDATA", "")) / "Programs") if root.exists() for p in root.glob("Blender*/blender.exe")]}
    report["claude_test"] = '.\\.agent-venv\\Scripts\\python.exe tools\\reviewer.py claude --task "Subscription smoke test; return the required review structure."'
    try:
        result = subprocess.run(gate_command("doctor"), capture_output=True, text=True, timeout=30)
        report["asset_gate"] = json.loads(result.stdout) if result.returncode == 0 else {"status": "busy_or_failed", "exit_code": result.returncode}
    except Exception as exc:
        report["asset_gate"] = {"status": "unavailable", "error_type": type(exc).__name__}
    result = subprocess.run(["git", "status", "--short"], cwd=ROOT, capture_output=True, text=True)
    report["git_status"] = result.stdout.splitlines()
    try:
        report["manifest_errors"] = manifest_errors()
    except Exception as exc:
        report["manifest_errors"] = [type(exc).__name__]
    report["integration_evidence"] = read_json(ROOT / "tools/integration-status.json", {})
    report["security_boundary"] = "Installed same-user gate enforces workflow routing, not an OS boundary against arbitrary same-user code or synthetic GUI input. See docs/ASSET_PIPELINE.md."
    write_json(ROOT / ".review/doctor.json", report)
    print(json.dumps(report, indent=2))
    ready = not report["manifest_errors"] and all(report["packages"].values()) and report.get("gemini_credential_present") and report["asset_gate"].get("installed") and report["asset_gate"].get("credential_present")
    integrations_ready = all(not str(value).startswith(("BLOCKED", "PENDING")) for value in report["integration_evidence"].values())
    print("Tooling ready; integration checks pending." if ready and not integrations_ready else "Tooling checks completed.")
    return 0 if ready and integrations_ready else 2


if __name__ == "__main__":
    raise SystemExit(main())
