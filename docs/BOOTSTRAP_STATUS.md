# Autonomous workflow bootstrap status

Implementation is installed on `tooling/agent-workflow`. The existing `.gitignore` entries were preserved and extended. No gameplay source, Studio-authored place binary, or existing place deployment pipeline was changed. The user explicitly chose standalone asset gating while preserving place CI.

Implemented: native Python reviewer wrappers, Iconify search/acquisition/PNG rendering, local Kenney CC0 indexing/acquisition, centralized asset validation, provenance manifests, deterministic notices/Luau credits, external Tkinter/SQLite gate installer and launcher, request preparation/status/reconciliation, doctor, recovery commands, Windows CI, and regression/smoke-test tools.

Installed external app: `%LOCALAPPDATA%\RobloxAssetGate`. Both required Credential Manager entries were detected without printing secrets. Gemini is now configured as `gemini-3.7-flash`; the user requested the strongest model currently usable without billing changes. Canonical Figma: https://www.figma.com/design/qOQKzOXH6HIc8g1PHWvplh/Untitled . It is currently empty; no production design system was invented.

Verified on 2026-09-08:

- 25 distinct offline regressions passed, including mocked production transport byte/metadata checks, timeout and HTTP-error non-retry, credential isolation, hash binding, licensing, credits, local Kenney indexing, and reconciliation.
- Native Tkinter windows mapped and demo approve/deny/close callbacks passed with credential/network traps. This is programmatic test evidence, not a human visual inspection.
- Installed gate process tree was forcibly terminated during a demo, then recovered WAITING_FOR_APPROVAL with identical SHA-256 `fde233a3c1863e9a33116448c0158fa61306d71218eee42fa3e1b1dd91fe04b2`.
- Recovery demo request `3e6df78c-0a09-48ec-b651-00e11837c754` and earlier demo `fc03789d-225e-4b5f-abed-40945c5b29b9` both subsequently reached DEMO_COMPLETE with zero network writes. Their results are reconciled; the installed gate has no pending requests.
- Claude subscription smoke test passed after the wrapper rejected an initial invalid response and added restricted/structured-output flags.
- Gemini text and image review passed; advisory findings are reconciled in REVIEW_DISPOSITIONS.md.
- Iconify search, MIT license metadata/text retrieval, original SVG preservation, native PNG export, provenance, and credit generation passed using `ph:star-fill`.
- Figma authenticated inspect/write/cleanup passed: disposable node `5:2` removed and original empty Page 1 verified.
- Manifest validation, syntax checks, and repository asset-write audit passed within the confirmed standalone-upload scope. Runtime executed from the repository refused operation as intended.

Retry verification on 2026-09-08:

- Computer Use now works. Blender 5.2 was inspected in its unsaved scene. Recovery copies are `.review/blender-before-smoke.blend` and `.review/blender-after-smoke.blend`. A separate `WorkflowSmoke_20260908` scene and `WorkflowSmokeCube` were created through the visible Python console, saved at `assets/source/blender/workflow-smoke.blend`, visually verified, and removed from the live session. The original scene, objects, Edit mode, and viewport were restored. Visual evidence is `.review/blender-smoke-visual.png` and `.review/blender-smoke-cleanup.png`. The disposable source copy is ignored because it also contains the preexisting scene.
- Native Studio MCP connected through the installed `StudioMCP.exe` stdio proxy after an eight-second registration delay. Both intended places passed `get_studio_state`, bounded `search_game_tree`, and `inspect_instance` calls in Edit mode. Evidence: `.review/studio-mcp-evidence.json`. No instance mutation, play transition, save, or publish occurred. The current session tool inventory still does not expose the server directly; this smoke test used its native MCP protocol.
- Computer Use inspected the resumed gate preview, compliance text, SHA-256, upload metadata, and controls. Request `3e6df78c-0a09-48ec-b651-00e11837c754` completed in demo mode with `network_writes: 0` and the same hash. The gate now has a visible metadata scrollbar and bottom-anchored decision buttons; it was reinstalled, and all 25 regressions plus native approve/deny/close callback checks passed again.
- Claude source review was retried under the renewed request, first with four selected files, then only the gate runtime. Both attempts timed out after 240 seconds. Evidence: `.review/claude-cfd7aacc-a8d2-4338-b439-cc3253f0786c` and `.review/claude-03712edd-d96e-409f-9101-a84e1397bda2`. No source verdict was obtained; the earlier approval-review blocker is superseded by these timeouts.

Latest follow-up:

- Claude timeouts are resolved: authentication and subscription access worked; generation outlasted the old deadline. Explicit medium effort completed the source review. The wrapper now allows 900 seconds (override with `--timeout`), displays and persists progress every 15 seconds, and reports the last phase on timeout. No account action was needed. Findings and fixes are in REVIEW_DISPOSITIONS.md.
- Each approval popup is raised and focused when shown, including each request in a resume batch. Topmost is released after 500 ms. Three successive native demo windows passed focus checks; no approval is automated by this behavior.
- The accepted review finding about a broken request blocking batch recovery is fixed. All 28 regressions passed and the external gate was updated.
- The user acknowledged the cooperative same-user security limitation and requested no further hardening. It remains documented as context, not pending setup work.

No real Roblox upload was performed. No authentication was changed and no key was printed. Complete commands/prompts are in WORKFLOW_COMMANDS.md; begin recovery with RECOVERY.md and `tools/doctor.py`. Doctor retains the integration evidence and acknowledged trust boundary. Safe tests and local reviewer evidence live in `.review/` and survive process restarts but are not committed. Gate database/frozen content remain outside Git.


Gemini Pro follow-up: selected `gemini-3.1-pro-preview`, confirmed it in the credential's model listing, and attempted both text and image smoke tests. Both were rejected. A bounded diagnostic confirmed HTTP 429 RESOURCE_EXHAUSTED with free-tier request and input-token limits of 0 for gemini-3.1-pro. This is an API-project entitlement/billing blocker, not a model-name or authentication failure. Pro remains selected; no Flash fallback was added. The user must enable billing for the existing key's project in Google AI Studio (and add prepaid credits if requested), then rerun the reviewer smoke tests. No billing settings were changed by the agent. Previous Gemini PASS results refer to Flash only.


The later request to use the highest available model supersedes the Pro-only selection and billing action above. Pro 2.5 also returned 404 (unavailable to new users). Flash 3.8 returned HTTP 503 high demand, and a second reviewer call failed with ServerError. Flash 3.7 passed a direct text call and is selected explicitly. Availability evidence: `.review/gemini-model-availability.json`. No billing changes were made.

Flash 3.7 also passed the full image-review wrapper with the required verdict structure: `.review/gemini-3c28ef35-0cc3-4c38-9f93-d8c16bfcfb82`. Text and image checks are both PASS; no manual Gemini setup remains.
