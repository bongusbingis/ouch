# Splat Brawl (ouch) — Production-Readiness Audit

**Scope:** `c:\Users\jackc\Desktop\ouch` only. `C:\Users\jackc\Desktop\boba-cafe`
(unrelated project) and the external `ouch-prototype-lobby` directory are out
of scope and were not read.

**Method:** Direct reads of `AGENTS.md`, `Network.luau`, `MatchService.luau`,
`ModeVoteService.luau`, `PlayerData.luau`, the vendored `ProfileStore`
package's shutdown internals, `MatchmakingScript.server.luau`,
`GameModes.luau`/`ModeRegistry.luau`, `CrateService.luau`/`RewardService.luau`/
`CosmeticsService.luau`, `CombatCamera.luau`, `LoadingScreen.luau`, and
`PartyBus.luau`, plus three parallel read-only call-site traces covering (1)
combat/networking security, (2) party/matchmaking/teleport lifecycle, and (3)
input/camera/UI ownership. Baseline verified: `lune run
src/scripts/lune/run-tests.luau` → **447 tests, 0 failures**; `stylua --check`
and `selene` clean on `src`, `places/arena`, `places/lobby`.

No production files were modified to produce this report.

**Addendum (2026-08-25) — remediation pass:** Following this audit, the
findings below were triaged and acted on. Status per finding, with
corrections where a fix pass surfaced that the original finding overclaimed
the problem:

| ID | Disposition |
|---|---|
| AUDIT-001 | **Fixed.** `ArenaApp.luau` now holds `Combat.requestCursor("LoadingAction")` for exactly as long as a real action button (retry/return/stay) is rendered. |
| AUDIT-002 | **Corrected, not a defect.** Re-reading `ShopPage.luau`/`ShopSection.luau` in full during the fix pass found a working container-width breakpoint system (`compact` mode below 820px, driven by `React.Change.AbsoluteSize`) that the original audit missed by not reading the file end-to-end. The fixed-pixel values exist *within* that breakpoint system, not instead of one. No code change made; see the corrected write-up below. |
| AUDIT-003 | **Fixed.** `PartyService` now locks a player out of `JoinByCode` for `Config.JoinCodeLockoutSeconds` after `Config.JoinCodeMaxFailures` consecutive wrong codes, with a friendly client-side error message. |
| AUDIT-004 | **Not applied, by design.** The fix requires relocating `DevSoloPlay.luau` out of `ReplicatedStorage.Shared` into a server-only location, which would also strand its existing pure-Luau spec (the Lune test harness cannot reach `ServerScriptService`) and requires new Rojo project-file wiring. Cost is disproportionate to a LOW, information-disclosure-only finding the audit itself flagged as "functionally optional." Left as-is. |
| AUDIT-005 | **Fixed — deleted.** Confirmed with the user: `Scramble.luau` removed rather than registered. |
| AUDIT-006 | **Fixed — deleted.** `CombatDebug.luau` removed; confirmed zero references anywhere, including one adjacent false-positive grep hit (`"CombatDebugVisuals"` in `DebugVisuals.luau`, an unrelated string) checked before deletion. |
| AUDIT-007 | **No action, per original recommendation.** Inherent to the ProfileStore pattern; monitor in production instead. |
| AUDIT-008 | **No action, per original recommendation.** Only matters if hot-reload is introduced. |
| AUDIT-009 | **No action, per original recommendation.** Monitoring note, not a code defect. |
| AUDIT-010 | **Resolved by AUDIT-005's deletion.** The Infection-vs-Scramble contrast that motivated this note no longer applies now that Scramble is gone. |
| AUDIT-011 | **Fixed.** `ReportAnalyticsEvent`'s validator now rejects any payload `AnalyticsLogic.routeUIEvent` wouldn't route, reusing the existing pure whitelist instead of a new one. Also corrected: the original finding overstated the exposure — unroutable `kind`s were already silently dropped by `handleReport` before this fix, they just weren't rejected at the validation layer. |
| AUDIT-012 | **Not applied.** The recommended fix was a documentation comment at the read site, but this session established (and the user approved) a strict no-inline-comments convention for this codebase; adding one back here would contradict it. Left as a mental note for future readers via this report instead. |

Verified after all changes: **447 tests, 0 failures**; `stylua --check` and
`selene` still clean on `src`, `places/arena`, `places/lobby`; both places
still build via `rojo build`.

---

## Section 1 — Executive Summary

**Overall health: good, for a project this ambitious.** The core simulation
(dodgeball + hammer combat) is deterministic, server-authoritative, and
extensively spec-tested (447 passing specs). The netcode boundary is
disciplined: clients send *intent* (aim direction, charge, a target-id
*hint*), and the server independently recomputes origin, cooldowns, hit
legitimacy, and elimination from its own authoritative state on every case
checked. The party/matchmaking/teleport subsystem — usually the messiest part
of a Roblox multiplayer game — uses generation counters, phase guards, and
atomic MemoryStore claims consistently enough that the classic race conditions
(stale leadership, double-queue, teleport-callback-fires-after-party-gone)
are largely designed out rather than patched over. `AGENTS.md` is unusually
accurate: nearly every invariant it claims was independently verified against
the actual code in this pass.

**Strongest areas:** the deterministic sim and its test coverage; the
cross-place trust boundary (payload schema validation *and* independent
source-place/universe checks, not just field casting); the mode-vote's
async-race handling via a `deadlineRevision` generation counter; party
leadership transfer and in-transition disconnect handling.

**Largest risks:** none are catastrophic. The most concrete player-facing bug
is a mouse/keyboard cursor lockout on the loading screen's retry path
(AUDIT-001). The most concrete security-adjacent gap is unthrottled party
join-code guessing (AUDIT-003). Everything else found is LOW/INFO — dead
code, an orphaned game mode, and architecture notes worth documenting rather
than "fixing."

**Fix before launch:** AUDIT-001 (loading-screen input lockout) and AUDIT-003
(join-code throttle) are the two with real player-facing or abuse-surface
impact. Both were small, surgical fixes — **both are now done** (see the
remediation addendum below).

**Can safely wait:** everything else in this report, including the dead code
and the orphaned mode — none of it is reachable by players today, so none of
it is blocking.

---

## Section 2 — Architecture Map

