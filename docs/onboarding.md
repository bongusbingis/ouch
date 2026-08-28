# First-session onboarding

The onboarding is a complete first-session experience, not a tutorial popup. It
runs inside the **lobby** place, before the normal lobby is revealed, and it
teaches exactly three things: **normal throw**, **hammer**, **charged throw**.
Nothing else is explained. There is no lob mechanic and onboarding never
mentions one.

It is built on the real combat systems. A player who finishes training has
already thrown a real dodgeball, at a real simulation character, with the real
camera, the real aim assist, the real charge UX, and the real hit resolution.

---

## 1. Architecture found, and what changed to support this

The combat runtime used to live entirely under `places/arena/`. Onboarding
needs it in the lobby, so it was promoted to `src/` — the repository's own rule
is that `src/` is what both places load and `places/` is what only one does.
The arena's runtime tree is byte-for-byte the same shape it was; only the
on-disk location and the project files changed.

| Moved from | Moved to |
|---|---|
| `places/arena/client/Modules/Input/*` | `src/client/Game/Input/` |
| `places/arena/client/Modules/Presentation/*` (combat feel only) | `src/client/Game/Presentation/` |
| `places/arena/client/Modules/UI/ThrowUXClient.luau` | `src/client/Game/UI/` |
| `places/arena/client/UI/CombatHUD.luau` | `src/client/Game/UI/` |
| `places/arena/server/Modules/BallService.luau` | `src/server/Modules/` |
| `places/arena/server/Modules/CmdrService.luau` | `src/server/Modules/` |

Arena-only presentation (`VoteCamera`, `MatchAudio`, `MatchAudioLogic`,
`PlayerHighlights`, `JumpPadVisuals`), `Movement/PlatformRider` and `Debug/*`
stayed in `places/arena/`, and both project files overlay them back into the
same `Client.Modules.Presentation` folder the arena has always had.

Two arena-specific policies were hardcoded inside the shared
`ServerAuthAdapter`: `ArenaAdmission`/`ArenaReady` per player, and
`ReplicatedStorage.MatchState.phase == "Active"` globally. Both are now
injected:

**`src/shared/Game/Adapters/CombatSession.luau`** is the single owner of
"is combat live for this player, in this place". The server installs one host;
the answer is projected onto one player attribute (`CombatLive`) that every
client combat module reads. The arena's host is the match; the lobby's host is
an active training session.

```
                      server host                     projection
Arena:   ArenaReady + MatchState.phase == "Active"  →  player.CombatLive
Lobby:   player has an active onboarding session    →  player.CombatLive
```

`ServerAuthAdapter` also gained two narrow seams, both used by onboarding:

- `registerCharacterSource(name, fn)` — non-player simulation characters.
  `SimCore` keys characters by opaque strings, so a training dummy fights by
  exactly the rules a player does, and **no simulation code is aware training
  exists**. A registered entry may widen its own hit radius, which is how
  target leniency is expressed without loosening the weapon.
- `setRuleOverride(rules)` — a host with no game mode states its rules
  directly. Onboarding sets `preserveDodgeballs = true`, which is what makes
  the ball come back after every throw with no onboarding-specific code.
- `equipWeapon(player, weapon)` — a server-side equip. The hammer lesson needs
  the hammer in hand on every device, and the routing rule sends a `Throw` to
  the *equipped* kit, so the choice has to be stated rather than implied.

Everything else the onboarding uses already existed: `PlayerData` (ProfileStore
+ Replica), `AnalyticsService` (`logFunnelStep` / `logCustomEvent`),
`Network` (one declarations table), `PartyService`, `UIFeedback` (haptics),
`CameraShaker`, `useReducedMotion`, `ResponsiveText`, `AnimatedButton`,
`Motion`, and `CmdrService`.

---

## 2. Onboarding architecture

