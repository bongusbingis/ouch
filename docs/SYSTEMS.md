# Systems

Each system's responsibility, owner modules, key invariants, and protected contracts.

All systems serve the four highest product priorities: **monetization, engagement, retention, and CCU**. Default to continued play even when presentation or gameplay is degraded or broken. Showing a failure screen or deliberately blocking match entry requires Jack's explicit approval, including for gameplay-critical errors. Preserve purchase, ownership, server-authority, and saved-data correctness while isolating failures. See `CONVENTIONS.md` and `AI_AGENT_WORKFLOW.md` for design and review requirements.

### Combat & Simulation
**Purpose:** Runs a pure, fixed-tick physics and combat simulation that is fully server-authoritative.
**Owner modules:** 
- `src/shared/Game/Sim/SimCore.luau`
- `src/shared/Game/Sim/Projectiles.luau`
- `src/shared/Game/Sim/WeaponRegistry.luau`
- `src/shared/Game/Adapters/CombatSimServer.luau`
**Key invariants:** 
- `SimCore` must remain perfectly deterministic and free of side-effects; it solely maps `SimState` + `InputCommand` -> `SimState` + `SimEvent`.
- The server maintains persistent `SimState` in memory across fixed ticks, encoding state back to instances for client replication.
- Replicated client character positions are sampled into `WorldSnapshot`, with `MovementGuard` bounding physical anomalies, while projectile trajectories and combat hit detection remain 100% server-authoritative.
- Weapons must be routed and executed in canonical order, maintaining fairness regardless of network latency.
**Depends on:** Command inputs, pure weapon definitions, network synchronization layer.
**Consumers:** Server orchestration (`MatchService`, `QuestService`, `AnalyticsService`, `OnboardingCombat`), client presentation (aim trajectory preview via `ProjectileTrajectory`, weapon presentation, and event feedback via `CombatSimEvent`). Combat simulation itself runs exclusively on the server.

### Game Modes
**Purpose:** Defines the rules and lifecycles for different arena gametypes like FFA, TDM, and Infection.
**Owner modules:** 
- `src/shared/Game/Modes/GameMode.luau`
- `src/shared/Game/Modes/MatchSim.luau`
- `src/shared/Game/Modes/ModeRegistry.luau`
- `src/shared/Game/Modes/ModeVote.luau`
**Key invariants:** 
- GameMode modules must expose pure `MatchRules` completely separate from server lifecycle logic.
- `MatchSim` drives match phase transitions, timers, and scoring as a pure finite state machine parameterized by `MatchRules`.
- Modes must define a deterministic way to evaluate a winner and score targets (either globally or scoped per team).
**Depends on:** Configuration values for constraints, Combat & Simulation to track eliminations.
**Consumers:** MatchService (for match lifecycle and scoring), MatchmakerService (for queues), UI layer (for scoring and match flow).

### Arena Startup & Asset Loading
**Purpose:** Starts as much of the arena client as possible while isolating initialization and media failures.
**Owner modules:** `places/arena/client/Modules/UI/ArenaLoadingClient.luau`, `places/arena/client/Scripts/SimulationClient.client.luau`, `places/arena/client/Scripts/ArenaUI.client.luau`
**Key invariants:**
- Client module load/start/render failures are diagnostics. Isolate and clean up the failed system without stopping healthy input, presentation, or UI systems. Generic startup errors must not create a failure screen or force a lobby return.
- Install loading-screen handoff deadlines before loading UI dependencies. Stalled or missing presentation must not leave an arrival or bootstrap screen covering the game indefinitely.
- UI presentation, voting visuals, and audio feedback are not match-admission requirements. Bound other client initialization waits and preserve continued play when initialization degrades.
- Degraded startup never invents an authoritative session snapshot or grants server admission. Combat input still respects server readiness, active match phase, and game mode.
- Preloading is a bounded warmup, not an authority on whether a player may enter a match. Missing preload-discovered objects must produce diagnostics and release the warmup gate; preload must not create a failure screen.
- Audio, images, fonts, animations, and cosmetic media are best-effort presentation assets. Failed downloads or preload timeouts must not become fatal startup errors or permanently withhold readiness, including in Splashdown.
- Preload media through instances with the appropriate content properties so Roblox requests the correct asset type.
- Warmup waits are bounded. Diagnostics must identify failures without requiring the player to leave the match; late or cancelled work must not change a newer initialization attempt.