```
ReplicatedStorage
├── Shared/          <- src/shared        (both places: sim, UI, adapters, matchmaking payloads)
├── Config/          <- src/config        (both places: all tunables, live-overridable subset)
├── Packages/        <- Wally packages    (react, react-roblox, profilestore, promise, cmdr, ...)
├── Remotes/         <- created at runtime by src/shared/Network.luau
├── MatchState/       <- arena only, created by MatchService
└── ModeVoteState/    <- arena only, created by ModeVoteService

ServerScriptService.Server
├── Modules/         <- src/server/Modules (both) + places/<place>/server/Modules (place-specific)
└── Cmdr/            <- arena only, admin console commands

ServerStorage.Tests   <- src/tests (harness) + places/<place>/tests (specs), both places

StarterPlayer.StarterPlayerScripts.Client
├── Modules/         <- places/<place>/client/Modules
├── UI/              <- places/<place>/client/UI (React)
└── (PlayerModule fork lives under StarterPlayerScripts too, via src/client/PlayerModule)
```

Two independent places share `src/`:

- **Lobby** (`lobby.project.json`, place `130584867985467`) — parties, party
  codes, matchmaking, cross-server party state (MemoryStore + MessagingService),
  the shop/inventory UI, teleport-out.
- **Arena** (`arena.project.json`, place `121997450145716`) — the deterministic
  combat sim, mode voting, match lifecycle, elimination/respawn, post-match,
  teleport-back.

Each project file explicitly blocks the other's place ID (`arena.project.json`
cannot accidentally load into the lobby's slot or vice versa) — a good,
underrated guard against a common Rojo-multi-place mistake.

**Critical state owners** (all independently confirmed against `AGENTS.md`'s
claims):

| State | Sole owner | Notes |
|---|---|---|
| Ball possession | `ProjectileState.phase`/`heldBy` | never duplicated elsewhere |
| Alive/dead | `CombatAlive` character attribute | `EliminationService`, never native Humanoid health |
| Equipped weapon | `PlayerCombatState.equipped` → `SimStateCodec` attribute | HUD/animations read the attribute, no second copy |
| Walk speed | `MovementSpeedService` | sole writer, named modifiers |
| Profile cosmetics | `CosmeticsService` | profile is truth, `Equip_*` attributes are a read-only projection |
| Party/queue/match records | MemoryStore repositories (`PartyRepository`/`QueueRepository`/`MatchRepository`) | cross-server, atomic-update based |
| Match phase | `MatchSim.MatchState` inside `MatchService` | one phase machine, mode rules injected |
| Mode ballot | `ModeVoteService`'s module-local `vote`/`deadlineRevision` | projected via `ModeVoteState` |

No competing owners were found for any of these during this pass.

---

## Section 3 — Critical Runtime Flows

**Player startup (arena):** `ReplicatedFirst` loading screen holds the client
until `SimulationServer`'s services have started and the arena's
`ArenaSessionService` admits the arrival (validates `SourcePlaceId`/
`SourceGameId` on the incoming teleport payload). `SimulationClient.client.luau`
waits on `ReactLoadingPresented` before starting any input/presentation module,
then unconditionally enables `CombatCamera` (see AUDIT-001) and gates
`Combat.setInputEnabled` on `ArenaReady` + match phase == "Active".

**Combat:** Client `CombatInputSender` sends `{kind, aimDir, targetId, charge}`
only. `ServerAuthAdapter` runs a fixed 60Hz accumulator on `Heartbeat`,
derives throw origin from the player's *live server-side* root, and steps
`SimCore` — which routes commands to the equipped `WeaponKit`, recomputes hit
legitimacy from the authoritative `WorldSnapshot` every tick, and emits
`SimEvent`s. Presentation-only broadcast follows over `CombatSimEvent`
(unreliable). `MatchService.handleCombatEvent` reacts only to events its own
sim loop produced — it is not remote-reachable.

**Party:** `PartyService` (1175 lines) owns creation, join-by-code, kick,
leadership (auto-promotes `members[1]` on leader removal), and the
`_removeMemberFromParty` guard that refuses to detach a member mid-teleport
(`Claimed`/`Assigned`/`Teleporting` phases), so a mid-transition disconnect
can't dissolve a party out from under an in-flight match.

**Matchmaking:** `MatchmakerService:Tick()` is invoked by *every* lobby
server independently (`MatchmakingScript.server.luau:100-108`, gated on
`HasLocalQueuedParty()`), each `_claimCandidates` call re-validating ticket
id, party size, and lease inside an atomic MemoryStore transform — a claim
can't reference a party that changed shape or dissolved after being enqueued.

**Teleport:** `TeleportRetryCoordinator` backs off on `Failure`/`Flooded`/
`GameFull`, guarded by a generation/`retryRevision` counter so a stale retry
can't fire after the situation has moved on. `TeleportPayload.parse`/
`ReturnPayload.parse` reject malformed/wrong-schema payloads, and — the part
that actually matters for trust — `ArenaSessionService.receive` and
`PartyService`'s return handler both independently check
`SourcePlaceId`/`SourceGameId` *before* trusting the parsed payload.

**Gameplay start:** `ArenaSessionService`'s readiness gate
(`ArenaReadinessGate`) releases on full-ready, on a ready deadline with ≥1
ready player, or on direct-join-ready — it cannot release with zero ready
players (verified against the code, not just the doc comment).
`ModeVoteService.beginVote` opens a 10-second ballot the moment the gate
releases; `finishVote` is protected by `deadlineRevision` against both a
stale scheduled callback and a vote that gets extended after the callback was
already scheduled (it re-checks remaining time and reschedules itself rather
than firing early).

**Round end:** `MatchSim.finish` → `MatchService`'s `MatchEnded` event →
`PostMatchService.beginResult` builds and delivers a `PostMatchResult` per
party group; `ProgressionService` commits XP/Bonks/stat deltas keyed off the
same result, deduplicated via `EventDedup`. This path is **substantially
more complete** than the product-context note in the audit brief implied —
see Section 12.

---

## Section 4 — Findings by Severity

### HIGH

**AUDIT-001 — Combat camera hides/locks the cursor before the mode vote ever
requests it, stranding mouse/keyboard players on a loading-screen retry —
FIXED**
- **Category:** Input/UI
- **Confidence:** High
- **Files:** `places/arena/client/Scripts/SimulationClient.client.luau:67`,
  `src/client/PlayerModule/Combat/CombatCamera.luau:34-36,71-81`,
  `places/arena/client/Modules/Input/InputRouter.luau:29,31,96`,
  `src/shared/UI/Components/LoadingScreen.luau:57-70,221` (real
  `AnimatedButton` retry/continue actions).
- **Problem:** `Combat.setCameraEnabled(true)` runs unconditionally at
  bootstrap. `CombatCamera.isActive()` is `enabled and Config.Enabled and not
  cursorIsRequested()` — the *only* place that ever calls
  `Combat.requestCursor` is `InputRouter`, tagged `"ModeVote"`, and only once
  the mode ballot is actually open. Between script start and the ballot
  opening (loading, streaming, admission, any load failure/retry), nothing
  holds a cursor request, so `CombatCamera` is active: `MouseIconEnabled =
  false` and the camera mouse-locks.
