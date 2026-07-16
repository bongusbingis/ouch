# Splat Brawl (ouch)

Roblox PvP arena brawler: dodgeball (ranged) vs. inflatable hammer (melee), FFA and TDM on small symmetric maps. The design source of truth is `docs/Splat_Brawl_GDD.md`; `docs/dodgeball-studio-setup.md` covers manual Studio-side asset setup.

## Hard rules — read before writing any code

1. **No excessive commentary.** Inline comments are for constraints and invariants that cannot be understood by reading the code — nothing else. No comments narrating what a line does, no "changed X to Y" commentary, no section banners. Match the existing style: a short block comment at the top of a module stating its responsibility and invariants, then near-zero inline comments.

2. **Never use `:FindFirstChild()` for Studio-authored assets that must exist at runtime** (sounds, animations, templates, map folders, UI views, etc.). Use `:WaitForChild()` — if the asset is missing, the infinite-yield warning / error is the *correct* behavior and surfaces the setup problem. `FindFirstChild` silently hides missing assets. `FindFirstChild` is acceptable only for things that legitimately may not exist (e.g. `character:FindFirstChild("HumanoidRootPart")` during death/streaming, optional runtime state). Follow the existing pattern: `WaitForChild` then `assert(x:IsA(...), "[Service] path must be a T")`.

3. **Never use `Instance.new()` to create gameplay assets** — no code-built dodgeballs, hammers, UI screens, buttons, effects, or sounds unless specifically directed. All gameplay assets are authored in Studio and cloned (`BallService` clones `ReplicatedStorage.Assets.Dodgeball`; UI clones view/element templates via `ElementFactory.cloneMount`). If a needed asset does not exist yet, **tell the user exactly where it should live in the hierarchy and what properties/children it needs** (as `docs/dodgeball-studio-setup.md` does), or ask how they want it structured. `Instance.new` is fine only for non-gameplay infrastructure: organizational Folders (`Remotes`, `Balls`, `MatchState`), RemoteEvents/Functions, `InputContext`/`InputAction`/`InputBinding`, physics constraints for ragdolls, invisible markers/waypoints.

4. **One source of truth per piece of state; simple, single-responsibility modules.** This codebase is built around explicit single-owner state and the doc comments name the owner (e.g. ball possession lives *only* in `ProjectileState.phase/heldBy`; alive/dead lives *only* in the `CombatAlive` attribute; profile `Cosmetics.*` is written *only* by CosmeticsService). Never introduce a second copy of state that can drift, race, or mismatch — derive, don't duplicate. Keep functions small and pure where possible, push side effects to the owning service, and handle edge cases (player leaves mid-match, character missing, profile not yet loaded, duplicate events, latency) deliberately — existing code dedupes events, uses generation counters to cancel stale timers, and pcalls listener dispatch for a reason.