### Splashdown
**Purpose:** Manages the racing-based obstacle course mode, handling checkpoints, course sequencing, and placements.
**Owner modules:**
- `src/shared/Game/Splashdown/CourseBuilder.luau`
- `src/shared/Game/Splashdown/CourseSequence.luau`
- `src/shared/Game/Splashdown/SplashdownState.luau`
**Key invariants:**
- The snapshot schema (`SplashdownState`) must exactly match between server and client without corruption.
- Round progressions must be synchronized; invalid or missing placements cannot halt the sequence.
**Depends on:** The core map streaming and collision logic, networking.
**Consumers:** Client UI for rendering the standings and timer, Progression for match rewards.

### Matchmaking & Parties
**Purpose:** Gathers players into parties, allocates them into valid matches, and teleports them seamlessly.
**Owner modules:**
- `places/lobby/server/Modules/Matchmaking/PartyService.luau`
- `places/lobby/server/Modules/Matchmaking/MatchmakerService.luau`
- `places/lobby/server/Modules/Matchmaking/TeleportCoordinator.luau`
**Key invariants:**
- A player can only ever be in exactly one party at any time.
- Party ownership and member lists must be strictly consistent before entering the matchmaking queue.
- Teleport returns (from arena back to lobby) must preserve party state and queues securely without dropping players.
**Depends on:** PlayerData, Config (queues and modes), Network.
**Consumers:** TeleportCoordinator, UI lobby screens.

### Economy & Monetization
**Purpose:** Safely handles all real-money and in-game currency purchases, receipt validation, and inventory unlocks.
**Owner modules:**
- `src/server/Modules/EconomyService.luau`
- `src/server/Modules/MonetizationService.luau`
- `src/server/Modules/PaidRandomPolicyService.luau`
- `src/server/Modules/CrateService.luau`
- `src/server/Modules/DirectPurchaseService.luau`
- `src/shared/Game/Economy/EconomyStore.luau`
- `src/shared/Game/Economy/ShopViewModel.luau`
**Key invariants:**
- Receipt processing MUST be idempotent; an already processed receipt should never grant rewards twice but must report success to Roblox.
- Economy state must only be mutated through the centralized `PlayerData` proxy; NEVER bypass the proxy for currency changes.
- Unknown or failed receipts must be left unprocessed so Roblox retries them.
- Paid random outcomes (crates) must respect regional compliance (handled by `PaidRandomPolicyService`).
- Product IDs, asset IDs, prices, and catalog definitions must not be changed without Jack's explicit approval.
**Depends on:** MarketplaceService, PlayerData, Configuration (Products, Crates, Bundles).
**Consumers:** Cosmetics, Progression, Lobby UI.

### Progression
**Purpose:** Manages the Battle Pass, seasonal XP, match awards, and tier unlocks.
**Owner modules:**
- `src/shared/Game/Progression/BattlePassLogic.luau`
- `src/shared/Game/Progression/SeasonStore.luau`
- `src/server/Modules/BattlePassService.luau`
- `src/shared/Game/Progression/MatchAwards.luau`
**Key invariants:**
- `BattlePassLogic` must be purely functional, relying only on the provided season definitions and time state to determine unlock eligibility.
- Match awards must be strictly validated on the server at match end; clients cannot dictate their XP earnings.
- Premium pass claims must be locked until the premium entitlement is confirmed.
**Depends on:** Economy (for premium entitlement), PlayerData (for XP storage).
**Consumers:** Battle Pass UI, Post-match summary screens.

### Quests & Daily Rewards
**Purpose:** Defines and tracks daily/weekly tasks and consecutive login rewards.
**Owner modules:**
- `src/shared/Game/Quests/QuestLogic.luau`
- `src/shared/Game/DailyReward/DailyRewardLogic.luau`
- `src/server/Modules/QuestService.luau`
- `src/server/Modules/DailyRewardService.luau`
**Key invariants:**
- Quest progress must be clamped to the quest goal; over-completion should not wrap or error.
- Rewards can only be claimed once per cycle; the state timestamp must securely block early re-claims.
**Depends on:** PlayerData, MatchAwards, Config.
**Consumers:** Lobby UI, Match Summary.