```
Player joins lobby
        │
        ▼
PlayerData.onLoaded ──► OnboardingService.resolveRoute
        │                       │
        │                       ├─ profile unavailable ─► route "Lobby" + OnboardingError
        │                       ├─ settled status      ─► route "Lobby"
        │                       └─ eligible            ─► beginSession
        ▼
player.OnboardingRoute  ("Training" | "Lobby")
        │
        ▼
LobbyClient blocks on the answer (fail-open after ResolveTimeoutSeconds)
        │
   ┌────┴─────────────────────────┐
   ▼                              ▼
Training overlay + CombatHUD   Normal lobby
+ suppressed lobby
```

A session then runs one step at a time:

```
Eligibility → Session → Step → Checkpoint → CoreComplete → Completed / Skipped
```

- **Eligibility** — `OnboardingState.isEligible`, from the persisted status.
- **Session** — one training ring, one slot, one player. Owned by
  `OnboardingService`; nothing else decides what step a player is on.
- **Step** — `OnboardingSteps.Ordered`. The step is advanced by a **simulation
  event**, never by a button press: the player has to actually land the hit.
- **Checkpoint** — persisted the instant a step completes.
- **CoreComplete** — persisted the instant the *third* mandatory mechanic
  lands. From that moment the player is never auto-started again, even if they
  disconnect one second later.
- **Completed** — the whole thing, including the practice fight and the
  celebration.
- **Skipped** — a deliberate choice, remembered with the step it happened on.

The state owner coordinates every consequence: prompt, target, dummy, player
equipment, camera and input handover, combat permission, effects, analytics,
persistence, and the transition out. No other system decides tutorial progress.

---

## 3. Files created and modified

### Shared, pure (spec-tested headlessly)

| File | Role |
|---|---|
| `src/shared/Game/Onboarding/OnboardingSteps.luau` | The ordered step list — ids, prompts, what each demands. The server, the UI and analytics all name the same thing. |
| `src/shared/Game/Onboarding/OnboardingState.luau` | The status model: eligibility, resume point, the CoreComplete moment, skip, and explicit version migration. |
| `src/shared/Game/Onboarding/OnboardingLayout.luau` | Ring geometry: slot allocation, spawn, target and portal positions, fall height. Native `vector`, no engine types. |
| `src/shared/Game/Onboarding/OnboardingAnalytics.luau` | Fixed funnel step numbers and the low-cardinality property builders. |
| `src/shared/UI/Models/OnboardingViewModel.luau` | Snapshot → headline, gesture notation, hint, and the placement rule that keeps the indicator off everything else. |
| `src/shared/Game/Adapters/CombatSession.luau` | Who is fighting, here. |

### Shared, engine

| File | Role |
|---|---|
| `src/config/Onboarding.luau` | Every onboarding tunable. Nothing else carries a magic number. |
| `src/shared/UI/Components/GestureGlyph.luau` | The one way the game draws "do this input", used by training and by the arena's swipe tip. |
| `src/shared/UI/Components/OnboardingOverlay.luau` | The chrome: instruction panel, skip, party choice, completion card. |
| `src/shared/UI/Components/OnboardingGestureLayer.luau` | Places the indicator at the real input point, uninset. |
| `src/shared/UI/Stories/OnboardingOverlay.story.luau` | Every step × every device × every variant, plus the four notations side by side. |

### Lobby server

| File | Role |
|---|---|
| `places/lobby/server/Modules/Onboarding/OnboardingService.luau` | The single flow owner. |
| `places/lobby/server/Modules/Onboarding/OnboardingWorld.luau` | Programmatic prototype ring builder. |
| `places/lobby/server/Modules/Onboarding/TrainingDummies.luau` | Dummies as real simulation characters, plus their knockout and return. |
| `places/lobby/server/Modules/Onboarding/PracticeBots.luau` | The two wandering opponents of the practice beat. |
| `places/lobby/server/Modules/Onboarding/OnboardingDebug.luau` | The one guarded implementation behind every developer command. |
| `places/lobby/server/Cmdr/Commands/sb-onboarding*.luau` | Developer-console front door for the above. |

### Lobby client

| File | Role |
|---|---|
| `places/lobby/client/Modules/Onboarding/OnboardingClient.luau` | Snapshot, camera/input handover, effects, haptics, device tracking, fail-open routing. |
| `places/lobby/client/UI/OnboardingApp.luau` | React root for the overlay. |

### Modified

