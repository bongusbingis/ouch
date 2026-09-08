# Recovery after interruption

Open native PowerShell. Nothing here requires remembered variables, a running server, or a prior conversation.

```powershell
Set-Location C:\Users\jackc\Desktop\ouch
git status --short
git log -3 --oneline
.\.agent-venv\Scripts\python.exe tools\doctor.py
& "$env:LOCALAPPDATA\RobloxAssetGate\bin\rbx-asset-gate.cmd" list
.\.agent-venv\Scripts\python.exe tools\assetctl.py reconcile
```

Read `docs/BOOTSTRAP_STATUS.md`, `tools/integration-status.json`, task notes, and manifest request history. If the virtualenv is missing, recreate it with installed Python 3.12 (`py -3.12 -m venv .agent-venv`) and install `tools/requirements.txt`. If the gate is missing, run the installer. Never delete an existing gate database to fix installation.

Use `rbx-asset-gate status <request-id>` for a specific request. `rbx-asset-gate resume <request-id>` reopens a pending graphical approval or polls its known operation. Omitting the ID processes pending requests sequentially. No remembered approval is replayed after restart. A closed popup stays WAITING_FOR_APPROVAL. APPROVED without a transmitted write returns to WAITING_FOR_APPROVAL. RECOVERY_REQUIRED means stop and inspect Roblox manually before creating any replacement request; it is deliberately not automatically retryable.

After a file was prepared but not received, its UUID JSON remains under `.asset-requests`. Run the installed gate's `receive <absolute-request-json-path>`; duplicate receives reuse that UUID and reject changed proposal bytes. Do not generate a new UUID as a recovery shortcut. Result handoffs replay on a later gate invocation if the project drive was unavailable. Reconcile again after polling.

For Blender, inspect the currently visible application through Computer Use and reopen the saved `.blend` source named in the manifest/task note. Never assume an unsaved scene survived. Save before continuing exports. For Studio, reopen the intended authored place and reconnect its explicit Rojo project (`arena.project.json` on 34872 or `lobby.project.json` on 34873). Do not edit `.rbxl` contents using repository tools. Revalidate the runtime and capture new Studio evidence before production acceptance.

Figma state is in the canonical remote file recorded in `tools/workflow.json`. Review local node IDs and source export paths before producing new assets. Windows Credential Manager owns credentials. Do not print or recreate keys merely because an application restarted.

`.review/<provider>-<id>/state.json` tracks reviewer runs. RUNNING after a crash means the outcome is unknown; inspect retained response files before deciding whether a new paid review is justified. Carry accepted findings and next actions into durable task notes. See `docs/WORKFLOW_COMMANDS.md` for smoke tests and first-upload preparation.