5. **Make zero architectural guesses.** If the plan, scope, or prompt leaves an architectural decision open (where state lives, which layer owns a behavior, hierarchy of a new Studio asset, a new remote's shape), do not pick one silently — ask the user what the intention or decision should be. Guessing is only acceptable when the user has specifically directed it.

Also: **never rewrite `game.rbxl` with repository tooling.** It is a Git LFS binary edited only in Studio.

## Toolchain & commands

Tools are pinned in `aftman.toml` (rojo, wally, lune, stylua, selene, rbxcloud). Run everything from the repo root.

```sh
wally install                                # populate Packages/ (gitignored)
lune run src/scripts/lune/run-tests.luau     # run all specs headlessly (regenerates sourcemap.json via rojo)
bash src/scripts/shell/lint.sh src           # selene lint
bash src/scripts/shell/check-format.sh src   # stylua --check; run `stylua src` to fix
```

CI (`.github/workflows/cicd.yml`) runs lint, format check, and the Lune tests on every PR to `main`/`prod`; a PR to `prod` also builds and publishes to Roblox.

## Layout (Rojo mapping in `default.project.json`)

| Filesystem | DataModel |
|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` |
| `src/config/` | `ReplicatedStorage.Config` |
| `Packages/` | `ReplicatedStorage.Packages` |
| `src/server/` | `ServerScriptService.Server` |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` |

Entry points: `src/server/init.server.luau` (PlayerData load/save lifecycle only), `src/server/Scripts/SimulationServer.server.luau` (starts all services, wires sim events to animations/feedback), `src/client/Scripts/SimulationClient.client.luau` (starts all client modules).

## Systems

### Deterministic combat sim — `src/shared/Game/Sim/`

`SimCore.step` is a pure fixed-tick function run identically by client prediction and server authority. It owns no engine state: characters and geometry arrive in a `WorldSnapshot`, time is the tick counter, results leave as mutated `SimState` plus an ordered `SimEvent` list.

- **Determinism rules:** no `Instance` access, no wall clock, no unordered iteration — always `SimUtil.sortedKeys` over keyed tables. Input commands are canonically sorted so server resimulation agrees with the predicting client regardless of arrival order.
- **Weapons** implement the `WeaponKit` interface (`kind`, `commands` routing set, `init`, `handleInput`, `tickPlayer`, optional `tickWorld`) and register in `WeaponRegistry`. Adding a weapon = one kit module + one registry entry; sim core, adapter, and netcode do not change.
- `Weapons/Dodgeball.luau`: ball possession has exactly one source of truth — `ProjectileState` (`phase == "Held"` + `heldBy`). Kit state holds only cooldowns. Aim assist / homing parameters come from `Config.AimAssist`, keyed by device class (Mouse/Touch).
- `Weapons/Hammer.luau`: kit state is a small phase machine (cooldown → active dash → recovery). The recovery window is the GDD's whiff-punish mechanic — do not remove it.
- `Projectiles.luau`: generic swept-projectile subsystem — fixed-tick kinematics, homing steering, swept-sphere vs. capsules and static AABBs, substepped (max 8) to prevent tunneling. Projectile phases: `Held | Windup | InFlight | Bouncing | Rolling | Recalling | Free`. Archetype params live in `Config.Combat`.
- `MatchSim.luau`: pure match phase machine (`Idle → Active → Results → Intermission`) parameterized by the active mode's `MatchRules`; it decides scores and match flow only. Consequences (respawns, teleports, maps) are applied by MatchService.

### Netcode / adapters — `src/shared/Game/Adapters/`

`ServerAuthAdapter` is the single bridge between the sim and the engine: one BindToSimulation callback initialized on both client and server that decodes `SimState` from predicted instances, reads `InputAction` state, runs `SimCore.step`, and encodes back. The engine owns prediction, rollback, and resimulation — never hand-roll any of those.

`SimStateCodec`: attributes on predicted instances are the between-tick source of truth (the engine rolls them back on misprediction). Attribute names are deliberately short (`ph`, `hb`, `ow`, `er`, `ft`, `vel`) because of replication limits (first 64 attributes, ≤50-char names). Ball position is *not* an attribute — it lives in the part's CFrame, which has Simulation Access and is predicted natively.

**Security invariant (GDD §8):** hits, catches, eliminations, and respawn timing are server-authoritative. Clients send inputs and render feedback; never trust client raycasts or client-reported hits.

### Match orchestration — `src/server/Modules/`

- **MatchService** (the largest service) drives `MatchSim` with the active mode's rules and owns the match lifecycle: map spawn, teleports, ball provisioning via mode hooks, elimination consequences, respawn scheduling. Replicated UI surface: `ReplicatedStorage.MatchState` folder attributes (`phase`, `timeRemaining`, `winnerId`, `modeId`, `mapId`), per-player `MatchScore` attribute, leaderstats `Elims`, and `MatchService.onEvent` for killfeed-style consumers. Respawns use per-player generation counters so a new death/leave cancels a stale scheduled respawn; TDM uses synchronized wave respawns (`WaveRespawnSeconds`).
- **Modes** (`src/shared/Game/Modes/`) implement `GameMode` (`MatchRules` + server-only hooks receiving a `ModeContext` of levers: map spawns, ball provisioning functions, team assignment). Registered in `ModeRegistry` (FFA, TDM, Scramble). Rules are shared modules so tests and client UI can read them.
- **EliminationService**: the `CombatAlive` character attribute is the single source of truth for alive/dead (nil/true = alive, false = eliminated). It never touches native Humanoid health or `LoadCharacter`. Also owns the ragdoll (BallSocket constraints with per-joint limits) and restore.
- **BallService**: the *sole* creator of ball instances — clones the Studio-authored `ReplicatedStorage.Assets.Dodgeball` template into `Workspace.Balls`. Two provisioning strategies driven by mode hooks: cadence ground spawns at map points, and direct held grants. Spawning is outside the deterministic sim (not input-driven); balls join the sim as replicated instances.
- **MapService**: picks, clones, and despawns Studio-authored maps (authored at final world position, so spawning is a plain clone). Spawn pools are flat: every BasePart under the map's `BallSpawns`/`PlayerSpawns` folders counts. Team ownership is not authored — MatchService assigns it per match via `TeamSpawns`.
- **MapFeatureService**: server-side terrain features — bounce pads launch along the pad's UpVector (server-set velocity, predicts cleanly), foam pits scale WalkSpeed while a root is inside the volume.
- **LobbyService**: teleports characters to `Workspace.Lobby.PlayerSpawns` (same invisible-spawn-parts convention as maps).
- **InputSetup**: materializes the declarative map in `Config.Input` as an `InputContext`/`InputAction`/`InputBinding` tree under each Player (contexts must be Player descendants for engine ownership/replication). Owns the validated `DeviceClass` attribute the adapter stamps onto commands.

### Data & economy — `src/server/Modules/`

- **PlayerData**: ProfileStore profiles (template in `Config.Data`, store key in `src/server/Env.luau`) replicated to the owning client via Replica (token `"GameProfile"`). Exposes a write-through proxy so mutations replicate automatically; go through PlayerData's API (`get`, `addCash`, progression deltas), never a second cache of profile data.
- **ProgressionService**: accumulates per-match progress (elims, deaths, catches, wins, XP, cash) from match events — with event dedup — and commits via PlayerData. XP/Cash award values live in `Config.Data`.
- **QuestService**: server owner of quest state (stored in the profile under `Quests`, daily reset key). Consumes match/sim events with dedup keys; pure rules live in `src/shared/Game/Quests/QuestLogic.luau`. Remotes: `GetQuestState`, `ClaimQuest`, `QuestStateChanged`. Rewards granted through **RewardService** (currently Cash only).
- **CosmeticsService**: the *only* writer of profile `Cosmetics.*`. The profile is the source of truth; `Equip_<Slot>` player attributes are a read-only projection so every client can render other players' equips.
- **CrateService**: two purchase paths — Cash via the `OpenCrate` remote, Robux via MonetizationService receipts — sharing one roll-and-grant routine; every open fires `CrateOpened`. The roll itself is pure (`src/shared/Game/Economy/CrateRolls.luau`, injected `Random`) so tests pin distributions and the dupe-refund rule.
- **MonetizationService**: owns `ProcessReceipt`. Receipts are recorded in the profile for idempotency (retry after grant returns `PurchaseGranted` without re-granting); unknown products/failures return `NotProcessedYet` so Roblox retries. New product types register a handler in its `handlers` table.

**No power creep:** cosmetics only — nothing purchasable may affect gameplay stats (GDD §2, §7).

### Client — `src/client/Modules/`

- **Input/**: `InputRouter` feeds `AimDirector`'s aim into the `Aim` InputAction every frame, pulses `Throw` on touch taps, reports device class. `AimDirector` owns aim/soft-lock target selection.
- **Presentation/** (BallVisuals, HammerVisuals, DamageFeedback, DeathEffects, TargetingUI, WorldAudio): rendering and audio feedback *only* — they react to sim events, attributes, and remotes and hold no gameplay authority. Effects on the ball template (trails, emitters, sounds) are Studio-authored and enabled/disabled by phase; must not replay during rollback corrections (test at 0/100/150/200 ms latency per `docs/dodgeball-studio-setup.md`).
- **UI/**: `MenuManager` owns which menu is open (single `currentMenu`, tweened open/close, escape handling); menus are declared in `MenuRegistry` and rendered from Studio-authored views looked up by `viewName`. Dynamic elements are cloned from Studio templates through `Elements/ElementFactory.cloneMount`, which returns the clone plus an `ElementHandle` for cleanup. `MatchHud` reads the `MatchState` attributes. React/react-roblox is available in Packages but current UI is template-clone based — ask before switching paradigms.

### Networking — `src/shared/Network.luau`

The single place remotes are declared: add to its `definitions` table (name → `"event" | "function" | "unreliable"`) instead of creating ad-hoc RemoteEvents. Server handlers get per-player rate limiting via `checkRateLimit` — keep limits on any new client-invokable remote.

### Config — `src/config/`

All tunables live here and nowhere else: combat feel (`Combat`, cmdr-tunable at runtime; units are studs/seconds/degrees), aim assist per device class (`AimAssist`), input map (`Input`), maps (`Maps`, `MapFeatures`), data template + XP/Cash tables (`Data`), quests, cosmetics, crates, products, UI, debug flags. New gameplay constants go in the matching config module, not inline.

## Testing

Specs live in `src/shared/Tests/*.spec.luau` and use `TestKit` — a minimal pure-Luau describe/it/expect (not TestEZ; expectations: `toEqual`, `toBeNear`, `toBeTruthy`, `toBeNil`) — so they run headlessly under Lune through the fake-Instance loader in `src/scripts/lune/`. `MockWorld` builds AABB `WorldSnapshot`s for sim tests. Anything in `Sim/`, `Modes/`, `Economy/`, or `Quests/` is pure and must stay runnable this way — if new shared logic needs engine APIs, put that part in an adapter or service instead. Selene excludes `*.spec.luau`. Add or extend a spec whenever you touch pure logic.

## Conventions

- Luau with `--!strict` at the top of modules; tab indentation; StyLua-formatted (`stylua src`).
- Services/modules are plain tables with functions; a `start()` guards against double-start with a `started` flag.
- Comments follow rule 1: module-top responsibility/invariant blocks, minimal inline.
- Selene (`std = "roblox"`) with `unused_variable` allowed.