`Network.luau` (two remotes), `Config/Data.luau` (profile branch),
`Config/Analytics.luau` (funnel + events), `PlayerData.luau` (onboarding
mutators + attribute projection), `ServerAuthAdapter.luau` (host seams),
`AimDirector.luau` / `ChargeAim.luau` / `CombatState.luau` /
`CombatInputSender.luau` (read `CombatSession`), `InputRouter.luau` (no longer
knows the mode vote exists), `WeaponAnimations.luau` (required clips preload off
the input path), `WorldAudio.luau` (tolerates a place without the legacy
templates), `PartyService.luau` (snapshot observer), `LobbyApp.luau`
(suppression + play emphasis), `SplashPage.luau` (play emphasis), both entry
scripts of both places, and both project files.

---

## 4. The player flow as implemented

| Beat | What happens |
|---|---|
| Join | Loading screen stays up while the server answers. No lobby flash. |
| ~0 s | Character is placed in a padded ring facing the first dummy. Combat camera and input are live immediately. There is no cinematic and no Continue button. |
| +0.35 s | `THROW!` and the input glyph pop in. |
| First throw | Real dodgeball, real aim assist. The dummy squashes, launches, spins, and sails away with an impact sound, a camera shake and a haptic pulse. |
| +0.55 s | `BONK!`. The ball is taken away and the hammer is equipped, so a press means "swing" on every device. A goofy dummy waddles into reach and stops. |
| Hammer hit | Same payoff, harder. |
| +0.55 s | `HOLD FOR POWER!`. A ball is handed back; a target appears far away and raised. |
| Charged throw | Accepted only above `MinimumChargeAlpha`. A tap that happens to reach knocks the dummy over but does not pass the lesson — the target returns and the prompt stays. |
| CoreComplete | Persisted immediately. |
| Practice | `KNOCK THEM OUT!`. Two easy bots approach and circle. Ends on two knockouts or `PracticeMaxSeconds`. |
| Celebration | Confetti burst, portal opens, `READY!` with ✓ THROW ✓ BONK ✓ POWER. |
| Reveal | Route flips to Lobby, the overlay unmounts, the lobby camera and cursor are restored, and the Play button gets a single entrance emphasis. |

Missing is never punished. There is no failure text, no reset screen, and no
death: the player is invulnerable (`minv`) for the whole session, so no
respawn ever interrupts a 45-second experience.

**Assistance escalates rather than arriving all at once.** After
`InactivityHintSeconds` the prompt re-animates and the target pulses. After
`EscalatedHintSeconds`, or `EscalateAfterAttempts` failed attempts, the dummy's
hit radius widens by `EscalatedForgiveness` and one short line appears. The
onboarding never performs the action for the player.

---

## 5. World prototype

Everything the training world is made of is built in code, under one named
container, because the lobby place file is a Studio-authored binary this
repository never writes.

```
Workspace.OnboardingArenas
  Ring<slot>
    Floor, InnerRing        padded cylinder + accent ring
    Pad1..Pad16             soft perimeter wall
    Column1..Column4        rounded columns
    TargetSpotlight         moves to the current lesson's target
    Portal                  opens at the celebration
    CelebrationAnchor       confetti emitter
Workspace.OnboardingDummies
  dummy_<n>                 cloned Assets.Rigs.CharacterRig
```

**Per-player isolation is spatial and total.** `OnboardingLayout` allocates a
grid slot per session, `SlotSpacing` studs apart, far above the lobby proper.
Two onboarding players never share a ring, so one player's dummy, ball, target,
or knockout cannot touch another's session, and lobby players cannot wander
into either. A slot is released when the session ends and reused by the next.

The rings are also the reason combat in the lobby is safe: `CombatSession`
makes a player a combat character only while they have a session, so a training
throw can never reach the lobby crowd and a lobby player is never a target.

---

## 6. UI / UX

The training UI is built from the game's own kit: the same nine-slice panel
(`124751224634629`) and button art (`136021539696619` / `94748581468730`) the
loading screen, notification modal and shop use, LuckiestGuy headlines with the
shared dark stroke (`24, 41, 48`), HighwayGothic for secondary lines, and the
shared `Motion` springs. There is no bespoke panel treatment anywhere in it.