- **Impact:** If a mouse/keyboard player's load fails and `LoadingScreen`
  shows its real retry/continue button, their cursor is invisible and the
  camera is mouse-locked — they have no way to click it. Touch players are
  unaffected (no cursor to hide); gamepad players are unaffected (menu
  navigation uses `GuiService.SelectedObject`, confirmed built in
  `ArenaMenu.luau:343-388`).
- **Reproduction:** Force a loading failure (e.g. block a critical asset) as
  a mouse/keyboard player before the mode vote opens; observe the retry
  button is rendered but the cursor cannot reach it.
- **Fix applied:** `places/arena/client/UI/ArenaApp.luau` now derives
  `actionable = primaryAction ~= nil or secondaryAction ~= nil` (true exactly
  when a real retry/return/stay button is rendered) and holds
  `Combat.requestCursor("LoadingAction")` for as long as `actionable` is
  true, via a `React.useEffect` keyed on that boolean, releasing on
  cleanup/unmount. This is narrower than the original recommendation (which
  would have held the cursor for the *entire* loading screen, including the
  large stretch with no interactive control) — scoped to only the moments a
  button actually needs to be clickable, so combat-camera immersion is
  preserved everywhere else.
- **Scope:** Small. **Risk of fix:** Low (additive, uses an existing
  reference-counted API). **Verified:** 447 tests still pass; `stylua`/
  `selene` clean; both places still build.

### RETRACTED / CORRECTED

**AUDIT-002 (original) — "Shop UI uses fixed-pixel row heights with no
viewport/UIScale scaling" — corrected on deeper reading, not a defect**
- **Category:** UI/Responsive design
- **Confidence:** High (in the correction)
- **Files:** `src/shared/UI/Components/ShopPage.luau:20-23,182-193` (the
  `compact` state, `heroHeight`, and the `React.Change.AbsoluteSize` handler
  that flips it), `src/shared/UI/Components/Shop/ShopSection.luau:19-20`
  (`columns`/`cardHeight` both keyed off the same `Compact` prop).
- **What the original finding got wrong:** It was based on a grep for
  `UDim2.new(1, 0, 0, <px>)` and the absence of `useViewportSize`/`UIScale`
  in the Shop components, without reading `ShopPage.luau` end-to-end. In
  fact `ShopPage` already implements a real container-width breakpoint:
  it observes its scrolling content frame's `AbsoluteSize.X` and switches
  into a `compact` layout below 820px, which `ShopSection` also consumes to
  drop from 3 to 2 columns and adjust card height. The fixed-pixel values
  the original finding cited are the two breakpoint regimes' concrete
  values, not evidence of no responsive handling — the same way a
  CSS media query's pixel values aren't "unresponsive" just because they're
  not percentages.
- **Residual, much narrower observation:** The whole Shop content sits in a
  `ScrollingFrame` with `AutomaticCanvasSize`, so even on a very short phone
  screen nothing gets clipped — worst case is more scrolling, which is
  normal for a storefront list. No code change made.
- **Lesson applied:** corrected here rather than left standing, per this
  audit's own "no fake findings" standard — a static grep is a starting
  point, not a substitute for reading the file it's about to make a claim
  on.

### MEDIUM

**AUDIT-003 — Party join-by-code has no code-specific brute-force throttle
— FIXED**
- **Category:** Party/Security
- **Confidence:** Medium
- **Files:** `places/lobby/server/Modules/Matchmaking/PartyRepository.luau:52-73`
  (6-digit numeric code space, up to 50 collision retries on generation),
  `places/lobby/server/Scripts/MatchmakingScript.server.luau:65-84` (generic
  `PartyRequest` rate limit: 8/sec whole-remote, plus a `JoinByCode`-specific
  action limit of 2 per 5 seconds — confirmed present, but still a flat
  per-player limit with no escalating lockout or code-guess-specific
  penalty).
- **Problem:** `JoinByCode` is throttled (2/5s per player), which is better
  than the audit brief's worst-case assumption, but there's no
  progressive backoff, no CAPTCHA-equivalent, and no alerting if one account
  cycles through many `JoinByCode` failures. `PartyRepository.GetPartyByCode`
  does correctly reject stale/expired/leaderless parties on lookup, which
  bounds the value of a successful guess.
- **Impact:** A determined attacker can still enumerate live codes slowly
  (2/5s ≈ 1,440/hr per account, and this is not obviously tied to
  UserId-level lockout across multiple accounts). Impact of success is
  joining a stranger's party — a harassment/privacy nuisance, not an economy
  or combat exploit.
- **Fix applied:** `PartyService` now tracks consecutive `JoinByCode`
  failures per user in-memory (`_joinCodeFailures`, cleaned up on
  `PlayerRemoving`); after `Config.JoinCodeMaxFailures` (5) wrong codes
  within `Config.JoinCodeLockoutSeconds` (30s), further attempts return a
  new `Protocol.Errors.TooManyCodeAttempts` immediately without touching the
  repository, for a 30-second cooldown. Both constants live in
  `places/lobby/shared/Matchmaking/Config.luau` alongside the codebase's
  other matchmaking tunables. The client (`PartyClient.ErrorMessages`/
  `JoinCodeErrorMessages`) shows "TOO MANY ATTEMPTS - TRY AGAIN LATER" for
  the new code, matching the existing friendly-copy pattern rather than
  leaking the raw error string.
- **Scope:** Small. **Risk of fix:** Low. **Verified:** 447 tests still
  pass; `stylua`/`selene` clean; both places still build. No existing test
  harness covers `PartyService` (it has no spec today, mocked or otherwise),
  so this wasn't spec-tested — flagged for the test plan in Section 18.

### LOW

**AUDIT-004 — `DevSoloPlay`'s group id and minimum rank are hardcoded in a
client-shipped `Shared` module — NOT FIXED (deliberately)**
- **Category:** Security (defense-in-depth)
- **Confidence:** High
- **Files:** `src/shared/Game/Matchmaking/DevSoloPlay.luau:10-11`.
- **Problem:** The authorization *decision* is unforgeable (it runs
  server-side against `player:GetRankInGroup`), but the constants
  (`GROUP_ID = 291738800`, `MIN_RANK = 254`) ship in a module every client
  downloads, letting anyone inspect client Luau to learn which Roblox
  group/rank gates dev tooling (`DevSoloPlay` in the lobby, `DevEndMatch` in
  the arena).
