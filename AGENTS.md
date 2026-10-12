# AGENTS.md — Ouch! agent entrypoint

Provider-neutral. Claude Code, Muse, and Codex all work from the same
documents and the same live board. Nothing here replaces those sources.

## Read first

1. `docs/AI_AGENT_WORKFLOW.md` — Prime + specialist roles, task contracts,
   leases, gates, evidence layout. Roles are vendor-neutral; follow your
   current role's contract.
2. `docs/CONVENTIONS.md` — product priorities (monetization, engagement,
   retention, CCU) and continued-play rules.
3. `docs/ARCHITECTURE.md`, `docs/SYSTEMS.md`, `docs/STYLE.md` — structure,
   system invariants, candy UI tokens.

## Live state

- Board: `.review/agent-workflow/board.json`, `completed.ndjson`,
  `decisions.md` (DEC-### series continues there).
- Task evidence: `.review/agent-workflow/tasks/<ID>/`; finished work moves to
  `archive/`. Never put task docs in `docs/` or at `.review/` root.
- Board `model` labels (`opus`/`sonnet`/`haiku`) are Claude lane hints, not
  requirements. Any agent may work any lane within its role contract.

## Boundaries

- `.claude/` belongs to Claude Code. Other agents read nothing from it and
  write nothing to it.
- Advisory review (`tools/reviewer.py`, providers `claude`/`gemini`/`muse`)
  is advisory only; Codex makes final decisions.
- Jack approvals (never infer): failure screens or match-entry blocks,
  publishing/releasing, uploads, economy/prices/probabilities/rewards,
  destructive migrations, secrets/credentials, scope widening.

## Gates

- Luau: Lune suite, StyLua, Selene, both Rojo builds.
- Python tooling: `python tools/run_safe_tests.py`.