### Two roots, on purpose

| Root | Insets | Holds |
|---|---|---|
| `OnboardingRoot` | `DeviceSafeInsets` | Instruction panel, skip, party choice, completion card |
| `OnboardingGestureRoot` | `None` | The input indicator only |

The indicator has to be drawn in **raw viewport pixels**, because that is the
coordinate space `TouchIntent` classifies taps, holds and swipes in. Drawing it
in an inset-adjusted root would put the picture a topbar's height away from
where the finger is actually read. The chrome has the opposite requirement and
gets the safe-area root.

### The gesture notation

`GestureGlyph` is the one component that draws "do this input", and it uses the
established touch documentation notation rather than inventing symbols:

| Kind | Drawn as | Means |
|---|---|---|
| `Tap` | Filled dot, ring leaving it and fading | Contact and release |
| `Hold` | Ringed dot, ring closing onto the dot | Contact that stays down |
| `Swipe` | Dot running a trail to a chevron | Contact that travels, and which way |
| `Action` | The platform's own key glyph on a plate | Press this button |
| `ActionHold` | That glyph inside the closing ring | Press and hold this button |

The timings are not decorative. The hold ring closes over exactly
`CombatConfig.Charge.HoldDelay`, the real delay before a press becomes a
charge, and the swipe trail runs exactly `TouchRegions.scale(BottomSwipe.MinDistance)`,
the real distance a swipe must travel to register.

### Platform-correct glyphs, by construction

Mouse and gamepad prompts are drawn by **`InputActionLabel`** bound to the real
`Throw` `InputAction`. The engine resolves the glyph for the device in the
player's hands — Xbox art on an Xbox pad, PlayStation art on a DualSense — and
re-resolves on a device switch with no scripting on our side. Its resolution
order is binding `DisplayImage` → `GetImageForKeyCode` → binding `DisplayName`
→ `GetStringForKeyCode`, so `Config.Input` now carries a `DisplayName` per
binding: the mouse binding says `LMB` rather than falling through to
`"MouseLeftButton"`, and the gamepad binding deliberately leaves it unset so the
platform's own button art wins. A client too old for `InputActionLabel` falls
back to the binding's text, decided once by a probe.

Touch keeps the drawn notation, because a gesture is a motion rather than a
button and no glyph can state it.

### Where the indicator sits, and why it cannot collide

`OnboardingViewModel.gesturePlacement` is pure and spec-tested. It reads the
real regions from `Combat.inputGeometry()` — press centre, swipe rect, tap drift,
hold delay — rather than assuming any of them, and derives the reticle's largest
extent the same way the combat HUD sizes it. The rule:

- **Below the reticle** whenever the whole assembly fits above the swipe region.
  That is the direction the eye already travels, and it is inside the region a
  tap or a hold is read in.
- **Beside the reticle** when the viewport is too short for that — which is real
  on phone landscape. Still inside the same region, still clear of the reticle,
  clamped to stay on screen, and far from both the thumbstick and the hammer
  button.

Measured on the shipped values:

| Viewport | Glyph band | Reticle band | Swipe region top | Placement |
|---|---|---|---|---|
| 1920×1080 | 607–712 | 507–573 | 778 | below |
| 1366×768 | 444–527 | 358–410 | 553 | below |
| 896×414 | 203–271 | 181–233 | 298 | beside (x 512) |
| 844×390 | 191–259 | 169–221 | 281 | beside (x 486) |
| 1180×820 | 470–558 | 384–436 | 590 | below |
| 820×1180 | 650–738 | 564–616 | 850 | below |

Nothing in the indicator is a `GuiButton`, so it cannot sink a touch in the very
region it is pointing at.

### The rest of the chrome

- **Instruction panel** — top band, nine-slice, headline plus at most one
  clarifying line. It tints to the highlight yellow and overshoots on a success.
- **Skip** — top-right, on the real button art. First press arms it (`SKIP?`),
  a second press inside `SkipConfirmSeconds` commits. Mouse, touch and
  controller focus all reach it.