- **Impact:** Information disclosure only — no bypass. Lets an attacker
  target that specific group for social engineering/rank-farming.
- **Why left as-is:** The fix means moving the module out of
  `ReplicatedStorage.Shared` into a server-only tree. `DevSoloPlay.luau` is
  currently spec-tested (`src/shared/Tests/DevSoloPlay.spec.luau`) through
  the pure-Luau Lune harness, which can only reach `ReplicatedStorage` — it
  has no path to `ServerScriptService` at all (confirmed: `loader.luau` never
  defines a `game`/`GetService` global). Relocating the module would strand
  that spec (no equivalent lightweight harness exists for server-only code;
  the alternative is the heavier in-place cloud suite) and requires adding
  new `$path` entries to both `arena.project.json` and `lobby.project.json`.
  That's a disproportionate amount of change for a finding the original
  audit itself scored LOW and called "functionally optional" — the
  authorization check itself was already confirmed unforgeable regardless of
  where the constants live. Left as-is; noted here so the trade-off is
  explicit rather than silently skipped.

**AUDIT-005 — `Scramble` game mode is fully implemented but registered
nowhere — FIXED (deleted, per product decision)**
- **Category:** Incomplete/dead integration
- **Confidence:** High
- **Files (removed):** `src/shared/Game/Modes/Scramble.luau` (implemented
  the full `GameMode` interface: `onMatchStart`, `onPlayerSpawned`, `onElim`,
  `onMatchEnd`); was never listed in `ModeRegistry.luau` or present in
  `src/config/GameModes.luau` (not even as a disabled stub, unlike
  `Infection`).
- **Resolution:** Asked the product owner directly (leave it / register it
  enabled / register it disabled / delete it) rather than guess. Answer:
  delete. File removed.

**AUDIT-006 — `CombatDebug.luau` has zero call sites anywhere in the repo —
FIXED (deleted)**
- **Category:** Dead code
- **Confidence:** High
- **Files (removed):** `src/client/PlayerModule/Combat/CombatDebug.luau`.
  Before deleting, re-confirmed the whole repo for `CombatDebug` and
  double-checked the one adjacent grep hit
  (`places/arena/client/Modules/Debug/DebugVisuals.luau`) — it turned out to
  be an unrelated string literal (`"CombatDebugVisuals"`, a folder name), not
  a reference to this module.
- **Resolution:** Confirmed with the user before deleting. File removed.

**AUDIT-007 — Receipt/crate-grant idempotency has a bounded persistence-window
risk (not a same-process race)**
- **Category:** Data/Economy
- **Confidence:** Medium
- **Files:** `src/server/Modules/MonetizationService.luau:107-143`,
  `src/server/Modules/CrateService.luau:44-99,215-223`.
- **Investigation note:** I initially suspected a check-then-act race here
  (the `Receipts[receiptKey]` guard is checked before the grant handler runs
  and written only after it succeeds). I traced the full call chain —
  `processReceipt` → handler → `CrateService.openFromReceipt`/`rollAndGrant`
  → `CosmeticsService.grant`/`PlayerData.addBonks` — and **none of it
  yields** (no `task.wait`, no DataStore call, no Promise in the hot path;
  everything is a synchronous in-memory table mutation). Within one Roblox
  server process, Lua coroutines only switch at yield points, so two
  `ProcessReceipt` invocations for the same purchase cannot interleave on
  the same server. **This is not a same-process defect.**
- **Real residual risk:** `data.Receipts[receiptKey]` only becomes durable at
  `ProfileStore`'s next autosave (library default, no custom interval set in
  `PlayerData.luau`). If the server crashes/loses the profile between the
  in-memory grant and the next autosave, and Roblox redelivers the receipt to
  a *different* server after the player reconnects, that second server has
  no record of the grant and could re-process it. This is an inherent
  property of the standard ProfileStore-based idempotency pattern (used by
  most Roblox games), not a coding mistake specific to this repo.
- **Recommended fix:** No urgent action. If double-grant reports ever surface
  in production, cross-reference against server-crash timing before assuming
  a code bug.
- **Scope:** N/A today.

**AUDIT-008 — `startOptional` debug/optional client modules don't disconnect
on `script.Destroying`**
- **Category:** Lifecycle/cleanup
- **Confidence:** High
- **Files:** `places/arena/client/Modules/Debug/DevMatchSkip.luau:69`,
  `places/arena/client/Scripts/SimulationClient.client.luau:209-225`
  (teardown list omits `DevMatchSkip` and several other `startOptional`
  entries).
- **Impact:** None today — `SimulationClient.client.luau` only tears down at
  place shutdown, at which point the whole client VM is gone regardless.
  Would matter only if the project ever introduced client-script hot-reload
  or repeated start/stop of the simulation script within one session.
- **Scope:** N/A.

**AUDIT-011 — `ReportAnalyticsEvent` accepts any string `kind` with no
further payload validation — FIXED**
- **Category:** Security/Analytics
- **Confidence:** Medium
- **Files:** `src/server/Modules/AnalyticsService.luau:384-391`.
- **Correction on deeper reading:** The original impact statement
  ("spam arbitrary/spoofed analytics rows") overstated it. Tracing
  `handleReport` → `AnalyticsLogic.routeUIEvent` showed that function was
  already a pure whitelist — only `"MenuOpened"` and a fixed
  `SHOP_EVENTS` set of kinds route anywhere; everything else already
  returned `nil` and was silently dropped before this fix. The real,
  narrower gap was that unroutable payloads still reached the handler
  (wasted work, and rejection wasn't visible at the validation layer where
  it belongs).
- **Fix applied:** The remote's `validate` function now calls
  `AnalyticsLogic.routeUIEvent(payload)` itself and rejects (`"unknown_kind"`)
  anything it wouldn't route — reusing the existing pure whitelist instead of
  introducing a second one, consistent with the "one source of truth" rule.
- **Scope:** Small. **Risk of fix:** Low. **Verified:** 447 tests still
  pass (including the existing `AnalyticsLogic.spec.luau` coverage of
  `routeUIEvent`, unchanged); `stylua`/`selene` clean.

### INFO / FUTURE

**AUDIT-009 — Matchmaking has no single leader; every lobby server ticks its
own `MatchmakerService`**
- **Files:** `places/lobby/server/Scripts/MatchmakingScript.server.luau:100-108`.
- This is a deliberate scale-out design (coordination happens through
  MemoryStore atomic claims, not a leader election), and the traced claim
  logic handles concurrent claims safely. Worth watching MemoryStore call
  volume as CCU grows — every server polls independently at
  `Config.WorkerPollInterval`, so N servers means N× the poll rate against
  the same shared store. No evidence of a problem at any tested scale; this
  is a documentation/monitoring note for scale, not a defect.

