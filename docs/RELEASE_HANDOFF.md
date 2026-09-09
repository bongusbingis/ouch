# Continue after owner visual approval

Workspace: `C:\Users\jackc\Desktop\ouch`, branch `tooling/agent-workflow`. Approved gameplay/source revision: `faedbc3cd4be7b0e5a4a521511b30fdf3e3687f2`. Start in a fresh chat; this document replaces the long conversation history, not the original task requirements.

## Authorization and scope

The owner's latest instruction is: **"The visual review is now approved. Proceed with the rest of the plan in a fresh context window to avoid context rot."**

The manual visual checkpoint is satisfied and the next phase is authorized. Do not ask for that approval again or keep redesigning the accepted lobby. This does not erase open content/functionality/device issues or convert failed advisor runs into passes. Later material changes to approved visuals need focused renewed approval.

Read the original request at `.review/visual-release/original-request.md`, then the current `docs/VISUAL_RELEASE_AUDIT.md` issue ledger. The exact original attachment remains at `C:\Users\jackc\.codex\attachments\1c8ce7b2-6871-4ea0-891c-040f27556bf1\pasted-text.txt`. Later instructions in this handoff supersede its earlier medium-Claude-effort and pending-visual-checkpoint wording. Implement and verify the remaining plan; do not stop at another audit or recommendations.

Preserve these owner changes; do not stage, restore, overwrite or delete them:

```
 D AGENTS.md
 M docs/ART_STYLE.md
 D docs/RECOVERY.md
 D docs/SECURITY_AUDIT.md
```

`AGENTS.md` was deliberately absent throughout this work. Read its committed version with `git show HEAD:AGENTS.md` without restoring it, and follow any current nested instructions. Continue using existing React roots, shared components and single-owner state. Required authored assets use WaitForChild plus type assertions. Do not construct imperative gameplay/UI assets, introduce architectural guesses, or edit place binaries with repository tooling.

All Git pushes, release PRs, deployments (including private staging), and place publishing are owner-only. Local code, tests, fixtures, builds and commits are authorized. No real purchases, billing/account changes, live migrations/resets, new commercial offerings, or Creator Hub monetization changes. Standalone asset uploads are separately authorized through the installed human gate; refocus every approval window and never click the owner's approval. Preserve place CI. Protect unsaved Studio/Blender work.

## Next work in priority order

1. Reconfirm Git state and both Studio place identities/modes; use bounded doctor/status checks rather than repeating bootstrap. Walk a fresh-player session and a returning-player session through existing lobby/tutorial/party, actual match, rewards and return paths. Record reproducible first-session/core-loop blockers and fix them through existing owners. Start with the known tutorial skip/glyph discoverability issue and phone Join Party keyboard obstruction. Prepare owner-run remote checks where local Studio cannot establish behavior.
2. Carry forward mobile modal backdrop clipping, controller focus/input presentation, landscape tablet and narrow/cutout coverage, and missing in-game credits integration through existing Settings. Preserve the approved lobby composition, logo and action hierarchy. Physical-device behavior remains unverified; emulation is not equivalent.
3. Complete scoped content: inspect actual authored arena fans/spinners and comparable obstacle behavior; preserve the approved static map/layout/art. Inspect and rebuild the existing Wave/Showtime/victory performances as polished content using the actual rig and existing emote ownership/system. Native Blender via Computer Use only; protect the owner's scene first. Determine behavior from source and Studio, not object names. Ask only if gameplay intent or a major architecture remains genuinely unresolved.
4. Inspect earning/spending/duplicate rules and calculate justified Bonks pacing, catalogue, rarity, price and crate changes. Use actual code/config inputs and label design estimates. Verify current official Roblox paid-random-item/PolicyService rules; enforce restricted, pending, unknown and failed eligibility authoritatively across every relevant entry point. Restricted paid-random interactions are disabled, with no invented alternative shop or compensation. Preserve developer products/game passes; report out-of-scope defects and owner setup rather than changing commercial promises.
5. Exercise reward replay, rapid/repeated input, invalid IDs, ownership/duplicates, interrupted actions, equip/respawn/reset, disconnects, persistence and repeated-round resource/performance behavior. Use isolated mocks and test namespaces deliberately. Prepare exact owner-run deployment/device/payment checks where necessary; never deploy yourself.
6. Deliver the original request's final release recommendation with implemented changes, evidence, content/economy decisions, platform/input/state coverage, remaining owner actions, mock cleanup, provenance, local commits and owner-executed QA/deployment checklist. Do not declare readiness solely from test counts or this visual approval.

