# Workflow commands and smoke tests

Run commands from `C:\Users\jackc\Desktop\ouch` in native PowerShell. Explicit virtualenv paths avoid depending on activation or remembered shell variables.

1. Doctor:

   ```powershell
   .\.agent-venv\Scripts\python.exe tools\doctor.py
   ```

   Exit 2 means setup/integration work remains. Diagnostics never print credentials. GUI-only integrations require an agent session; installation alone does not prove them.

2. Install/update the external gate (close gate popups first):

   ```powershell
   .\.agent-venv\Scripts\python.exe tools\install_asset_gate.py
   ```

3. Claude subscription test (max effort; 900-second default deadline; `--timeout` may bound an individual review):

   ```powershell
   .\.agent-venv\Scripts\python.exe tools\reviewer.py claude --task "Smoke test: assess only this rule: uncertain uploads without a durable operation ID must never automatically retry. Return the required review structure."
   ```

4. Gemini text and image tests:

   ```powershell
   .\.agent-venv\Scripts\python.exe tools\reviewer.py gemini --smoke-test --task "Text smoke test: assess chunky filled icons for our toy-like game. Return the required structure."
   .\.agent-venv\Scripts\python.exe tools\assetctl.py demo --prepare-only
   .\.agent-venv\Scripts\python.exe tools\reviewer.py gemini --smoke-test --task "Image smoke test: describe the disposable demo fixture and assess readability. This is not production UI." --image .review\approval-demo.png
   ```

5. Icon search and acquisition:

   ```powershell
   .\.agent-venv\Scripts\python.exe tools\iconctl.py search star
   .\.agent-venv\Scripts\python.exe tools\iconctl.py acquire ph:star-fill --output assets\ui\workflow-star.png
   .\.agent-venv\Scripts\python.exe tools\generate_credits.py
   ```

6. Native demo popup:

   ```powershell
   .\.agent-venv\Scripts\python.exe tools\assetctl.py demo
   ```

   Each request window comes to the foreground and receives focus when shown. DEMO APPROVE, DENY, and window close all cause zero Roblox network writes. Close leaves the request pending. Agents must never click the production approval button.

7. Forced interruption/recovery test (close other gate windows first):

   ```powershell
   .\.agent-venv\Scripts\python.exe tools\interruption_test.py --resume
   .\.agent-venv\Scripts\python.exe tools\assetctl.py reconcile
   .\.agent-venv\Scripts\python.exe tools\run_safe_tests.py
   ```

   The script starts a new demo request, waits for durable persistence, terminates only its own child gate, checks state/hash, and optionally reopens the same request. Do not decide the popup while the forced-exit test is running. Evidence lives at `.review/interruption-test.json`. Offline tests mock GUI/transport; the integration script exercises the actual installed process.

8. Figma direct-control inspection prompt (no MCP):

   > Use the open authenticated Figma browser through direct browser/Computer Use to inspect https://www.figma.com/design/qOQKzOXH6HIc8g1PHWvplh/Untitled and its existing components/tokens. Do not use or configure Figma MCP. Record the observed file/page and canonical components needed for this task. Preserve existing work; do not repeat disposable mutation tests when inspection establishes the needed access.

9. Exact Blender Computer Use smoke-test prompt:

   > Use Computer Use only to inspect native Windows Blender. Do not install or use Blender MCP. Verify the current visible scene and protect any unsaved user work. I explicitly request a disposable modeling smoke test: create one uniquely named test object in a disposable saved .blend under assets/source/blender, save, verify it visually, then remove only the test object and save the clean test state. If the UI is ambiguous or the desktop is locked, stop Blender actions and persist the blocker.

10. Exact Studio smoke-test prompt:

    > Use Roblox Studio MCP for an inspect-only smoke test. Report connected place ID, edit/play state, relevant Workspace hierarchy, and available runtime inspection capability. Do not change instances, save, publish, or upload anything. Arena is 121997450145716; lobby is 130584867985467. Persist the observed result and any connector blocker.

11. First disposable real upload, **after bootstrap**, with the actual target ID substituted:

    ```powershell
    .\.agent-venv\Scripts\python.exe tools\assetctl.py submit --file assets\ui\workflow-star.png --asset-type Decal --display-name "Disposable workflow star" --description "Disposable Phosphor MIT icon upload test; notices retained in project." --creator "user:YOUR_ROBLOX_USER_ID"
    ```

    Use `group:YOUR_GROUP_ID` if that is the intended creator. No target account ID was supplied during bootstrap, so one must be entered deliberately. The command prepares and opens approval; only your graphical APPROVE & UPLOAD sends exact frozen bytes. Afterwards run `rbx-asset-gate resume <request-id>` to poll and `assetctl.py reconcile`. Never treat unknown/pending moderation as ready. Do not execute this real upload as a bootstrap test.

12. Short reboot recovery:

    ```powershell
    Set-Location C:\Users\jackc\Desktop\ouch
    git status --short
    .\.agent-venv\Scripts\python.exe tools\doctor.py
    & "$env:LOCALAPPDATA\RobloxAssetGate\bin\rbx-asset-gate.cmd" list
    .\.agent-venv\Scripts\python.exe tools\assetctl.py reconcile
    ```

    Inspect the request state before `resume`. Restore work from Git, canonical Figma, saved `.blend` files, Studio source and external gate state. See ASSET_PIPELINE.md for uncertain uploads. Do not restore the owner's deleted recovery/instruction files or retrieve credentials as a recovery shortcut.

13. Remaining manual/integration work is tracked in BOOTSTRAP_STATUS.md and tools/integration-status.json. No new secrets were requested or printed. A local native GUI cannot enforce an adversarial human-only boundary against arbitrary same-user code; see ASSET_PIPELINE.md before treating this as a security product.

For a local Kenney pack:

```powershell
.\.agent-venv\Scripts\python.exe tools\iconctl.py kenney-index --pack-id ui-pack --path asset-library\kenney\raw\ui-pack --source-url https://kenney.nl/assets/ui-pack --license-file asset-library\kenney\raw\ui-pack\License.txt
.\.agent-venv\Scripts\python.exe tools\iconctl.py acquire "kenney:ui-pack/PNG/example.png" --output assets\ui\example.png
```

Use the actual extracted pack file names. The index checks CC0 evidence and hashes; raw packs stay ignored.

## Visual milestones and local release readiness

Follow [VISUAL_REVIEW.md](VISUAL_REVIEW.md), including named peer comparisons and before/after cases. See `tools/visual-packet.example.json` for the required packet shape; replace its example paths and observations with actual evidence.

```powershell
.\.agent-venv\Scripts\python.exe tools\reviewer.py gemini --visual-packet .review\visual-release\packet.json --task "Inspect the requested changes against their named peers and actual surrounding UI."
.\.agent-venv\Scripts\python.exe tools\visual_review.py --review .review\gemini-REVIEW-ID
lune run src/scripts/lune/release-readiness.luau
```

The first command saves a structured advisory result, never release approval. The second rejects incomplete/contradictory results and stale sources, policy or evidence. Full local release readiness additionally requires a release-purpose review and the owner's actual final visual acceptance at the paths in `tools/workflow.json`. The prior lobby visual checkpoint is approved; it does not manufacture the full release-purpose records. See PRODUCTION_READINESS_SPEC.md for current scope and remaining gates. Existing place CI and upload approval behavior are unchanged.