### Cosmetics
**Purpose:** Manages ownership, equipping, and visual rendering of character customization options.
**Owner modules:**
- `src/shared/Game/Cosmetics/CharacterAppearance.luau`
- `src/server/Modules/CosmeticsService.luau`
- `src/shared/Game/Economy/CosmeticsLogic.luau`
- `src/shared/Game/Economy/InventoryModel.luau`
**Key invariants:**
- A player cannot equip a cosmetic they do not own; the server strictly validates ownership before modifying loadout state.
- Cosmetic IDs must map explicitly to defined assets; invalid IDs must default gracefully rather than failing visually.
**Depends on:** Economy & Monetization (for unlocks and purchases), PlayerData.
**Consumers:** In-game avatars, Lobby display, Party appearance sharing.

### Map Features
**Purpose:** Registers and coordinates interactive environmental elements like bumpers, conveyors, and hazards.
**Owner modules:**
- `places/arena/server/Modules/MapFeatures/MapFeatureRegistry.luau`
- `places/arena/server/Modules/MapFeatures/MapFeatureKit.luau`
**Key invariants:**
- Map features must fail gracefully if dependencies are missing, maintaining the match loop.
- They must not dictate core combat outcomes directly, but rather feed events into the simulation.
**Depends on:** The active game mode, arena workspace layout.
**Consumers:** Active arena matches.

### Settings
**Purpose:** Maintains a localized registry of player preferences (audio, UI, controls).
**Owner modules:**
- `src/shared/Game/Settings/SettingsRegistry.luau`
- `src/shared/Game/Settings/SettingsStore.luau`
**Key invariants:**
- Changes to settings must instantly propagate to subscribed listeners.
- Invalid or deprecated setting keys must be pruned upon loading.
**Depends on:** Local device storage, PlayerData (if synced).
**Consumers:** Audio controllers, Input managers, UI visibility toggles.

### Onboarding
**Purpose:** Tracks and shepherds new players through first-time user experiences and tutorials.
**Owner modules:**
- `src/shared/Game/Onboarding/OnboardingState.luau`
- `places/lobby/server/Modules/Onboarding/OnboardingService.luau`
**Key invariants:**
- Onboarding state is append-only; a player can never un-learn a completed tutorial step.
- The service must safely handle players who join mid-flow or have legacy data shapes.
**Depends on:** PlayerData, Network.
**Consumers:** Client UI overlays, Matchmaker (to gate modes behind tutorials).

### Player Data
**Purpose:** Single source of truth for loading, validating, proxying, and saving persistent player profiles.
**Owner modules:**
- `src/server/Modules/PlayerData.luau`
**Key invariants:**
- Profile access MUST go through the `WriteThroughProxy` to ensure all mutations replicate properly and trigger listeners.
- Data migrations must apply sequentially over the baseline template to handle legacy profiles without data loss.
- Save operations must correctly lease and release write locks to prevent concurrent profile corruption.
**Depends on:** ProfileStore, Replica (for replication).
**Consumers:** Nearly all server services (Economy, Progression, Cosmetics, etc).

### Configuration
**Purpose:** Manages static definitions and runtime live-overrides across all game domains.
**Owner modules:**
- `src/config/*`
- `src/shared/Game/Config/ConfigRuntime.luau`
- `src/server/Modules/ConfigLiveService.luau`
**Key invariants:**
- `ConfigRuntime` must track the original shipped defaults and restore them exactly when a live-override is removed.
- Configuration tables must be completely read-only from the perspective of game systems; they can only observe changes via listeners.
**Depends on:** LiveOps tools, Network.
**Consumers:** Every major game system (Economy, Gameplay, Infra, Interface, Progression).

### Networking
**Purpose:** The central artery defining and materializing every valid remote event and function.
**Owner modules:**
- `src/shared/Network.luau`
**Key invariants:**
- All client-to-server requests MUST pass through rate-limiting and validation middleware.
- Remotes must be materialized consistently on both client and server before any system attempts to bind to them.
**Depends on:** Roblox networking primitives.
**Consumers:** All systems requiring client-server communication.
