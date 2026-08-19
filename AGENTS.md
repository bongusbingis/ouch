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
bash src/scripts/shell/lint.sh src                 # selene lint shared code
bash src/scripts/shell/lint.sh places/arena        # selene lint arena code
bash src/scripts/shell/lint.sh places/lobby        # selene lint lobby code
bash src/scripts/shell/check-format.sh src
bash src/scripts/shell/check-format.sh places/arena
bash src/scripts/shell/check-format.sh places/lobby
```

CI (`.github/workflows/cicd.yml`) runs lint, format check, and the Lune tests on every PR to `main`/`prod` regardless of what changed. A PR to `prod` additionally deploys, but only the places the change affects: `places/arena/**` deploys the arena, `places/lobby/**` deploys the lobby, and anything under `src/**` (or the toolchain) deploys both, since both places load it. Each deployed place builds, merges into the currently-live place, uploads a Saved version, runs **that place's own** `ServerStorage.Tests` suite through the Open Cloud Luau Execution API, and publishes only on green. Both places therefore need an in-place suite: shared harness in `src/tests/` (`Runner`, `Helpers`), place-specific specs in `places/<place>/tests/`.

## Layout

This repository owns both Roblox places. Always pass the project file explicitly:
`arena.project.json` serves only place `121997450145716` on port `34872`, and
`lobby.project.json` serves only place `130584867985467` on port `34873`.
Each project also blocks the other place ID. Do not add a `default.project.json`.

| Filesystem | DataModel |
|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` (both places) |
| `src/config/` | `ReplicatedStorage.Config` (both places) |
| `src/server/` | Server modules **both places load**: PlayerData, ConfigLiveService, CosmeticsService, CharacterColorService, AnalyticsService, and `Env` |
| `src/scripts/` | Tooling; not mapped into either place |
| `src/tests/` | Shared in-place test harness (`Runner`, `Helpers`), mapped into both places' `ServerStorage.Tests` |
| `Packages/` | `ReplicatedStorage.Packages` |
| `places/arena/server/` | Arena `ServerScriptService.Server` |
| `places/arena/client/` | Arena `StarterPlayerScripts.Client` |
| `places/arena/tests/` | Arena-specific specs, merged into `ServerStorage.Tests` |
| `places/lobby/server/` | Lobby `ServerScriptService.Server` |
| `places/lobby/client/` | Lobby `StarterPlayerScripts.Client` |
| `places/lobby/shared/Matchmaking/` | Lobby-only `ReplicatedStorage.Shared.Matchmaking` |
| `places/lobby/tests/` | Lobby-specific specs, merged into `ServerStorage.Tests` |

`src/` is shared by both places and nothing else; anything place-specific lives under `places/`. The shared server modules stay in `src/server/` and are mapped into each place's `Server.Modules` by both project files, so a module's location tells you whether the lobby depends on it.

Arena entry points: `places/arena/server/Server.server.luau` (PlayerData load/save lifecycle only), `places/arena/server/Scripts/SimulationServer.server.luau` (starts all services, wires sim events to animations/feedback), `places/arena/client/Scripts/SimulationClient.client.luau` (starts all client modules). Lobby entry points: `places/lobby/server/Server.server.luau`, `places/lobby/server/Scripts/MatchmakingScript.server.luau`, and `places/lobby/client/Scripts/LobbyClient.client.luau`.

## Systems

### Deterministic combat sim — `src/shared/Game/Sim/`

`SimCore.step` is a pure fixed-tick function run by the authoritative server. It owns no engine state: characters and geometry arrive in a `WorldSnapshot`, time is the tick counter, results leave as mutated `SimState` plus an ordered `SimEvent` list.

- **Determinism rules:** no `Instance` access, no wall clock, no unordered iteration — always `SimUtil.sortedKeys` over keyed tables. Predicates shared across weapons and projectiles (`sameTeam`, `hasLineOfSight`, `hasHandBall`, `pushEvent`) live in `SimUtil` so every module applies identical rules — don't re-implement them locally. Input commands are canonically sorted so server resimulation agrees with the predicting client regardless of arrival order.
- **Weapons** implement the `WeaponKit` interface (`kind`, `commands` routing set, `init`, `handleInput`, `tickPlayer`, optional `tickWorld`) and register in `WeaponRegistry`. Adding a weapon = one kit module + one registry entry; sim core, adapter, and netcode do not change.
- `Weapons/Dodgeball.luau`: ball possession has exactly one source of truth — `ProjectileState` (`phase == "Held"` + `heldBy`). Kit state holds cooldowns plus the transient catch window and direction; it never duplicates possession. Aim assist / homing parameters come from `Config.AimAssist`, keyed by device class (Mouse/Touch).
- `Weapons/Hammer.luau`: kit state is a small phase machine (cooldown → active dash → recovery). The recovery window is the GDD's whiff-punish mechanic — do not remove it.
- `Projectiles.luau`: generic swept-projectile subsystem — fixed-tick kinematics, homing steering, swept-sphere vs. capsules and static AABBs, substepped (max 8) to prevent tunneling. Projectile phases: `Held | Windup | InFlight | Bouncing | Rolling | Free`. Archetype params live in `Config.Combat`.
- `MatchSim.luau`: pure match phase machine (`Idle → Starting → Active → Results → Intermission`) parameterized by the active mode's `MatchRules`; it decides scores and match flow only. Consequences such as respawns and arena teleports are applied by MatchService.

### Netcode / adapters — `src/shared/Game/Adapters/`

`ServerAuthAdapter` is the single bridge between the sim and the engine, and runs **server-side only**: a fixed 60Hz accumulator on `Heartbeat` decodes `SimState` from the ball instances, turns queued client intents into sim commands, runs `SimCore.step`, and encodes back. Clients send throw/catch intent over `SubmitCombatInput` and nothing else; the aim origin is taken from the player's own root on the server, never from the client. Resulting events are broadcast over the unreliable `CombatSimEvent` remote for presentation only.

Weapon animations are started by the acting player's own client (`WeaponAnimations`, fed by `CombatInputSender.onIntent`) so they are not delayed by a round trip; playback on the local character replicates outward and stays the only copy. The server must not also play them, or they restart on the actor. `WeaponAnimations` mirrors `WeaponRegistry` order to pick which weapon a `Throw` press belongs to (Dodgeball while a ball is held, Hammer otherwise) — adding a weapon adds a row there alongside its kit and registry entry.

`PlayerIds` is the single owner of the sim player-id convention (UserId as string): every translation between a `Player` and a sim/event id goes through `toId`/`fromId`/`fromEvent` — never `tostring(player.UserId)` inline. `EventDedup` is the shared dedup guard for sim/match event consumers (`EventDedup.new(cap?)` → `markSeen(event)`/`clear()`); every event consumer that must not double-apply a side effect uses it instead of a hand-rolled seen-table.

`SimStateCodec`: attributes on the ball instances are the between-tick source of truth and replicate to clients for presentation. Attribute names are deliberately short (`ph`, `hb`, `ow`, `er`, `ft`, `vel`) because of replication limits (first 64 attributes, ≤50-char names). Ball position is *not* an attribute — it lives in the part's CFrame, set by the server each tick and replicated natively; `BallVisuals` smooths it with `Combat.Dodgeball.RemoteSmoothing`.

**Security invariant (GDD §8):** hits, catches, eliminations, and respawn timing are server-authoritative. Clients send inputs and render feedback; never trust client raycasts or client-reported hits.

### Match orchestration — `src/server/Modules/`

- **MatchService** (the largest service) drives `MatchSim` with the selected mode's rules and owns the match lifecycle: arena teleports, ball provisioning via mode hooks, elimination consequences, and respawn scheduling. Only ModeVoteService (plus explicit developer/test tooling) calls its server-only `beginMode(modeId)` seam. Replicated UI surface: `ReplicatedStorage.MatchState` folder attributes (`phase`, `timeRemaining`, `winnerId`, `modeId`), per-player `MatchScore` attribute, leaderstats `Elims`, and `MatchService.onEvent` for killfeed-style consumers. Respawns use per-player generation counters so a new death/leave cancels a stale scheduled respawn; TDM uses synchronized wave respawns (`WaveRespawnSeconds`).
- **ModeVoteService**: sole owner of the 10-second authoritative ballot, deadline, counts, and random tie/no-vote resolution. Opening the ballot waits for admitted players to report ready, capped by `GameModes.ClientReadyWaitSeconds` and armed at most once per ballot, so a client that never reports delays a match by that cap and no more. It projects coherent snapshots through `ReplicatedStorage.ModeVoteState`, projects each accepted selection through the player's `ModeVoteSelection` attribute, and accepts only admitted players and validated mode IDs over `SubmitModeVote`. Stale unavailable options from an older lobby server are ignored as long as at least one registered option remains. The React UI derives from those projections and never updates optimistically.
- **Modes** (`src/shared/Game/Modes/`) implement `GameMode` (`MatchRules` + server-only hooks receiving only ball provisioning, player, and team levers). Registered in `ModeRegistry` (FFA and TDM); Infection has disabled presentation metadata only. `PartyTeamAllocator` keeps lobby parties together while minimizing TDM imbalance. Rules are shared modules so tests and client UI can read them.
- **EliminationService**: the `CombatAlive` character attribute is the single source of truth for alive/dead (nil/true = alive, false = eliminated). It never touches native Humanoid health or `LoadCharacter`. Also owns the ragdoll (BallSocket constraints with per-joint limits) and restore.
- **BallService**: the *sole* creator of ball instances — clones the configured Studio-authored default from `ReplicatedStorage.Assets.Cosmetics.BallAssets` into `Workspace.Balls`. Match modes grant one persistent held ball per entrant. Provisioning is outside the deterministic sim (not input-driven); balls join the sim as replicated instances.
- **ArenaService**: validates the permanent Studio-authored `Workspace.Assets.Arena` with `Map`, `Scriptables`, `PlayerSpawns`, and `TeamSpawns.Red`/`Blue`. It caches direct-child spawn parts and teleports players without cloning, reparenting, or destroying arena content.
- **ArenaSessionService**: validates lobby TeleportData when players arrive and owns the arena server's immutable matchmaking-session identity, admission state, and party identity. Party identity survives a disconnect for same-server reconnection; malformed or mismatched arrivals are excluded from voting and gameplay. It also owns client readiness: a client fires `ArenaClientReady` once its UI is mounted, projected as the `ArenaReady` player attribute, so the vote is not spent before arriving players can see it. Direct joins remain valid but do not invent session state.
- **ArenaReturnService**: at `MatchReset`, once the results screen has played, returns lobby-originated players to `Env.LobbyPlaceId` grouped one teleport per party, carrying a `ReturnPayload` (party id, match id, member user ids). The decision is **per player**: a player with a party identity goes back, a direct join is left alone and the vote reopens for them, so deleting the lobby is a configuration change rather than a rewrite. A failed teleport leaves the group in the arena on the normal loop. The lobby consumes the payload in `PartyService:_resolveArrivalTarget`, rejoining the original party record when it survived and otherwise regrouping on whichever member arrived first — returning members are not friend-gated, unlike invites.
- **MovementSpeedService**: the *sole* writer of `Humanoid.WalkSpeed` — named multiplicative modifiers (`setModifier`/`clearModifier`/`applyTimedModifier`) compose over a captured base speed; never set WalkSpeed directly elsewhere.
- **MapFeatureService**: drives the authored features under `Workspace.Assets.Arena.Scriptables` from one Heartbeat. Each kit in `src/server/Modules/MapFeatures/` owns one folder there and implements `MapFeatureKit` (`folderName`, optional `tickPlayer`/`tickWorld`/`forget`), registered in `MapFeatureRegistry` — adding a feature is one module plus one registry entry, mirroring `WeaponKit`/`WeaponRegistry`. Shipped kits: `ElimZones` (immediate elimination via the `MatchService.eliminate` seam, so scoring/feed/respawn stay in one place), `BouncePads` (launch along the pad's UpVector, server-set velocity that predicts cleanly), `FoamPits` (slow via a MovementSpeedService modifier). Membership is a volume test on the root (`src/shared/Game/MapFeatures/Volume.luau`, spec-tested), not a touch trigger, and folders are re-read on change so parts can move or spawn at runtime.
- **RotatingPlatforms** (`src/shared/Game/MapFeatures/`) spins the assemblies under `Scriptables.Rotating`. Each assembly is a folder holding an `Origin` BasePart (the axis) and an `Assembly` Model that turns about Origin's up axis. It is deliberately *not* a MapFeatureKit: clients need the registry even though only the server moves anything. `startMover` is server-only and clients call `load` — two sides writing the same anchored assembly fight each other, which reads as violent stutter rather than rotation. The pose is a pure function of `Workspace:GetServerTimeNow()` (`Rotation.angleAt`, spec-tested) rather than accumulated frame deltas, so it never drifts. `PlatformRider` (client) carries the local character with the platform it rides, including while airborne over its footprint so a jump lands in the same relative spot; position only, never facing. It measures the delta from the assembly's own pose frame over frame, so replication lag cannot desync the carry from what the player is standing on.
- **InputSetup**: materializes the declarative map in `Config.Input` as an `InputContext`/`InputAction`/`InputBinding` tree under each Player (contexts must be Player descendants for engine ownership/replication). Owns the validated `DeviceClass` attribute the adapter stamps onto commands.

### Data & economy — `src/server/Modules/`

- **PlayerData**: ProfileStore profiles (template in `Config.Data`, store key in `src/server/Env.luau`) replicated to the owning client via Replica (token `"GameProfile"`). Exposes a write-through proxy so mutations replicate automatically; go through PlayerData's API (`get`, `addBonks`, progression deltas), never a second cache of profile data.
- **ProgressionService**: accumulates per-match progress (elims, deaths, catches, wins, XP, bonks) from match events — with event dedup — and commits via PlayerData. XP/Bonks award values live in `Config.Data`.
- **QuestService**: server owner of quest state (stored in the profile under `Quests`, daily reset key). Consumes match/sim events with dedup keys; pure rules live in `src/shared/Game/Quests/QuestLogic.luau`. Remotes: `GetQuestState`, `ClaimQuest`, `QuestStateChanged`. Rewards granted through **RewardService** (currently Bonks only).
- **CosmeticsService**: the *only* writer of profile `Cosmetics.*`. The profile is the source of truth; `Equip_<Slot>` player attributes are a read-only projection so every client can render other players' equips.
- **CrateService**: two purchase paths — Bonks via the `OpenCrate` remote, Robux via MonetizationService receipts — sharing one roll-and-grant routine; every open fires `CrateOpened`. The roll itself is pure (`src/shared/Game/Economy/CrateRolls.luau`, injected `Random`) so tests pin distributions and the dupe-refund rule.
- **MonetizationService**: owns `ProcessReceipt`. Receipts are recorded in the profile for idempotency (retry after grant returns `PurchaseGranted` without re-granting); unknown products/failures return `NotProcessedYet` so Roblox retries. New product types register a handler in its `handlers` table.

**No competitive advantage:** nothing purchasable may affect combat outcomes — no weapon, movement, damage, cooldown, or health value is ever for sale (GDD §2, §7). Progression boosters (XP/Bonks multipliers) are permitted and live in `GamePasses.Boosts`; they change earn *rate* only. If a proposed offer would change who wins a fight, it is out of scope regardless of how it is framed.

### Client — `places/arena/client/Modules/`

- **Input/**: `InputRouter` feeds `AimDirector`'s aim into the `Aim` InputAction every frame, pulses `Throw` on touch taps, and reports mouse, touch, or gamepad device class. It releases the centered mouse only while the authoritative mode vote is open. `AimDirector` owns aim/soft-lock target selection.
- **Presentation/** (BallVisuals, HammerVisuals, DamageFeedback, DeathEffects, WorldAudio; CharacterRig owns rig-name lookups like the R15/R6 right-hand fallback): rendering and audio feedback *only* — they react to sim events, attributes, and remotes and hold no gameplay authority. Effects on the ball template (trails, emitters, sounds) are Studio-authored and enabled/disabled by phase; broadcast events can arrive more than once, so effects must deduplicate (test at 0/100/150/200 ms latency per `docs/dodgeball-studio-setup.md`).
- **UI/**: every arena UI is React; there is no imperative or Studio-authored UI left in this place. `ArenaApp` is the arena React root and renders the shared `GameModeSelect` from `ModeVoteClient`'s derived replicated snapshot. Presentational components never require Network or own gameplay state; client-to-server actions stay in the arena adapter. Shared interaction, responsive text, feedback, and motion primitives live under `src/shared/UI`.

### Networking — `src/shared/Network.luau`

The single place remotes are declared: add to its `definitions` table (name → `"event" | "function" | "unreliable"`) instead of creating ad-hoc RemoteEvents. Server handlers get per-player rate limiting via `checkRateLimit` — keep limits on any new client-invokable remote.

### Config — `src/config/`

All tunables live here and nowhere else: combat feel (`Combat`, cmdr-tunable at runtime; units are studs/seconds/degrees), aim assist per device class (`AimAssist`), input map (`Input`), game-mode vote metadata/timing (`GameModes`), arena features (`MapFeatures`, pending the `Scriptables` pass), data template + XP/Bonks tables (`Data`), quests, cosmetics, crates, products, UI, debug flags. New gameplay constants go in the matching config module, not inline.

**Live configs (`LiveConfig` + `ConfigLiveService`).** `src/config/LiveConfig.luau` is the allowlist of leaves that Roblox experience configs (`ConfigService`) may override at runtime; a leaf not declared there can never be changed live. `ConfigLiveService` (server, both places) reads the snapshot, validates every value against the declared type and range, and installs it by writing into the config table consumers already read — there is no second resolved copy to drift from it. The baked value of each leaf is captured on first override and restored exactly when the override disappears, so **the game always falls back to the values in `src/config`** when the config APIs fail, and a resync is all-or-nothing so a partial read cannot install a half-applied set. `ConfigSnapshot.UpdateAvailable` drives refreshes, with a periodic resync as a safety net.

`ConfigService` is server-only, so the active set is mirrored to clients through `ReplicatedStorage.ConfigState` (one value object per active override, named with underscores, plus a `revision` attribute bumped last as the commit signal as `ModeVoteState` does; value objects rather than attributes because replication caps an instance's total attribute payload at 1024 bytes) and re-validated client-side by `ConfigReplication`. Overrides for modules the sim reads (`LiveConfig.SimCritical`: `Combat`, `AimAssist`) are staged while a match runs and adopted at `MatchPreparing`, so combat constants never change underneath a running match. Pure rules live in `src/shared/Game/Config/` (`ConfigOverrides`, `ConfigRuntime`) and are spec-tested. See `docs/live-configs.md` for authoring and for adding a key. A config table holding a live leaf must not be `table.freeze`d.

## Testing

Specs live in `src/shared/Tests/*.spec.luau` and use `TestKit` — a minimal pure-Luau describe/it/expect (not TestEZ; expectations: `toEqual`, `toBeNear`, `toBeTruthy`, `toBeNil`) — so they run headlessly under Lune through the fake-Instance loader in `src/scripts/lune/`. `MockWorld` builds AABB `WorldSnapshot`s for sim tests. Anything in `Sim/`, `Modes/`, `Economy/`, or `Quests/` is pure and must stay runnable this way — if new shared logic needs engine APIs, put that part in an adapter or service instead. Selene excludes `*.spec.luau`. Add or extend a spec whenever you touch pure logic.

## Conventions

- Luau with `--!strict` at the top of modules; tab indentation; StyLua-formatted (`stylua src places`).
- Services/modules are plain tables with functions; a `start()` guards against double-start with a `started` flag.
- Comments follow rule 1: module-top responsibility/invariant blocks, minimal inline.
- Selene (`std = "roblox"`) with `unused_variable` allowed.