## Existing evidence and state

The accepted review is `.review/visual-release/comparison/index.html`; source mapping and revision are in its `sources.json`. PC, iPhone landscape, intermediate 1280x720 and small 568x320 captures show the actual runtime. The logo uses measured visible artwork and optical alignment; Join/Invite have white lettering on cyan, with larger pink Play and matched sliced corners. Do not redo this work for novelty.

Source changes are committed at `faedbc3`; predecessor `eabc8d9` dark lettering/old logo was rejected. Final checks: 48 Python workflow regressions and 745 Luau tests passed; shared/lobby Selene and changed-file StyLua passed. The 12 Studio responsive specs are predecessor evidence, not newly rerun with the last capture. New tests are only needed for meaningful changes or unresolved concerns.

Both Studios were left in Edit. Lobby `75cff925-5f89-4533-996d-32addabf7c9b` is place `130584867985467`; arena `889eb175-709a-42ae-bfcb-014e4ce35bcc` is place `121997450145716`. Re-list rather than assuming instance IDs survive. `lobby.project.json` uses 34873; `arena.project.json` uses 34872; always specify the project. No `.rbxl` saved/published by the agent. Temporary simulator/mock state was removed; `.review/visual-release/consistency-pass/cleanup.json` and `restored-player-data.luau` verify restored PlayerData source exactly. Existing `STAGING_009` namespace alone does not prove isolated persistent testing. No real persistence or payment acceptance was established.

## Model and tool routing

Astra owns every visual review, design judgment and task requiring strong reasoning, together with the existing advisor workflow. Smaller Codex models only execute tightly specified edits or mechanical preparation/checks; they do not decide visual quality. The owner prefers GPT-5.3-Codex-Spark for such work. It was not exposed in the prior session; gpt-5.6-luna handled bounded artifact/document edits with the substitution disclosed. Recheck availability without a model-research detour. Use independent bounded agents where useful; serialize conflicting source edits and all desktop control.

Keep Claude/Gemini depth and milestone cadence. Claude uses the subscription CLI wrapper with **max** effort. Gemini remains explicitly configured as `gemini-3.7-flash`, the previously established usable account model; no silent fallback, key changes or billing changes. Read `docs/TOOL_ROUTING.md`, `docs/WORKFLOW_COMMANDS.md`, `docs/VISUAL_REVIEW.md`, `docs/ASSET_PIPELINE.md`, `tools/workflow.json` and wrapper help before relevant operations. Bootstrap/integration status contains historical successes; current failures below take precedence.

Recent Gemini review attempts returned 503 UNAVAILABLE, including `.review/gemini-7250f504-8b86-41dd-aeb7-9659faae933f`. `.review/gemini-01481a73-12d9-4bcb-ac5d-e8dddf05a7f8` returned PASS text but failed peer-reference validation; it is not ADVISORY_PASS. Claude max `.review/claude-d0523e58-501d-42b1-ab7b-ac97aa46c254` reached 900 seconds while actively generating with rate-limit status allowed; no verdict. Earlier medium review findings and their implemented/rejected dispositions are in the audit. Do not blindly rerun these paid calls or fabricate results. No authentication fix was indicated. Your visual approval is recorded separately at `.review/visual-release/owner-visual-approval.json`; do not manufacture the release-purpose advisory/acceptance record to turn local preflight green. Unfinished advisor evidence does not revoke the owner's authorization to continue local work.

Figma canonical file: `https://www.figma.com/design/qOQKzOXH6HIc8g1PHWvplh/Untitled`. It contains partial editable compositions; it is not empty. MCP Starter quota was exhausted, but authorized native Chrome editing worked. `figma/checkpoint-state.json` under the visual review directory records partial nodes. Native Blender contains protected owner work; no new emote authoring has been completed. No real upload occurred in the lobby pass. Animation gate extensions are authorized only where needed, with honest content-specific previews, frozen approval, regressions, Claude review and explicit installed-gate update.

Read skill instructions before Computer Use/Figma/Blender work. Do not recreate the toolkit or reopen the acknowledged same-user security limitation. Keep raw evidence under `.review`, source assets in established directories, and this handoff/audit current at meaningful milestones.