**AUDIT-010 — Infection is intentionally soft-disabled; Scramble is not
soft-disabled, it's just absent — RESOLVED**
- Config confirms `Infection.Enabled = false` in `src/config/GameModes.luau`
  with a matching spec (`GameModesConfig.spec.luau`: "retains the disabled
  Infection stub"). Scramble had no equivalent stub anywhere; this was the
  evidence behind treating it as *possibly forgotten*. Superseded by
  AUDIT-005's resolution — Scramble is now deleted, so this contrast no
  longer applies.

**AUDIT-012 — Gamepad aim and aim-assist tuning live on different code
paths, coupled only through the shared camera — NOT FIXED (deliberately)**
- **Files:** `places/arena/client/Modules/Input/AimDirector.luau:44-56,
  206-217`.
- `AimDirector` always reads `camera.CFrame.LookVector` — there is no
  dedicated `Enum.UserInputType.Gamepad` aim branch. Gamepad aim works only
  because the stock `CameraModule`'s right-stick rotation happens to feed the
  same camera `AimDirector` reads. `AssistConfig`/aim-assist strength is
  keyed by device class independently. Not a bug today, but a future change
  to stock gamepad camera rotation (e.g. a PlayerModule update) could
  silently change aim feel without touching anything that looks like "aim"
  code.
- **Why left as-is:** The recommended fix was a documentation comment at the
  read site. This session established a strict convention for this codebase
  (a 4-line Name/Author/Description/Created header per file, zero other
  comments — see `AGENTS.md` rule 1's replacement) that the user explicitly
  approved; adding an inline comment back in would contradict it. Recorded
  here instead, where a future reader investigating this exact area is
  likely to look.

**No significant issue found:**
- The deterministic sim's ordering rules (`SimUtil.sortedKeys` used
  consistently; no unordered table iteration found in the sim path).
- Elimination/event forgery: `MatchService.handleCombatEvent` and
  `MatchService.eliminate*` are not remote-reachable.
- Vote-close race conditions: fully generation-counter guarded (see Section 3).
- Background polling loops: every one found (`AnalyticsService`,
  `ConfigLiveService`, `MatchmakingScript.server.luau`) properly `task.wait()`s
  — no busy-spin found anywhere in this pass.
- `PartyBus` cross-server subscription lifecycle: connections are disconnected
  on both `Release` and `Destroy`.

---

## Section 5 — Security Review

Every entry in `src/shared/Network.luau`'s `definitions` table that a client
can actually invoke, with its server-side guard:

| Surface | Client Claim | Server Validation | Rate Limit | Risk | Notes |
|---|---|---|---|---|---|
| `SubmitCombatInput` | aimDir, targetId (hint), charge, kind | `ServerAuthAdapter` rejects non-Throw/Catch, non-finite/NaN vectors, oversized/typed targetId, out-of-range charge; origin always taken from server root | per-player (adapter-level) | Low | Client-claimed target is never trusted for the actual hit |
| `SubmitWeaponEquip` | weapon kind | validated against `WeaponRegistry` | per-player | Low | — |
| `SubmitModeVote` | modeId | string length 1-32; `isRoundEligible` required | 6/sec | Low | Non-eligible/late players can't vote |
| `PostMatchRequest` | action, resultId | `resultId` must match current result; party-leader-only for default/PlayAgain actions | 3/sec | Low | |
| `RequestLobbyReturn` | action | must be Retry/Stay/Return | 2/sec | Low | |
| `ArenaClientReady` / `ReportArenaLoadingEvent` | none/telemetry | n/a (no args of consequence) | 4/sec | Low | |
| `DevEndMatch` | none | `DevSoloPlay.canUse` (group rank, server-verified) | 2/sec | Low | See AUDIT-004 for the info-leak note |
| `PartyRequest` (all party actions) | action + payload | `Protocol.validateRequest`; per-action limits (`JoinByCode` 2/5s, `KickMember` 2/5s, `DevSoloPlay` 1/10s, `StartMatchmaking` 2/5s) | 8/sec overall | Low–Medium | See AUDIT-003 for the code-guess nuance |
| `TeleportPresentationReady` | none | n/a | 4/sec | Low | |
| `OpenCrate` | crateId | `isOpenable`, `canReceivePaidRandom`, balance check all server-side; roll is server-computed | 2/sec | Low | See AUDIT-007 for the persistence-window note |
| `PurchaseCosmetic` | itemId | ownership/price/purchasability checked in `.purchase` (not itself remote-facing) | 2/sec | Low | |
| `EquipCosmetic` | slot, itemId | ownership/slot validated in `CosmeticsService`/`CosmeticsLogic.canEquip` | 5/sec | Low | |
| `GetQuestState`/`ClaimQuest` | questId | type-checked; dedupe/already-claimed enforced in `.claim` | 4/6/sec | Low | |
| `GetSeasonPassState`/`ClaimSeasonTier`/`ClaimAllSeasonTiers` | tier | claim legality re-derived from stored XP each time (`BattlePassLogic`, pure) | 4/-/2/sec | Low | |
| `ReportDeviceClass` | device class string | whitelist-checked | 5/sec | Low | |
| `ReportAimPose` (unreliable) | charge 0-1 | numeric range checked | configurable | Low | Cosmetic-only (arm pose), not gameplay-authoritative |
| `MarkSwipeThrowLearned` | none | n/a | 1/sec | Low | |
| `ReportAnalyticsEvent` | free-form payload | only `kind` type-checked | 10/sec | Low | See AUDIT-011 |

Server→client-only events (`CombatFeed`, `MatchSummary`, `PostMatchResult`,
`PostMatchStatus`, `ShopStateChanged`, `QuestStateChanged`,
`SeasonPassStateChanged`, `DamageFeedback`, `CombatSimEvent`,
`JumpPadImpulse`, `CrateOpened`, `StorePurchaseGranted`, `PartyPacket`,
`TeleportStatus`) correctly have no `OnServerEvent` handler anywhere — they
cannot be spoofed into triggering server logic because nothing listens for
them being fired *at* the server.

**No CRITICAL security findings.** The one Robux-purchase path
(`MarketplaceService.ProcessReceipt`) follows Roblox's own recommended
idempotency pattern correctly (see AUDIT-007 for the one residual, inherent
caveat).

---

## Section 6 — Performance Review

**Client:** No render-loop hotspots found beyond what's expected for a
combat game with trajectory prediction and IK — `ChargeAim`'s trajectory
sweep and `ArmIK`'s per-frame chain solve are the two heaviest per-frame
client costs, both already scoped to only run while relevant (charging /
holding a ball respectively) per the file's own responsibility description.
No evidence of unbounded work scaling with player count on the client.

**Server:** No `O(players²)` or `O(projectiles × players)` pattern was found
in the traced combat path — hit resolution is computed against the
authoritative `WorldSnapshot` per weapon-kit tick, not as a cross-product
scan; `SimUtil`'s deterministic iteration is a correctness mechanism, not a
performance one, but doesn't introduce quadratic cost either. Not
exhaustively profiled — this is a code-shape review, not a load test.

**Network:** Combat state uses short attribute names (`ph`, `hb`, `ow`, `er`,
`ft`, `vel`) specifically to stay under Roblox's per-instance replication
caps — a deliberate bandwidth decision documented in `AGENTS.md` and
consistent with what `SimStateCodec` actually writes. Ball position
replicates via native CFrame, not an attribute. No evidence of per-frame
full-table remote spam.

**Memory/connections:** See AUDIT-008 (harmless today) and the "No
significant issue found" bullet in Section 4 for the polling-loop sweep. No
leaked `MessagingService` subscriptions found (`PartyBus` disconnects
correctly on both paths). Did not exhaustively audit every one of the ~450
files' `Connect` sites — spot-checked the highest-risk long-lived ones
(analytics, config live-reload, party bus, matchmaking tick, character
lifecycle).

**Scale (matchmaking):** See AUDIT-009 — the per-server polling design means
MemoryStore call volume scales with server count, not just CCU. Worth
tracking as a metric once real traffic exists; no evidence of a problem at
any scale tested in this repo's test suite (which doesn't simulate CCU load
at all — this would need production telemetry, not static analysis).