- **Party choice** — the game's own `NotificationModal`, so it looks like every
  other confirmation and gets its gamepad focus handling for free. It replaced a
  hand-rolled bottom bar that sat on top of the jump button and the thumbstick.
- **Completion** — the same panel with `READY!` and the three earned skills on
  button chips.
- **Swipe-throw tip** — owned by `ThrowUXClient`, which already ran its show,
  dismiss and persist lifecycle. Training does not draw a second one; it
  installs a gate (`ThrowUXClient.setHintGate`) so the tip is held back until the
  throw lesson has been passed. The tip itself is now the `Swipe` notation drawn
  inside the real swipe rect, which the arena gets too.
- **Reduced motion** — every spring goes immediate through `useReducedMotion`,
  and `OnboardingClient.effectScale()` returns zero, which turns off camera
  shake and haptics together. Comprehension never depends on motion, colour or
  sound: the headline alone states the action.

## 7. Persistence

Stored in the profile under `Onboarding`, written only through
`PlayerData.updateOnboarding`, which takes a pure transition from
`OnboardingState`:

| Field | Meaning |
|---|---|
| `Version` | Which onboarding version this state belongs to |
| `Status` | `NotStarted` / `InProgress` / `CoreComplete` / `Completed` / `Skipped` |
| `Checkpoint` | Last completed step id |
| `SkippedAt` | Step the player skipped on |
| `Sessions` | Sessions started, for abandonment analysis |

Projected to the client as read-only attributes `OnboardingStatus`,
`OnboardingCheckpoint`, `OnboardingRoute`, `OnboardingStep`, `OnboardingHint`.
The client never re-derives eligibility.

**On rejoin:** `Completed`, `CoreComplete` and `Skipped` all go straight to the
lobby. `InProgress` resumes at the step *after* the stored checkpoint.
A checkpoint naming a step that no longer exists is ignored rather than
crashing.

**Versioning is explicit.** `OnboardingState.migrate` leaves a settled player
settled across a version bump — nobody is dragged through a redesign. Only
*partial* progress against an older version is discarded, because it cannot be
trusted to line up with the current step list.

---

## 8. Analytics

Funnel `Onboarding` (`Config.Analytics.Funnels.Onboarding`), with fixed step
numbers that must never be renumbered:

| Step | Name |
|---|---|
| 1 | `Started` |
| 2 | `NormalThrow` |
| 3 | `Hammer` |
| 4 | `ChargedThrow` |
| 5 | `Practice` |
| 6 | `Completed` |

Custom events: `OnboardingEligible`, `OnboardingStarted`, `OnboardingResumed`,
`OnboardingStepStarted`, `OnboardingStepCompleted`, `OnboardingCoreComplete`,
`OnboardingCompleted`, `OnboardingSkipped`, `OnboardingAbandoned`,
`OnboardingError`, `OnboardingLobbyRevealed`.

Properties are low-cardinality and fixed: `stepId`, `attempts`, `escalated`,
`resumed`, `coreComplete`, `status`, `reason`
(`Completed|Skipped|PartyMatch|Left|Timeout|Error`), plus the `deviceClass` and
`assistBucket` dimensions `AnalyticsService` stamps on everything. Durations
are the event *value*, rounded to 1/100 s.

Directly answerable from this: eligibility rate, start rate, core completion
rate, full completion rate, skip rate, **skip location**, step abandonment by
step, time to first throw, time to first hit, time to hammer hit, time to
charged throw, total duration, attempts per mechanic, and every one of those
sliced by device.

Nothing is logged per frame, per touch move, per trajectory update or per
projectile step. Abandonment is derived from the session lifecycle rather than
a hypothetical clean quit: `PlayerRemoving` ends the session with reason
`Left`, carrying the last stable step, the time spent, and whether
`CoreComplete` was already reached.

Downstream correlation works because `OnboardingLobbyRevealed` fires with its
reason on the same player as the existing `Matchmaking` funnel, so
`onboarding → lobby → play → queue → match` is one join away in the dashboard.
Onboarding does not own any lobby analytics.

---

## 9. Party integration

Onboarding **never writes party state**. `PartyService` remains its only owner;
onboarding subscribes through `PartyService:SetSnapshotObserver`.

