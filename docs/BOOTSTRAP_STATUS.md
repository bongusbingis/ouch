# Autonomous workflow bootstrap status

Implementation is installed on `tooling/agent-workflow`. The existing `.gitignore` entries were preserved and extended. No gameplay source, Studio-authored place binary, or existing place deployment pipeline was changed. The user explicitly chose standalone asset gating while preserving place CI.

Implemented: native Python reviewer wrappers, Iconify search/acquisition/PNG rendering, local Kenney CC0 indexing/acquisition, centralized asset validation, provenance manifests, deterministic notices/Luau credits, external Tkinter/SQLite gate installer and launcher, request preparation/status/reconciliation, doctor, recovery commands, Windows CI, and regression/smoke-test tools.

Installed external app: `%LOCALAPPDATA%\RobloxAssetGate`. Both required Credential Manager entries were detected without printing secrets. Gemini is configured as `gemini-3.5-flash` with user authorization to choose a model. Canonical Figma: https://www.figma.com/design/qOQKzOXH6HIc8g1PHWvplh/Untitled . It is currently empty; no production design system was invented.

Verified on 2026-09-08:

- 25 distinct offline regressions passed, including mocked production transport byte/metadata checks, timeout and HTTP-error non-retry, credential isolation, hash binding, licensing, credits, local Kenney indexing, and reconciliation.
- Native Tkinter windows mapped and demo approve/deny/close callbacks passed with credential/network traps. This is programmatic test evidence, not a human visual inspection.
- Installed gate process tree was forcibly terminated during a demo, then recovered WAITING_FOR_APPROVAL with identical SHA-256 `fde233a3c1863e9a33116448c0158fa61306d71218eee42fa3e1b1dd91fe04b2`.
- Recovery demo request `3e6df78c-0a09-48ec-b651-00e11837c754`; earlier pending demo `fc03789d-225e-4b5f-abed-40945c5b29b9`. Both may be resumed/denied locally; neither is a production upload.
- Claude subscription smoke test passed after the wrapper rejected an initial invalid response and added restricted/structured-output flags.
- Gemini text and image review passed; advisory findings are reconciled in REVIEW_DISPOSITIONS.md.
- Iconify search, MIT license metadata/text retrieval, original SVG preservation, native PNG export, provenance, and credit generation passed using `ph:star-fill`.
- Figma authenticated inspect/write/cleanup passed: disposable node `5:2` removed and original empty Page 1 verified.
- Manifest validation, syntax checks, and repository asset-write audit passed within the confirmed standalone-upload scope. Runtime executed from the repository refused operation as intended.

Still blocked/pending:

- Studio MCP exposes no tools in this session; inspect-only Studio smoke test has not run.
- Computer Use cannot initialize: Windows sandbox `apply deny-read ACLs` / Node runtime failure. Blender 5.2 is detected, but visual inspection/modeling/saving smoke test did not run. No Blender MCP was installed.
- Human visual inspection of the gate layout remains pending because Computer Use is unavailable.
- Automatic approval review rejected sending selected private gate source to Claude. Exact bounded packet is local at `.review/claude-22311112-a9e7-4725-84e6-761cd970be83/packet.txt`; payload-specific user approval was requested and is still pending. Source changed further after that snapshot; any review must identify the reviewed snapshot and account for subsequent changes.
- The specified same-user Tkinter architecture cannot enforce an unforgeable human-only approval against arbitrary same-user agents/code. The normal workflow is gated; an adversarial OS boundary requires a separately protected identity or trusted approval service. Do not represent the hard universal guarantee as completed.

No real Roblox upload was performed. No authentication was changed and no key was printed. Complete commands/prompts are in WORKFLOW_COMMANDS.md; begin recovery with RECOVERY.md and `tools/doctor.py`. Doctor intentionally reports pending integration/security limitations instead of declaring full readiness. Safe tests and local reviewer evidence live in `.review/` and survive process restarts but are not committed. Gate database/frozen content remain outside Git.
