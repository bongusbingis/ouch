"""Terminate only a freshly launched DEMO gate and verify durable recovery; no uploads."""

import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

from assetctl import gate_command
from workflow_common import ROOT, read_json, write_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--resume", action="store_true", help="Reopen the same demo approval after the forced-exit check")
    args = parser.parse_args()
    existing = subprocess.run(gate_command("list"), capture_output=True, text=True)
    if existing.returncode:
        raise SystemExit("Close any current gate popup before running the isolated interruption test")
    prepared = subprocess.run([sys.executable, "tools/assetctl.py", "demo", "--prepare-only"], cwd=ROOT, capture_output=True, text=True, check=True)
    request_path = Path(prepared.stdout.strip().split("Prepared: ", 1)[1])
    proposal = read_json(request_path)
    if proposal.get("demo") is not True:
        raise RuntimeError("Only a demo can run this interruption test")
    process = subprocess.Popen(gate_command("receive", request_path), cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    inbox = ROOT / ".asset-inbox" / (proposal["id"] + ".json")
    try:
        deadline = time.monotonic() + 15
        while not inbox.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.1)
        if not inbox.exists():
            raise RuntimeError("Gate did not persist the demo before timeout")
        before = read_json(inbox)
        time.sleep(1)
    finally:
        if process.poll() is None:
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], check=True, capture_output=True)
        process.wait(timeout=10)
    result = subprocess.run(gate_command("status", proposal["id"]), capture_output=True, text=True, check=True)
    after = json.loads(result.stdout)
    if after["sha256"] != before["sha256"] or after["state"] != "WAITING_FOR_APPROVAL":
        raise RuntimeError("Unexpected state/hash after interruption (was the demo decided during the test?)")
    evidence = {"request_id": proposal["id"], "sha256_before": before["sha256"], "sha256_after": after["sha256"], "state": after["state"], "forced_process_exit": True, "demo_only": True}
    write_json(ROOT / ".review/interruption-test.json", evidence)
    print(json.dumps(evidence, indent=2))
    if args.resume:
        subprocess.run(gate_command("resume", proposal["id"]), check=True)


if __name__ == "__main__":
    main()