| Situation | Behaviour |
|---|---|
| Player arrives already in a party (invite, profile join, code) | Party is preserved untouched. Training runs privately. |
| Party starts matchmaking (`Queued` / `Claimed`) while training | `YOUR PARTY IS READY!` — join or keep training. Asked once. |
| Party is `Assigned` / `Teleporting` | Hard override: the session ends immediately with reason `PartyMatch`. A real match always wins, and progress is already persisted per step. |
| Onboarding player is party leader | The lobby Play flow is hidden during training, so they cannot queue mid-lesson; matchmaking naturally waits for them to finish or skip. No second leadership concept is introduced. |

Because the lobby root stays mounted (suppressed, not destroyed) the party
adapter, its snapshots and its socket keep running throughout, so nothing
about party membership can be lost by training.

---

## 10. Debug tools

Guarded by the same `Env.Cmdr` gate the developer console uses, checked on
every call — never installed-and-forgotten. Outside Studio, only the creator or
an allowlisted user id can touch stored progression.

Developer console:

```
sb-onboarding Reset            <player>
sb-onboarding Force            <player>
sb-onboarding StartAt          <player> NormalThrow|Hammer|ChargedThrow|Practice
sb-onboarding MarkCoreComplete <player>
sb-onboarding MarkCompleted    <player>
sb-onboarding MarkSkipped      <player> [step]
sb-onboarding Finish           <player>
sb-onboarding Status           <player>
```

Studio command bar (same implementation, second front door, Studio only):

```lua
require(game.ServerStorage.OnboardingDebug):Invoke("StartAt", nil, "Hammer")
require(game.ServerStorage.OnboardingDebug):Invoke("Status")
```

`Status` prints the stored status, checkpoint and version alongside the live
session's step and attempt count.

---

## 11. Effects and audio

Impacts already run the game's real presentation: a dummy is a simulation
character, so a hit on one produces the same `Elim` event a hit on a player
does, and `SplatEffects`, `GameAudio` and `DamageFeedback` respond to it
without knowing training exists. What onboarding adds on top is the comedy and
the punctuation.

| Beat | Effect |
|---|---|
| Any dummy hit | The rig squashes through its own `BodyWidthScale`/`BodyHeightScale`, then launches and cartwheels on an axis derived from the hit direction. A neon ring snaps outward from the impact point and fades. |
| Hammer hit | Same, at full strength: the heaviest camera shake and the strongest haptic of the session. |
| Assistance escalating | The target spotlight widens and brightens rather than a new symbol appearing. |
| Charged throw too weak | A short "not quite" cue and a light haptic; the dummy still flies, the lesson still stands. |
| Third mechanic landing | Its own cue on top of the step success, because CoreComplete is the moment that matters. |
| Celebration | Two confetti waves rather than one pop, an impact ring, and the exit portal opening rather than appearing. |

Camera shake goes through the same `CameraShaker` the arena's damage feedback
uses, so an onboarding impact reads exactly like a match one. Every effect and
haptic passes through `OnboardingClient.effectScale()`, which returns zero under
reduced motion, so the whole layer turns down together.

### Sounds

Every onboarding cue is declared in `Config.Audio.Gameplay` and played through
`GameAudio`, the same path the rest of the game's one-shots use. **Every id is
currently a placeholder borrowed from a sound this game already ships**, so
training is audible and testable today; replacing one is a change to its
`AssetIds` and nothing else.

