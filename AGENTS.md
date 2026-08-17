# Splat Brawl (ouch)

Roblox PvP arena brawler: dodgeball (ranged) vs. inflatable hammer (melee), FFA and TDM in one permanent Studio-authored arena. The design source of truth is `docs/Splat_Brawl_GDD.md`; `docs/dodgeball-studio-setup.md` covers manual Studio-side asset setup.

## Hard rules — read before writing any code

1. **No excessive commentary.** Inline comments are for constraints and invariants that cannot be understood by reading the code — nothing else. No comments narrating what a line does, no "changed X to Y" commentary, no section banners. Match the existing style: a short block comment at the top of a module stating its responsibility and invariants, then near-zero inline comments.

2. **Never use `:FindFirstChild()` for Studio-authored assets that must exist at runtime** (sounds, animations, templates, map folders, UI views, etc.). Use `:WaitForChild()` — if the asset is missing, the infinite-yield warning / error is the *correct* behavior and surfaces the setup problem. `FindFirstChild` silently hides missing assets. `FindFirstChild` is acceptable only for things that legitimately may not exist (e.g. `character:FindFirstChild("HumanoidRootPart")` during death/streaming, optional runtime state). Follow the existing pattern: `WaitForChild` then `assert(x:IsA(...), "[Service] path must be a T")`.

3. **Never use `Instance.new()` to create gameplay assets** — no code-built dodgeballs, hammers, UI screens, buttons, effects, or sounds unless specifically directed. All gameplay assets are authored in Studio and cloned (`BallService` clones the configured default under `ReplicatedStorage.Assets.Cosmetics.BallAssets`; UI clones view/element templates via `ElementFactory.cloneMount`). If a needed asset does not exist yet, **tell the user exactly where it should live in the hierarchy and what properties/children it needs** (as `docs/dodgeball-studio-setup.md` does), or ask how they want it structured. `Instance.new` is fine only for non-gameplay infrastructure: organizational Folders (`Remotes`, `Balls`, `MatchState`), RemoteEvents/Functions, `InputContext`/`InputAction`/`InputBinding`, physics constraints for ragdolls, invisible markers/waypoints.

4. **One source of truth per piece of state; simple, single-responsibility modules.** This codebase is built around explicit single-owner state and the doc comments name the owner (e.g. ball possession lives *only* in `ProjectileState.phase/heldBy`; alive/dead lives *only* in the `CombatAlive` attribute; profile `Cosmetics.*` is written *only* by CosmeticsService). Never introduce a second copy of state that can drift, race, or mismatch — derive, don't duplicate. Keep functions small and pure where possible, push side effects to the owning service, and handle edge cases (player leaves mid-match, character missing, profile not yet loaded, duplicate events, latency) deliberately — existing code dedupes events, uses generation counters to cancel stale timers, and pcalls listener dispatch for a reason.

