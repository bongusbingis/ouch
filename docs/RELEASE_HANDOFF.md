# Continue the production implementation

Read [PRODUCTION_READINESS_SPEC.md](PRODUCTION_READINESS_SPEC.md) first. It is the comprehensive Part 2 specification: current scope, source-confirmed findings, 14 work packages, acceptance, tool/delegation rules, scale model, schedule and owner release responsibilities. It incorporates the three independent planning audits and latest owner corrections; reconstructing the old conversation is unnecessary.

Target: **Saturday, September 12, 2026, 30–50k+ CCU**. Launch hour, physical testers and actual traffic shape remain open. Current planning work changed documentation only. It did not implement gameplay or establish release readiness.

## Start the new task with this prompt

> You are the authoritative GPT-6 Astra project lead for OUCH at C:\Users\jackc\Desktop\ouch. Read docs/PRODUCTION_READINESS_SPEC.md and this handoff, then execute the authorized production work through the existing workflow. Use the concrete work packages and current source; do not repeat bootstrap, token-routing research or a generic whole-repository audit. Maintain a compact candidate ledger and carry work through implementation, actual Studio review, relevant advisors and verification.
>
> Target September 12 and 30–50k+ CCU. Engagement, retention and monetization drive priorities. UI/UX, gameplay gap-filling, meaningful asset creation, interactive arena features and rebuilding emotes are fully in scope. The accepted lobby is a baseline, not an exemption from further UI quality work. Preserve the human-authored static arena layout; inspect real authored content before deciding fan/spinner mechanics or animation integration. Ask when a core decision remains unresolved after inspection.
>
> Prefer the smallest readable implementation that delivers polished gameplay/UI and handles realistic failures. Pragmatic code is acceptable. Do not spend the schedule on architecture elegance, generic hardening, broad cleanup, marginal optimizations or exhaustive testing without meaningful player impact. Resolve actual match-access, scale, purchase/reward and supported-device risks. Start visible content/UI progress in parallel with bounded integrity/capacity probes.
>
> Astra owns all visual judgment and strong reasoning. Use Spark, when available, for precisely specified mechanical execution; disclose any lightweight substitution. Keep Claude subscription CLI at max effort for consequential technical review, and Gemini for independent consequential visual review. Advisors never modify repository files. Figma is direct browser/Computer Use only; Blender is native Computer Use only; Roblox Studio MCP is final integration truth. No Figma/Blender MCP. Keep useful asset creation/upload work in scope through the installed human gate, refocusing each approval window without clicking approval.
>
> The previous visual review is owner-approved; do not ask for that approval again. Review and obtain focused approval for material new visual changes. Preserve existing commercial promises and IDs; creator setup, new/repriced offerings and real purchases are owner work. All Git pushes, release PRs, deployments including staging, and place publishing remain owner-only. Prepare exact reviewed artifacts and owner actions. Earlier AGENTS.md instructions were revoked; do not restore or use their Git version. Protect owner changes and unsaved app work.
>
> Begin with current Git/Studio identity and necessary integration checks, the accepted comparison, and the first implementation batch in the spec. Do not claim the game is ready from screenshots, test counts or simulated CCU. Report the tested envelope, blockers and exact remaining owner actions.

Recommended main-task setting: **GPT-6 Astra / Extra High (`xhigh`)**. The model/effort recommendation and advisor configuration are already resolved in the spec.

## Immediate state to preserve

Workspace branch: `tooling/agent-workflow`. Approved source revision: `faedbc3cd4be7b0e5a4a521511b30fdf3e3687f2`; previous handoff commit `8cdd931`. Recheck current status rather than assuming HEAD or Studio instance IDs.

Owner changes present before planning:

```text
 D AGENTS.md
 M docs/ART_STYLE.md
 D docs/RECOVERY.md
 D docs/SECURITY_AUDIT.md
```

Do not stage/restore/overwrite those changes. Planning documentation is separately modified; no gameplay implementation was performed in this planning pass.

Accepted comparison: `.review/visual-release/comparison/index.html`. Exact owner approval: `.review/visual-release/owner-visual-approval.json`. Current evidence has the white-lettered cyan Join/Invite, larger pink Play, matching sliced corners and measured/optically aligned logo. Historical rejected treatments remain available only for comparison.

Lobby place `130584867985467`, Rojo `lobby.project.json` port34873; arena `121997450145716`, `arena.project.json` port34872. Both Studios were last left in Edit. Mock cleanup is recorded in `.review/visual-release/consistency-pass/cleanup.json`. No authored base `.rbxl` exists in either checkout place directory, so complete build inputs must be resolved. `STAGING_009` is not proof of isolated or correct release persistence.

Historical test evidence and advisor outcomes are in [VISUAL_RELEASE_AUDIT.md](VISUAL_RELEASE_AUDIT.md). Prior Gemini 503s and Claude max timeout are not approvals. The spec distinguishes the earlier owner visual checkpoint from the outstanding full release-purpose evidence. Do not fabricate gate records or restart unchanged failed operations blindly.

For concrete tool commands and approval recovery use [WORKFLOW_COMMANDS.md](WORKFLOW_COMMANDS.md), [TOOL_ROUTING.md](TOOL_ROUTING.md), [VISUAL_REVIEW.md](VISUAL_REVIEW.md) and [ASSET_PIPELINE.md](ASSET_PIPELINE.md). The spec supersedes historical routing/scope claims elsewhere.