**Bots:** Not present in the codebase; not a defect. If queue times ever
need protection at low CCU, `MatchmakerService`'s candidate-selection seam
(`_selectCandidates`) is the natural insertion point for synthetic
candidates later — no architectural rework implied.

---

## Section 7 — Input / PlayerModule Review

`src/client/PlayerModule/` is a fork of Roblox's PlayerModule.
`CameraModule/`, `ControlModule/`, `CommonUtils/`, `ServerAuthority/` are
stock Roblox source (standard camera-type files: `ClassicCamera`,
`OrbitalCamera`, `VRCamera`, `VehicleCamera`, etc. — unmodified as far as this
pass checked; not read line-by-line per the plan's scope). The genuinely
custom layer is `Combat/` — a device-independent input/camera module built
*on top of* the stock camera controller rather than replacing it.

**Camera/cursor ownership** is a reference-counted map keyed by reason string
(`CombatCamera.luau:20,31`), not a boolean — multiple simultaneous claimants
(menu, mode-vote, window-focus) genuinely can't stomp each other, and
`Combat.requestCursor` proactively cancels any in-progress charge as a
backstop even if a caller forgets to (`init.luau:105-111` →
`cancelEverything`). This is a well-built pattern. The one gap in it is
AUDIT-001 (a caller that *should* hold a reason but doesn't, not a flaw in
the reference-counting itself).

**Touch arbitration:** `TouchIntent`'s state machine is single-owner per
touch — a touch that has resolved to `Charging`/`Consumed`/`Camera` cannot be
reclassified, and `beginCharge` only fires from `Pending` with no existing
charge owner. No path found where one physical touch fires two intents.

**Controller:** Genuinely first-class, not an afterthought — `ArenaMenu.luau`
explicitly manages `GuiService.SelectedObject` on open/close/tab-change and
restores prior selection on close, defaulting focus for gamepad input method.
See AUDIT-012 for the one architectural coupling note (gamepad aim rides on
the stock camera rather than an explicit AimDirector branch — works today,
worth a comment).

**Character lifecycle:** `CharacterAdded`/`CharacterRemoving` are connected
exactly once per module in each module's own `start()` — no stacking across
respawns found in `ArmIK`, `WeaponAnimations`, `DeathEffects`, `CombatState`,
or `PlayerHighlights`. `DeathEffects.bindCharacter` explicitly disconnects
the prior character connection before rebinding.

---

## Section 8 — Party / Matchmaking / Teleport Review

See Section 3 for the end-to-end flow and Section 4 (AUDIT-003) for the one
concrete gap. Additional detail:

- **Leadership:** Auto-promotion on leader removal is real and automatic
  (`PartyModel`, invoked from `_removeMemberFromParty`/`_kickMember`).
  Mid-transition phases (`Claimed`/`Assigned`/`Teleporting`) explicitly block
  member removal, so a disconnect can't dissolve a party mid-teleport.
- **Double-party window:** Between a party-membership commit and the
  user→party index update, there's a narrow theoretical window where a crash
  could leave the index stale — `_sweepStaleMembers` self-heals this on the
  next pass. Bounded, not a permanent corruption path.
- **Claim lease:** `MatchmakerService` claims carry an expiry
  (`Config.ClaimLifetime`); a party that changed/dissolved between enqueue
  and claim causes the claim to silently fail and the stale queue entry gets
  reconciled on the next tick, not stranded.
- **Partial-party teleport failure:** A member whose teleport ultimately
  fails after retries is moved into a fresh solo party while the rest of the
  party has already gone to the arena. This reads as intentional
  fail-forward behavior (the alternative — blocking the whole party on one
  member — is arguably worse), but is worth confirming against product
  intent (Section 19).
- **Cross-place trust:** Both directions (lobby→arena, arena→lobby)
  independently check `SourcePlaceId`/`SourceGameId` before trusting a parsed
  payload. This is the correct pattern and was verified, not assumed.

---

## Section 9 — Gameplay / Combat Review

- **Dodgeball:** Throw is rejected if the (server-computed) aim origin is too
  far from the sim's own character position — a second independent distance
  check beyond how the origin is constructed in the first place. Soft-lock
  target validation (cone, team, line-of-sight, distance) is recomputed from
  the authoritative world snapshot; a client-supplied `targetId` is only ever
  a hint. Catch window and collision are server swept-sphere tests.
- **Hammer:** Hit resolution is geometric and server-computed each tick
  (closest target in front, team/alive/invulnerable filtering); the
  cooldown → active-dash → recovery phase machine (the documented
  whiff-punish mechanic) is intact and covered by spec.
- **Aim assist:** Config-driven per device class (`AimAssist`), resolved
  through a pure `AssistResolver` that's independently spec-tested for
  device-scale gating, unknown-device fallback, and out-of-range rejection.
  Presentation-only — never grants server-side hit credit by itself (hit
  legitimacy is still recomputed independently, per above).
- **Physics/tunneling:** `Projectiles.luau`'s substepping (max 8) and swept
  collision are the documented mitigation for high-velocity tunneling; this
  matches the spec suite's explicit "does not tunnel through thin walls at
  high speed" case. Not independently re-derived in this pass beyond
  confirming the spec exists and the substep cap is real in code.
- **Mode voting:** See Section 3 — the generation-counter handling of the
  finish/extend race is a standout, deliberately defensive piece of code.
- **Game modes:** FFA/TDM/Infection share the `GameMode` interface;
  mode-specific logic (team scoring, infection conversion, time-cap winner)
  lives in each mode file, not scattered across `MatchService`. Reasonable
  amount of shared abstraction — not over-engineered, not duplicated in a way
  that risks drift.

---

## Section 10 — UI / UX Technical Review

- **Screen ownership:** each major surface (`ArenaMenuClient`,
  `ModeVoteClient`, `PostMatchClient`, `ArenaLoadingClient`) owns its own
  snapshot/subscribe pair; no two adapters were found writing the same piece
  of visible state.
- **Modal/cursor conflicts:** see AUDIT-001 — the only confirmed gap.
- **Responsive design:** see AUDIT-002 — the only confirmed gap; everything
  else sampled (`CombatHUD`, `PostMatchScreen`, `ResponsiveText`) scales via
  `useViewportSize`/`UIScale` correctly.
- **Controller navigation:** confirmed built (Section 7); every critical flow
  sampled had explicit `SelectedObject` handling.
- **Onboarding:** `ThrowUX`'s onboarding flag is server-persisted
  (`ThrowUXService`/`PlayerData.markSwipeThrowLearned`) and the swipe/tap/hold
  gesture classification it depends on is the same single-owner
  `TouchIntent` state machine used for real combat input — onboarding isn't
  a separate, divergent input path that could teach the wrong mental model
  or leave stale listeners behind.

---

## Section 11 — Data / Economy Review

**Persistence:** `ProfileStore`-based, with a write-through proxy
(`WriteThroughProxy`) so consumers never hold a second copy of profile data.
`Data.load`/`Data.save` use a generation counter (`_loadGeneration`) so a
stale load callback from a rejoin-during-load sequence can't clobber a newer
one. **Shutdown is correctly handled by the library itself** — `ProfileStore`
registers its own `game:BindToClose` (verified in
`Packages/_Index/vyon_profilestore@1.0.3/profilestore/ProfileStore.luau:2208-2235`)
that blocks shutdown until every active profile's session has saved; the
game's own `Server.server.luau` `BindToClose` loop calling `PlayerData.save`
per player is a harmless, idempotent secondary safety net on top of an
already-correct primary one.

**Monetization:** See AUDIT-007. Receipt handling follows Roblox's
recommended idempotent-ledger pattern; the one residual risk is inherent to
that pattern's persistence timing, not a code defect.

**Economy guardrail:** `AGENTS.md`'s stated invariant ("no weapon, movement,
damage, cooldown, or health value is ever for sale") was not contradicted by
anything read in `Products.luau`/`GamePasses.luau`/`Crates.luau` structure —
progression boosters affect earn *rate* only (`Boosts.luau`'s pure "best of,
not compounding" stacking rule), consistent with the stated policy.

**Inventory/cosmetics:** Ownership and equip validation both go through one
pure function (`CosmeticsLogic.canEquip`), shared by server enforcement and
(per its own doc comment) an eventual client pre-validation path — same
function, same answers, no drift risk between "what the server allows" and
"what the UI shows as allowed."

**Season/progression:** See Section 12 — more complete than the audit brief's
product context suggested.

---

## Section 12 — Incomplete Systems

- **Infection mode:** Deliberately soft-disabled (`Enabled = false` in
  `src/config/GameModes.luau`, with a spec explicitly asserting the disabled
  stub is retained). Fully implemented otherwise (patient-zero selection,
  conversion-on-elimination, time-cap-to-survivors win condition, all spec
  covered). **Missing piece:** nothing structural — this reads as a
  deliberate rollout lever, not an unfinished feature.
- **Scramble mode:** See AUDIT-005. Resolved — deleted per product decision
  during the remediation pass; no longer present in the repo.
- **Post-match / progression / results:** **More complete than the audit
  brief's product context implied.** `PostMatchService`, `PostMatchResult`,
  and `ProgressionService` form a working, event-deduplicated,
  party-grouped result-delivery pipeline with a full spec suite
  (`PostMatchResult.spec.luau` covers ordinal placement, malformed-packet
  rejection, victory-from-team-membership derivation). What's genuinely
  future-facing: the `BattlePassService`/season-pass layer exists with real
  claim/premium/rollover logic and specs, but content authoring (actual
  season definitions, reward tables) wasn't verified as populated beyond
  what the spec fixtures exercise — that's a content question, not an
  architecture gap.
- **Quests:** `QuestService`/`QuestLogic` are fully implemented (daily
  selection, UTC reset, event-to-progress mapping) with dedicated specs; no
  incompleteness found.

---

## Section 13 — Dead / Legacy Code

| Item | Confidence it's dead | Evidence | Status |
|---|---|---|---|
| `src/client/PlayerModule/Combat/CombatDebug.luau` | High | Zero references anywhere, including its own directory's public `init.luau`. | **Deleted** (confirmed with user). |
| `src/shared/Game/Modes/Scramble.luau` | Medium (unreachable, not necessarily "dead" if intended for future use) | Not in `ModeRegistry` or `GameModes` config; fully implemented interface. | **Deleted** (confirmed with user). |
| Stock PlayerModule variants not used by this game (`ClickToMoveController`, several VR camera files) | Low confidence they're "dead" in the audit sense | These are vendored stock Roblox code, selected/unselected by runtime settings the game doesn't override — normal for a PlayerModule fork to carry capability it doesn't currently expose, not a maintenance defect. | Left as-is; not recommended for removal. |

Both deletions were confirmed with the user before being made — this table
originally recommended documenting rather than deleting, per the audit's own
"do not remove them" instruction; the deletions above happened only in the
subsequent, explicitly-requested remediation pass.

---

## Section 14 — Positive Findings

These are patterns worth actively preserving in any future refactor:

- **Server-authoritative combat**, verified end-to-end: origin always from
  the live server root, hit legitimacy always recomputed from the
  authoritative world snapshot, client-claimed target/hit is never trusted.
- **`ModeVoteService.finishVote`'s generation-counter pattern** —
  textbook-correct handling of "can a stale scheduled callback fire after
  the state it captured is gone," including the reschedule-on-extension
  case.
- **Cross-place trust boundary** — real schema validation *and* independent
  source-place/universe checks on both lobby→arena and arena→lobby payloads.
- **`ProfileStore`'s built-in shutdown safety net**, with the game's own
  redundant `BindToClose` doing no harm on top of it.
- **Party leadership/disconnect handling** — auto-promotion, in-transition
  removal guards, and claim-lease self-healing all use explicit phase/
  generation checks rather than ad-hoc booleans.
- **`EventDedup` used consistently** across every sim/match event consumer
  checked (`ProgressionService`, `QuestService`, `AnalyticsService`,
  `BallVisuals`, `HammerVisuals`, `SplatEffects`, `GameAudio`) — a single
  reusable guard rather than N hand-rolled seen-tables.
- **`CombatCamera`'s reason-keyed, reference-counted cursor ownership** — the
  right shape for a resource multiple systems need to borrow; AUDIT-001 is a
  missing *caller*, not a flaw in the mechanism.
- **Deterministic sim discipline** — native `vector` type, `SimUtil.sortedKeys`
  used everywhere iteration order matters, 447 passing specs including
  bit-identical-replay and command-arrival-order-independence tests.
- **`AGENTS.md` itself** — unusually accurate as a source of truth; nearly
  every architectural claim it makes was independently confirmed against
  real code in this pass, which is not the norm for hand-written
  architecture docs.

---

## Section 15 — Prioritized Remediation Roadmap

**Status as of the 2026-08-25 remediation pass:** everything below marked
✅ is done; the roadmap is left intact (rather than deleted) so the
before/after reasoning stays visible.

**P0 — Must fix before meaningful public testing:** none. No CRITICAL
findings exist.

**P1 — Before launch:**
- ✅ AUDIT-001 (loading-screen cursor lockout) — fixed.
- ✅ AUDIT-003 (join-code brute-force hardening) — fixed.

**P2 — Early post-launch / polish:**
- AUDIT-002 — retracted on re-read; no fix needed (see Section 4).
- ✅ AUDIT-011 (analytics payload validation) — fixed, and narrowed to what
  was actually true once traced.
- ✅ Scramble's fate (AUDIT-005/010) — decided (deleted) and closed.

**P3 — Future:**
- AUDIT-004 (move dev-gate constants server-side) — evaluated, deliberately
  not applied; cost (breaks the only test coverage this module has, needs
  new Rojo project wiring) outweighs a LOW/optional finding.
- AUDIT-009 (matchmaking scale monitoring) — no code change, still a
  standing observability note for whenever real production telemetry exists.
- AUDIT-012 (explicit gamepad aim contract) — evaluated, deliberately not
  applied; conflicts with this session's own no-inline-comments convention.
- ✅ AUDIT-006 — fixed (deleted). AUDIT-008 — no action needed per its own
  original assessment.

---

## Section 16 — Quick Wins

- ✅ **AUDIT-001:** done — `ArenaApp.luau` now holds the cursor exactly
  while a loading-screen action button is on screen.
- ✅ **AUDIT-005/010:** done — Scramble deleted per product decision,
  closing the open question.

No other findings met the "high impact, near-zero cost" bar strongly enough
to have been listed here originally, and none has changed that since.

---

## Section 17 — Risk Matrix

| Area | Probability | Player Impact | Exploitability | Difficulty to Fix |
|---|---|---|---|---|
| Combat | Low | Low | Low | — |
| PlayerModule/Input | Low | Low (AUDIT-001 fixed) | None | Low |
| Party | Low | Low | Low | Low |
| Matchmaking | Low | Low | None | — |
| Teleport | Low | Low | None | — |
| Game modes | Low | Low | None | — |
| UI | Low (AUDIT-002 retracted) | Low | None | Low |
| Data | Low | Low (bounded by AUDIT-007) | None | — |
| Performance | Low (no measured issue) | Unknown at scale | None | — |
| Mobile | Low | Low | None | — |
| Controller | Low | Low | None | — |

---

## Section 18 — Recommended Test Plan

Focused on the actual risk areas this audit found, not a generic device
matrix:

- **PC, mouse/keyboard:** deliberately fail a loading/streaming step (block
  an asset or simulate a slow join) and confirm the retry/continue button on
  `LoadingScreen` is clickable — this directly targets AUDIT-001.
- **PC, mouse/keyboard vs. touch vs. controller, party of 2+:** join a live
  party by code from a second account rapidly with wrong codes, confirm the
  per-action throttle actually engages within the tested window (AUDIT-003).
- **Phone (small screen) and tablet:** open the Shop from both lobby and
  arena menus, check row heights against the rest of the UI for
  disproportionate sizing (AUDIT-002).
- **Party of 2+, one member's connection intentionally dropped mid-queue and
  again mid-teleport:** confirm leadership transfer and the
  in-transition-removal guard behave as traced in Section 8.
- **High-latency simulation** on a dodgeball throw and hammer swing: confirm
  server-side origin/hit recompute (Section 9) holds up — this is the
  highest-value combat test since it's the actual trust boundary.
- **All three registered modes (FFA, TDM, Infection)** through a full vote →
  match → results cycle, including a vote that ties and a vote extended by a
  late-ready player, to exercise the `deadlineRevision` path for real.
- **Respawn stress:** die and respawn repeatedly in quick succession, watch
  for any visual/IK/camera state that fails to reset (nothing found in
  static review, but this is exactly the class of bug static review is
  weakest at catching).
- **Solo play via `DevMatchSkip`/`DevEndMatch`** (added this session) as a
  fast way to exercise the full post-match → progression → return-to-lobby
  loop repeatedly during the rest of this test plan.

---

## Section 19 — Questions Requiring Product Input

1. ~~Is `Scramble` intentionally shelved, or forgotten?~~ **Answered and
   resolved** during the remediation pass — deleted (AUDIT-005).
2. **Is the partial-party-teleport-failure behavior (successful members go
   to the arena, the failed member becomes a fresh solo party) the intended
   product behavior, or should the whole party's teleport be atomic (all
   succeed or all retry together)?** (Section 8.) Current code clearly
   chooses fail-forward; I can't tell from the code alone whether that's a
   deliberate design call or an accepted-but-unreviewed side effect of how
   `TeleportRetryCoordinator` happens to be structured. Still open — no code
   change was made here since it's a design question, not a defect.
3. ~~How much investment does the Shop's visual consistency warrant before
   launch?~~ **Moot** — AUDIT-002 was retracted; the Shop's responsive
   handling turned out to already be adequate on closer reading.

---

*This audit was followed by a remediation pass on 2026-08-25 (see the
addendum near the top of this document). Production code was modified in
that pass, scoped exactly to the fixes and deletions itemized there and
confirmed with the user; the audit content above is otherwise left as
originally written, with corrections clearly marked rather than silently
edited away.*