| Key | Scope | When it fires | What it should become |
|---|---|---|---|
| `OnboardingStepStart` | Local | A lesson's prompt appears | Short, bright, rising two-note "here we go" sting. Soft attack, ~0.25 s. Must not compete with the prompt animation. |
| `OnboardingStepSuccess` | Local | A lesson is passed | Bright confirmation chime with a fast decay, ~0.35 s. Should feel like a reward, not a UI click. Ideally three variants that rise in pitch across the three lessons. |
| `OnboardingCoreComplete` | Local | The third mandatory mechanic lands | Bigger, warmer version of the success cue with a low body under it, ~0.6 s. The "you've got it" moment. |
| `OnboardingDummyLaunch` | World | A dummy is knocked flying | Cartoon whoosh with an inflatable squeak on the front. Comedic, not violent. Needs 3–4 variants so a run of hits does not repeat. ~0.5 s. |
| `OnboardingChargeShort` | Local | A charged throw released too weakly | Deflating, downward "nope" — a short descending blip. Must read as "not yet", never as failure. ~0.3 s. |
| `OnboardingHint` | Local | Assistance escalates | Very soft, low-priority attention cue. Quieter than everything else in the list. ~0.2 s. |
| `OnboardingCelebration` | Local | The `READY!` card appears | Short musical sting with confetti-pop transients, ~1.2 s. Should resolve upward and stop cleanly; it is followed immediately by the lobby. |
| `OnboardingPortalOpen` | World | The exit portal opens | Airy, magical whoosh that swells and settles, ~0.8 s. Positioned at the portal so it pulls the ear toward the way out. |
| `OnboardingReveal` | Local | Training hands over to the lobby | Soft transitional swell, ~0.4 s. Should feel like a door closing behind the player rather than another reward. |

---

## 12. Prototype asset replacement list

### Good enough for production testing

