# Tool routing

Codex/Astra owns planning, architecture, implementation, Git, Rojo, final technical decisions, final art direction, and reconciliation of advisory findings. Follow the current owner scope in [PRODUCTION_READINESS_SPEC.md](PRODUCTION_READINESS_SPEC.md) and inspect existing source ownership before changes. Earlier AGENTS.md instructions were revoked; do not recover or restore them as instructions. Prefer the smallest readable solution that delivers the player experience; no speculative backend cleanup or architecture expansion.

| Work | Owner and evidence |
| --- | --- |
| UI, HUD, menus, components, tokens, simple 2D art, particles, masks, gradients | Figma through direct browser/Computer Use only; no Figma MCP. Inspect the canonical file in `tools/workflow.json`, reuse its system, persist node IDs and export paths |
| Modeling, UVs, rigging, animation, materials, collision, LODs, exports | Native Blender through Computer Use only; inspect visible state first, save `.blend` early and at milestones |
| Integration, gameplay, device layouts, lighting, particles, imports, final visual acceptance | Roblox Studio MCP against the intended place; preserve screenshots and runtime evidence |
| Architecture, networking, persistence, exploit surfaces, risky refactors, difficult debugging | Claude subscription CLI advisory review through `tools/reviewer.py claude` |
| Major UI/3D/VFX, source vs Studio comparisons, icon candidate ranking | Gemini advisory review through `tools/reviewer.py gemini` |
| Roblox asset-content writes | Installed external gate; human graphical approval required for each frozen request |

Do not call reviewers for formatting, boilerplate, routine searches/tests or simple renames. Tiny visual changes still require a peer comparison and personal Studio inspection under [VISUAL_REVIEW.md](VISUAL_REVIEW.md); include them in the next meaningful milestone review. Packets include the requirement, selected relevant files/diff/test evidence, or art direction plus relevant images. Never send the entire repository by default. No `.env`, credentials, cookies, or unrelated private files. The wrapper rejects sensitive paths and recognizable credential patterns; inspect selected content as well because pattern matching cannot detect every secret.

Claude runs from a fresh temporary directory with `claude -p`, stdin packets, verified `--tools ""`, `--restricted`, `--strict-mcp-config`, `--safe-mode`, and streaming JSON output. Max reasoning effort and a 900-second deadline are configured in tools/workflow.json. Progress is displayed and saved every 15 seconds; --timeout overrides the deadline for a particular Claude review. Its child environment removes both `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN`; authentication remains the existing subscription login. No Anthropic SDK, API key lookup, or `--bare`. CLI compatibility checks fail closed if isolation flags disappear.

Gemini uses `google-genai`, model `gemini-3.7-flash`, and the keyring entry `roblox-agent-gemini` / `api-key`. The user requested the strongest currently usable model without billing changes. Pro 3.1 returned zero quota, Pro 2.5 is unavailable to this account, and Flash 3.8 failed twice with service errors; Flash 3.7 passed a live text call. It supports text and image input per [Google's model documentation](https://ai.google.dev/gemini-api/docs/models/gemini-3.7-flash). No tools are supplied to Gemini. Model changes are explicit configuration edits, never silent fallback.

Claude and explicit Gemini smoke tests return the legacy advisory format. Visual Gemini reviews require `--visual-packet` and return structured case/category comparisons; an `ADVISORY_PASS` requires every check to pass and no findings. Neither format approves uploads or releases. Persist Codex's findings and dispositions in the task document; follow [VISUAL_REVIEW.md](VISUAL_REVIEW.md) for evidence freshness and owner acceptance. Review runs retain packet, result, and state under `.review`; interrupted RUNNING requests are not silently resubmitted.

For Blender, use short verified actions. Deterministic Python entered through the visible Blender UI is permitted for repetitive operations. Do not run Blender headlessly or install Blender MCP. When the UI is ambiguous, stop Blender actions and persist the pending task; continue independent work. Save source under `assets/source/blender/`, exports under `assets/models/`, and review imagery under `.review/`. Recover from the last saved source after interruption.

Use native PowerShell/Python and the existing pinned Windows executables. For local Luau checks: `lune run src/scripts/lune/run-tests.luau`; pass explicit arena/lobby project files to Rojo. Existing shell-based CI remains the existing release system; this bootstrap introduces no WSL dependency.

Studio MCP connection smoke test: allow Studio a few seconds to register after the native proxy starts, then list instances and match the explicit place IDs before inspection. Never invoke MCP `upload_image` or other asset-content upload methods; standalone uploads belong to the external approval gate.

Use a lightweight Codex model for bounded routine edits, file preparation and mechanical checks. The owner prefers GPT-5.3-Codex-Spark when available; do not silently label another model as Spark. If Spark is unavailable, use an exposed lightweight model for explicitly delegated routine work and report the substitution. This preference does not reduce Claude/Gemini review depth or cadence; Claude uses max effort.

Visual review, design judgment, architecture and tasks requiring strong reasoning stay with Astra plus the existing advisors. Do not classify visual judgment as trivial merely because its implementation is small. Delegate only tightly specified execution (for example, applying an already-decided alignment with measured artwork bounds), artifact preparation and mechanical checks; Astra verifies the visual result.