5. **Make zero architectural guesses.** If the plan, scope, or prompt leaves an architectural decision open (where state lives, which layer owns a behavior, hierarchy of a new Studio asset, a new remote's shape), do not pick one silently — ask the user what the intention or decision should be. Guessing is only acceptable when the user has specifically directed it.

Also: **never rewrite `game.rbxl` with repository tooling.** It is a Git LFS binary edited only in Studio.

## Toolchain & commands

Tools are pinned in `aftman.toml` (rojo, wally, lune, stylua, selene, rbxcloud). Run everything from the repo root.

```sh
wally install                                      # populate Packages/ (gitignored)
lune run src/scripts/lune/run-tests.luau           # run all specs headlessly (regenerates sourcemap.json via rojo)
bash src/scripts/shell/lint.sh src                 # selene lint canonical arena/shared code
bash src/scripts/shell/lint.sh places/lobby/src    # selene lint lobby code
bash src/scripts/shell/check-format.sh src
bash src/scripts/shell/check-format.sh places/lobby/src
```

CI (`.github/workflows/cicd.yml`) runs lint, format check, and the Lune tests on every PR to `main`/`prod`; a PR to `prod` also builds and publishes to Roblox.

## Layout

This repository owns both Roblox places. Always pass the project file explicitly:
`arena.project.json` serves only place `121997450145716` on port `34872`, and
`lobby.project.json` serves only place `130584867985467` on port `34873`.
Each project also blocks the other place ID. Do not add a `default.project.json`.

| Filesystem | DataModel |
|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` |
| `src/config/` | `ReplicatedStorage.Config` |
| `Packages/` | `ReplicatedStorage.Packages` |
| `src/server/` | Arena server plus canonical data/economy services used by both places |
| `src/client/` | Arena client |
| `places/lobby/src/server/` | Lobby server and matchmaking |
| `places/lobby/src/client/` | Lobby client |
| `places/lobby/src/shared/Matchmaking/` | Lobby matchmaking protocol/config |

Arena entry points: `src/server/init.server.luau` (PlayerData load/save lifecycle only), `src/server/Scripts/SimulationServer.server.luau` (starts all services, wires sim events to animations/feedback), `src/client/Scripts/SimulationClient.client.luau` (starts all client modules). Lobby entry points: `places/lobby/src/server/Server.server.luau`, `places/lobby/src/server/Scripts/MatchmakingScript.server.luau`, and `places/lobby/src/client/Scripts/LobbyClient.client.luau`.

## Systems

### Deterministic combat sim — `src/shared/Game/Sim/`

`SimCore.step` is a pure fixed-tick function run identically by client prediction and server authority. It owns no engine state: characters and geometry arrive in a `WorldSnapshot`, time is the tick counter, results leave as mutated `SimState` plus an ordered `SimEvent` list.

- **Determinism rules:** no `Instance` access, no wall clock, no unordered iteration — always `SimUtil.sortedKeys` over keyed tables. Predicates shared across weapons and projectiles (`sameTeam`, `hasLineOfSight`, `hasHandBall`, `pushEvent`) live in `SimUtil` so every module applies identical rules — don't re-implement them locally. Input commands are canonically sorted so server resimulation agrees with the predicting client regardless of arrival order.
- **Weapons** implement the `WeaponKit` interface (`kind`, `commands` routing set, `init`, `handleInput`, `tickPlayer`, optional `tickWorld`) and register in `WeaponRegistry`. Adding a weapon = one kit module + one registry entry; sim core, adapter, and netcode do not change.
- `Weapons/Dodgeball.luau`: ball possession has exactly one source of truth — `ProjectileState` (`phase == "Held"` + `heldBy`). Kit state holds cooldowns plus the transient catch window and direction; it never duplicates possession. Aim assist / homing parameters come from `Config.AimAssist`, keyed by device class (Mouse/Touch).
- `Weapons/Hammer.luau`: kit state is a small phase machine (cooldown → active dash → recovery). The recovery window is the GDD's whiff-punish mechanic — do not remove it.
- `Projectiles.luau`: generic swept-projectile subsystem — fixed-tick kinematics, homing steering, swept-sphere vs. capsules and static AABBs, substepped (max 8) to prevent tunneling. Projectile phases: `Held | Windup | InFlight | Bouncing | Rolling | Free`. Archetype params live in `Config.Combat`.
- `MatchSim.luau`: pure match phase machine (`Idle → Starting → Active → Results → Intermission`) parameterized by the active mode's `MatchRules`; it decides scores and match flow only. Consequences such as respawns and arena teleports are applied by MatchService.

### Netcode / adapters — `src/shared/Game/Adapters/`

`ServerAuthAdapter` is the single bridge between the sim and the engine: one BindToSimulation callback initialized on both client and server that decodes `SimState` from predicted instances, reads `InputAction` state, runs `SimCore.step`, and encodes back. The engine owns prediction, rollback, and resimulation — never hand-roll any of those.

`PlayerIds` is the single owner of the sim player-id convention (UserId as string): every translation between a `Player` and a sim/event id goes through `toId`/`fromId`/`fromEvent` — never `tostring(player.UserId)` inline. `EventDedup` is the shared dedup guard for sim/match event consumers (`EventDedup.new(cap?)` → `markSeen(event)`/`clear()`); every event consumer that must not double-apply a side effect uses it instead of a hand-rolled seen-table.

`SimStateCodec`: attributes on predicted instances are the between-tick source of truth (the engine rolls them back on misprediction). Attribute names are deliberately short (`ph`, `hb`, `ow`, `er`, `ft`, `vel`) because of replication limits (first 64 attributes, ≤50-char names). Ball position is *not* an attribute — it lives in the part's CFrame, which has Simulation Access and is predicted natively.

**Security invariant (GDD §8):** hits, catches, eliminations, and respawn timing are server-authoritative. Clients send inputs and render feedback; never trust client raycasts or client-reported hits.

### Match orchestration — `src/server/Modules/`

- **MatchService** (the largest service) drives `MatchSim` with the selected mode's rules and owns the match lifecycle: arena teleports, ball provisioning via mode hooks, elimination consequences, and respawn scheduling. Only ModeVoteService (plus explicit developer/test tooling) calls its server-only `beginMode(modeId)` seam. Replicated UI surface: `ReplicatedStorage.MatchState` folder attributes (`phase`, `timeRemaining`, `winnerId`, `modeId`), per-player `MatchScore` attribute, leaderstats `Elims`, and `MatchService.onEvent` for killfeed-style consumers. Respawns use per-player generation counters so a new death/leave cancels a stale scheduled respawn; TDM uses synchronized wave respawns (`WaveRespawnSeconds`).
- **ModeVoteService**: sole owner of the 10-second authoritative ballot, deadline, counts, and random tie/no-vote resolution. It projects coherent snapshots through `ReplicatedStorage.ModeVoteState`, projects each accepted selection through the player's `ModeVoteSelection` attribute, and accepts only admitted players and validated mode IDs over `SubmitModeVote`. Stale unavailable options from an older lobby server are ignored as long as at least one registered option remains. The React UI derives from those projections and never updates optimistically.
- **Modes** (`src/shared/Game/Modes/`) implement `GameMode` (`MatchRules` + server-only hooks receiving only ball provisioning, player, and team levers). Registered in `ModeRegistry` (FFA and TDM); Infection has disabled presentation metadata only. `PartyTeamAllocator` keeps lobby parties together while minimizing TDM imbalance. Rules are shared modules so tests and client UI can read them.
- **EliminationService**: the `CombatAlive` character attribute is the single source of truth for alive/dead (nil/true = alive, false = eliminated). It never touches native Humanoid health or `LoadCharacter`. Also owns the ragdoll (BallSocket constraints with per-joint limits) and restore.
- **BallService**: the *sole* creator of ball instances — clones the configured Studio-authored default from `ReplicatedStorage.Assets.Cosmetics.BallAssets` into `Workspace.Balls`. Match modes grant one persistent held ball per entrant. Provisioning is outside the deterministic sim (not input-driven); balls join the sim as replicated instances.
- **ArenaService**: validates the permanent Studio-authored `Workspace.Assets.Arena` with `Map`, `Scriptables`, `PlayerSpawns`, and `TeamSpawns.Red`/`Blue`. It caches direct-child spawn parts and teleports players without cloning, reparenting, or destroying arena content.
- **ArenaSessionService**: validates lobby TeleportData when players arrive and owns the arena server's immutable matchmaking-session identity, admission state, and party identity. Party identity survives a disconnect for same-server reconnection; malformed or mismatched arrivals are excluded from voting and gameplay. Direct joins remain valid but do not invent session state.
- **MovementSpeedService**: the *sole* writer of `Humanoid.WalkSpeed` — named multiplicative modifiers (`setModifier`/`clearModifier`/`applyTimedModifier`) compose over a captured base speed; never set WalkSpeed directly elsewhere.
- **MapFeatureService**: server-side terrain features — bounce pads launch along the pad's UpVector (server-set velocity, predicts cleanly), foam pits slow movement while a root is inside the volume (via a MovementSpeedService modifier).
- **InputSetup**: materializes the declarative map in `Config.Input` as an `InputContext`/`InputAction`/`InputBinding` tree under each Player (contexts must be Player descendants for engine ownership/replication). Owns the validated `DeviceClass` attribute the adapter stamps onto commands.

### Data & economy — `src/server/Modules/`

- **PlayerData**: ProfileStore profiles (template in `Config.Data`, store key in `src/server/Env.luau`) replicated to the owning client via Replica (token `"GameProfile"`). Exposes a write-through proxy so mutations replicate automatically; go through PlayerData's API (`get`, `addCash`, progression deltas), never a second cache of profile data.
- **ProgressionService**: accumulates per-match progress (elims, deaths, catches, wins, XP, cash) from match events — with event dedup — and commits via PlayerData. XP/Cash award values live in `Config.Data`.
- **QuestService**: server owner of quest state (stored in the profile under `Quests`, daily reset key). Consumes match/sim events with dedup keys; pure rules live in `src/shared/Game/Quests/QuestLogic.luau`. Remotes: `GetQuestState`, `ClaimQuest`, `QuestStateChanged`. Rewards granted through **RewardService** (currently Cash only).
- **CosmeticsService**: the *only* writer of profile `Cosmetics.*`. The profile is the source of truth; `Equip_<Slot>` player attributes are a read-only projection so every client can render other players' equips.
- **CrateService**: two purchase paths — Cash via the `OpenCrate` remote, Robux via MonetizationService receipts — sharing one roll-and-grant routine; every open fires `CrateOpened`. The roll itself is pure (`src/shared/Game/Economy/CrateRolls.luau`, injected `Random`) so tests pin distributions and the dupe-refund rule.
- **MonetizationService**: owns `ProcessReceipt`. Receipts are recorded in the profile for idempotency (retry after grant returns `PurchaseGranted` without re-granting); unknown products/failures return `NotProcessedYet` so Roblox retries. New product types register a handler in its `handlers` table.

**No competitive advantage:** nothing purchasable may affect combat outcomes — no weapon, movement, damage, cooldown, or health value is ever for sale (GDD §2, §7). Progression boosters (XP/Cash multipliers) are permitted and live in `GamePasses.Boosts`; they change earn *rate* only. If a proposed offer would change who wins a fight, it is out of scope regardless of how it is framed.

### Client — `src/client/Modules/`

- **Input/**: `InputRouter` feeds `AimDirector`'s aim into the `Aim` InputAction every frame, pulses `Throw` on touch taps, and reports mouse, touch, or gamepad device class. It releases the centered mouse only while the authoritative mode vote is open. `AimDirector` owns aim/soft-lock target selection.
- **Presentation/** (BallVisuals, HammerVisuals, DamageFeedback, DeathEffects, WorldAudio; CharacterRig owns rig-name lookups like the R15/R6 right-hand fallback): rendering and audio feedback *only* — they react to sim events, attributes, and remotes and hold no gameplay authority. Effects on the ball template (trails, emitters, sounds) are Studio-authored and enabled/disabled by phase; must not replay during rollback corrections (test at 0/100/150/200 ms latency per `docs/dodgeball-studio-setup.md`).
- **UI/**: the Studio-authored live scoreboard remains imperative. `ArenaApp` is the arena React root and renders the shared `GameModeSelect` from `ModeVoteClient`'s derived replicated snapshot. Presentational components never require Network or own gameplay state; client-to-server actions stay in the arena adapter. Shared interaction, responsive text, feedback, and motion primitives live under `src/shared/UI`.

### Networking — `src/shared/Network.luau`

The single place remotes are declared: add to its `definitions` table (name → `"event" | "function" | "unreliable"`) instead of creating ad-hoc RemoteEvents. Server handlers get per-player rate limiting via `checkRateLimit` — keep limits on any new client-invokable remote.

### Config — `src/config/`

All tunables live here and nowhere else: combat feel (`Combat`, cmdr-tunable at runtime; units are studs/seconds/degrees), aim assist per device class (`AimAssist`), input map (`Input`), game-mode vote metadata/timing (`GameModes`), arena features (`MapFeatures`, pending the `Scriptables` pass), data template + XP/Cash tables (`Data`), quests, cosmetics, crates, products, UI, debug flags. New gameplay constants go in the matching config module, not inline.

## Testing

Specs live in `src/shared/Tests/*.spec.luau` and use `TestKit` — a minimal pure-Luau describe/it/expect (not TestEZ; expectations: `toEqual`, `toBeNear`, `toBeTruthy`, `toBeNil`) — so they run headlessly under Lune through the fake-Instance loader in `src/scripts/lune/`. `MockWorld` builds AABB `WorldSnapshot`s for sim tests. Anything in `Sim/`, `Modes/`, `Economy/`, or `Quests/` is pure and must stay runnable this way — if new shared logic needs engine APIs, put that part in an adapter or service instead. Selene excludes `*.spec.luau`. Add or extend a spec whenever you touch pure logic.

## Conventions

- Luau with `--!strict` at the top of modules; tab indentation; StyLua-formatted (`stylua src places/lobby/src`).
- Services/modules are plain tables with functions; a `start()` guards against double-start with a `started` flag.
- Comments follow rule 1: module-top responsibility/invariant blocks, minimal inline.
- Selene (`std = "roblox"`) with `unused_variable` allowed.