- Training ring floor, perimeter pads, columns, spotlight (programmatic, but
  correctly proportioned and coloured to the game's palette).
- Training dummies (the shipped `CharacterRig`, recoloured).
- Every impact, hammer, and elimination sound (`Config.Audio.Gameplay` already
  ships real ids and `GameAudio` already routes them).
- Camera shake (the same `CameraShaker` the arena's damage feedback uses).
- Haptics (the shared `UIFeedback` effects).
- The whole overlay UI — it is the game's real component library.

### Should eventually receive bespoke art or audio

| Item | Where | Note |
|---|---|---|
| Training dummy model | `TrainingDummies.dress` | An inflatable/foam dummy with a face reads far better than a recoloured avatar, and would sell the squash. |
| Ring environment | `OnboardingWorld` | Foam-pit floor, padded barrier meshes, star/confetti motifs, a sky treatment distinct from the lobby. |
| Exit portal | `OnboardingWorld.buildPortal` | Currently a neon slab with a sparkle emitter; wants a real doorway with an opening animation. |
| Instruction signage | — | Floating in-world signs would let the overlay carry even less text. |
| Confetti / star burst | `OnboardingWorld.buildBurst` | Placeholder particle; wants authored sprites. |
| Every onboarding sound | `Config.Audio.Gameplay.Onboarding*` | Nine placeholders borrowed from shipped sounds. Section 11 says what each should become. |
| Gesture indicator | `GestureGlyph` | Procedural dot/ring/trail/chevron. Correct notation and on-style, but a painted hand or finger sprite would sell touch gestures harder. Every shape is one component. |

### Studio setup the lobby place still needs

The lobby place file is authored only in Studio, so these must be added there.
Everything degrades gracefully without them — training is fully playable today
— but the polish is not complete until they exist.

| Path | Copy from | Effect if missing |
|---|---|---|
| `ReplicatedStorage.Assets.Animations.Throw` | arena place | Throw animation does not play (the required-clip preload warns). |
| `ReplicatedStorage.Assets.Animations.Swing` | arena place | Hammer animation does not play. |
| `SoundService.CombatAudio` (Dodgeball/Hammer groups) | arena place | The legacy `Windup`/`Pickup`/`Landing`/`Hit`/`Miss` cues are silent; every config-driven sound still plays. |
| A Cmdr client script in `StarterPlayerScripts` | arena place | `sb-onboarding` still registers but the console cannot be opened; the Studio command bar entry point still works. |

Mouse and controller prompts need no art at all: they are resolved by the engine
from the real binding, and a controller player already sees their own platform's
button.

---

## 13. Values that genuinely need playtesting

Centralised in `src/config/Onboarding.luau` so they can be moved without
touching code:

- `Targets.NormalThrow.Offset` — first target distance. The single most
  important number: it decides whether the first throw feels like a gimme.
- `Targets.ChargedThrow.Offset` — far enough to motivate charging without
  feeling unfair.
- `MinimumChargeAlpha` — how much hold counts as "held". Too high reads as the
  game ignoring you.
- `InactivityHintSeconds` / `EscalatedHintSeconds` / `EscalateAfterAttempts` —
  when help arrives. Too early is nagging, too late is abandonment.
- `EscalatedForgiveness` — how much easier a struggling player's target gets.
- `StepAdvanceSeconds` and `CelebrationSeconds` — the pacing between the last
  hit and the next prompt, and the length of the payoff.
- `PracticeKnockouts` / `PracticeMaxSeconds` / `PracticeBotWalkSpeed` — how
  long the little fight lasts and how lively the bots feel.
- `Effects.CameraImpulseStuds` and `Effects.HapticStrength.*` — impact weight,
  which is exactly the kind of thing that reads differently on a phone.
- `SkipCornerInset` and skip prominence — discoverable without competing.
- `UI.Gesture.SizeScale` and `UI.Gesture.ClearancePixels` — how big the input
  indicator is and how much room it keeps. Widening the clearance past the space
  a laptop viewport has pushes the indicator from below the reticle to beside
  it, so the placement spec is the fastest way to see the effect of a change.

**Deliberately not implemented, pending a playtest call:** the practice bots do
not throw. The player is invulnerable for the whole session, so an incoming
ball could not hit them, and a ball that visibly cannot hurt you teaches the
wrong thing about catching — which onboarding does not teach. If playtesting
says the practice beat feels inert, the cheapest addition is a telegraphed
wind-up animation on the bots rather than a real projectile.

---

## 14. Manual test checklist

**Brand-new PC player** — join → training starts with no lobby flash → `THROW!`
with `LMB` → dummy launches → `BONK!` → `HOLD FOR POWER!` → practice → `READY!`
→ lobby with Play emphasised.

**Brand-new mobile player** — tap throws; the indicator is a dot with a ripple
and the word `TAP`, never `LMB`. On the charge lesson it becomes a ringed dot
whose ring closes at the real hold delay. On a phone the indicator sits beside
the reticle rather than under it. After the throw lesson the swipe tip appears
inside the real swipe region, running the real recognition distance, and fades.
No overlay element overlaps the thumbstick, jump, hammer button, or the bottom
swipe region, and tapping where the indicator is still throws.

**Tablet** — same, at a larger viewport: prompt and glyph stay proportional
(`UISizeConstraint` maxima), skip stays in the corner, the party choice does not
stretch past `MaxSize`.

**Controller** — the indicator shows the pad's own trigger art, and a
PlayStation pad shows PlayStation art rather than Xbox. Skip is reachable by
focus. The party choice focuses `JOIN MATCH`. The camera stays gamepad-driven.

**Hot device switch** — start on mouse, pick up a controller mid-step: the glyph
swaps to the pad's art, the verb changes from `CLICK` to `PRESS`, the step does
not restart, and the target stays.

**Returning completed player** — join → lobby, no training, no flash.
**Returning CoreComplete player** — join → lobby; the practice fight is not
repeated.
**Returning skipped player** — join → lobby.
**Partial player** — `sb-onboarding StartAt <you> Hammer`, then leave during the
hammer step and rejoin: training resumes at `Hammer`, not at `NormalThrow`.

**Party** — accept an invite into a party, then have the leader queue while you
train: the party choice appears; `KEEP TRAINING` leaves the party intact;
letting it reach `Assigned` ends training and teleports normally.

**Multiple simultaneous onboarding players** — join with two fresh accounts:
each gets its own ring, neither sees the other's dummy, and neither one's
throws or knockouts advance the other's step.

**Disconnect** — leave right after the charged throw, rejoin: straight to the
lobby (CoreComplete persisted). Leave right after the *first* throw, rejoin:
resumes at `Hammer`.

**Reset** — reset during a step: you respawn back in the ring, on the same step,
with a ball.

**Fall** — walk off the ring: you are returned to the spawn with progress
intact.

**Data failure** — break `Env.PrimaryDataKey` in Studio: the lobby opens
normally after `ResolveTimeoutSeconds` and an `OnboardingError` is logged. The
player is never trapped behind a loading screen.
