# Ouch! Development Conventions

## 1. Philosophy
**The four highest product priorities are monetization, engagement, retention, and concurrent player count (CCU).** These take precedence over code elegance, architectural purity, strict validation for its own sake, and implementation convenience. Judge product and system design by its effect on those four outcomes. Preserve the existing server-authority, ownership, purchase, and data-integrity contracts that make those outcomes sustainable.

**Keep players playing, even when gameplay is degraded or broken.** Missing sounds, images, decals, fonts, animations, cosmetic effects, and even gameplay errors should default to bounded waits, useful diagnostics, isolated failures, and as much continued play as possible. Do not automatically substitute a failure screen or deny match entry because a check failed. Showing a failure screen or deliberately blocking match entry requires Jack's explicit approval, including for gameplay-critical errors. Agents must not infer that approval from permission to implement a feature or fix a bug. Test failure and timeout paths for continued play. Preserve purchase, ownership, server-authority, and data-integrity protections; continued play does not authorize granting purchases, corrupting saves, or accepting untrusted game state.

**Example to prevent repeating:** Arena asset preloading once promoted font/audio/image fetch failures into fatal startup errors. An optional media request could lock players out of the entire match, including during an asset-delivery outage. That design directly violates all four product priorities and these conventions. Correct request types, graceful degradation, and regression coverage are required; successful asset delivery alone is not proof that the startup design is acceptable.

**Simplicity over sophistication.** This codebase is maintained by one person. Agents must write simpler code, not more complicated code. Abstraction should reduce complexity, not add layers.
**Player-facing quality over code elegance.** The player experience is what matters. Implementation elegance behind the scenes is secondary.
**Pragmatism over purity.** It's acceptable to use approaches that might be considered "bad practice" if the "correct" alternative would waste significant tokens and effort while producing the same player-facing result.
**Don't over-engineer.** This is a Roblox game, not a massive AAA production with project designers and a large staff. Code should be as simple as it can be while still working correctly.
**Reduce, don't expand.** The codebase needs refinement and simplification. When touching existing code, look for opportunities to simplify. Don't add complexity without justification.

## 2. Luau Patterns
- **Module Structure**: Modules are straightforward dictionaries (`local Module = {} ... return Module`), not object-oriented classes. 
- **Type Annotations**: Use `--!strict` at the top of every file. Define and export types (`export type`) at the top of the file for public interfaces.
- **Naming Conventions**: 
  - `PascalCase` for files, modules, and types.
  - `camelCase` for variables and functions.
- **Error Handling**: Functions that can fail should return `(boolean, string?)` for `(success, reason)` rather than throwing errors.

## 3. React & UI Patterns
- **Functional Components**: UI components are simple functional components returning React elements. Use the `local c = React.createElement` alias pattern to reduce verbosity.
- **Hooks**: Custom hooks live in `src/shared/UI/Hooks/`, use the `use` prefix, and return tables of mapped bindings (e.g., `useButtonMotion.luau`).
- **Stories**: UI components are accompanied by `*.story.luau` files for isolated testing in tools like Hoarcekat or Storybook.
- **Visuals**: See `docs/STYLE.md` for visual rules. Never invent colors/metrics; always import and use `src/shared/UI/Tokens.luau` (`T.Colors`, `T.Shape`, `T.Layout`).

## 4. Testing
- **Framework**: TestEZ.
- **File Naming**: Tests are named `*.spec.luau`.
- **Location**: Test files live under `places/{arena,lobby}/tests/` or `src/tests/Shared/`.
- **Execution**: Run tests locally in-Studio, or headless via Lune using `lune run src/scripts/lune/run-tests.luau`.
- **Helpers**: Shared test scaffolding (like `FakePlayer.luau`, `MockWorld.luau`) lives in `src/tests/Helpers/`.

## 5. Configuration
- **Location**: All game data and tuning lives under `src/config/`.
- **Structure**: Config files are pure Luau dictionaries (`return { ... }`) holding constants, avoiding nested logic.
- **Categories**: Settings are organized into `Cosmetics`, `Economy`, `Gameplay`, `Infra`, `Interface`, and `Progression`.

## 6. Build & Tooling
- **Rojo (7.7.0)**: File syncing. Two project files (`arena.project.json`, `lobby.project.json`) serve different places; ensure both stay in sync for shared module paths.
- **Wally (0.3.2)**: Package management (`wally.toml`).
- **Lune (0.10.5)**: Task runner. Scripts are in `src/scripts/lune/`.
- **StyLua (2.5.2)**: Code formatting.
- **Selene (0.31.0)**: Linting. (Upstream `PlayerModule` files are deliberately excluded).
- **rbxcloud (0.17.0)**: Cloud API CLI.
- **Python Tools**: Found in `tools/`, these handle asset pipelines, visual review, and deployment helpers.

## 7. File Organization
| Type | Location |
|---|---|
| New shared game logic | `src/shared/Game/{Subsystem}/` |
| New UI components | `src/shared/UI/Components/` |
| New server modules | `src/server/Modules/` (Ensure it is mapped in both project JSON files) |
| Place-specific code | `places/{arena,lobby}/` |
| Configuration | `src/config/{Category}/` |
| Tests | Alongside place code or in `src/tests/Shared/` |

## 8. Things NOT To Do
- **DON'T** modify the upstream PlayerModule files (under `src/client/PlayerModule/CameraModule/`, `ControlModule/`, `CommonUtils/`, `ServerAuthority/`, `init.luau`). Additions under `Combat/` are fine.
- **DON'T** invent new visual palettes — use `Tokens.luau` and the candy system from `docs/STYLE.md`.
- **DON'T** create task-specific docs in `docs/`. Put task evidence and docs in `.review/agent-workflow/tasks/<ID>/`; finished tasks move to `.review/agent-workflow/archive/<ID>/` (see "Artifact layout" in `AI_AGENT_WORKFLOW.md`).
- **DON'T** duplicate Rojo project paths independently — both project.json files must stay in sync for shared modules.
- **DON'T** add packages without updating `wally.toml`.
- **DON'T** bypass server authority for economy, progression, or cosmetic ownership.
