# Combat input and camera

Input classification and the combat camera live inside the forked PlayerModule at
`src/client/PlayerModule/Combat/`. The layer answers one question — *what did the
player intend* — and hands a device-independent intent to the weapon systems,
which answer *what that action does*.

```
raw device input  ->  classification  ->  intent  ->  weapon systems  ->  server
```

Intents: `NormalThrow`, `BeginCharge`, `ReleaseCharge`, `CancelCharge`,
`HammerAttack`. Nothing here knows a dodgeball from a hammer beyond which control
was used, nothing here is authoritative, and no touch data ever reaches the
server — only the resulting intent, through the existing combat protocol.

---

## 1. Architecture

### Added

| File | Purpose |
|---|---|
| `Combat/init.luau` | Facade and the entire public API. Routes raw touch events, owns enable/disable, emits intents |
| `Combat/CombatConfig.luau` | Every feel value, with effect-and-symptom comments |
| `Combat/TouchIntent.luau` | Per-touch state machine. The core of accidental-throw prevention |
| `Combat/TouchRegions.luau` | Viewport-aware regions, HUD exclusions, threshold scaling |
| `Combat/CombatCamera.luau` | Combat camera state, shoulder offset, mouse lock, cursor ownership |
| `Combat/DeviceInput.luau` | Mouse and gamepad classification on the same rhythm as touch |
| `Combat/CombatDebug.luau` | On-screen classification view. Off by default |

### Modified (game side)

`CombatInputSender` consumes intents instead of watching input. `CombatState`
times the charge ramp from a single clock. `InputRouter` only requests/releases
the cursor. `CameraAssist` lost its duplicate shoulder offset. `SimulationClient`
enables combat. `ServerAuthAdapter` rejects `lob`.

### Removed

`TouchInput.luau` (+ `.md`) and the pure `Zones`/`TapTarget` modules and specs it
alone used — a second raw touch listener running in parallel with this one.

### Client/server boundary

Everything here is client-only. The server sees exactly what it saw before: a
`SubmitCombatInput` with kind, aim direction, optional target and charge. Server
authority is unchanged.

### How touch ownership is coordinated

It isn't — deliberately. This layer never suppresses, redirects or applies camera
input; `CameraInput` keeps complete ownership of every touch exactly as upstream
wrote it, and the classifier is a pure observer that only decides whether an
*attack* also happens.

That is why aiming-while-charging works for free (the charging finger is still an
ordinary camera touch), why there is no handoff to snap, and why there is nothing
to arbitrate: two systems cannot fight over a touch when only one is steering.

---

## 2. Gesture state diagram

```
                    touch begins in gameplay area
                              |
                           PENDING
                              |
   +-------------+------------+-------------+----------------+
   |             |                          |                |
 drift >         held >= HoldDelay      upward flick     release, short
 ClaimDistance   with drift <= HoldSlop  from bottom      + tiny drift
 or fast              |                  strip                |
   |                  |                     |                 |
 CAMERA            CHARGING             CONSUMED          NormalThrow
   |                  |                     |
 (one-way:         release              fires on
  release does        |                 recognition,
  nothing)       ReleaseCharge          release does
                                          nothing

   release from PENDING that is neither  ->  nothing at all
```

- **Middle tap** — Pending → release within `Tap.MaxDuration` and
  `Tap.MaxDistance` → `NormalThrow`.
- **Camera drag** — Pending → drift past `Camera.ClaimDistance`, or velocity past
  `Camera.ClaimVelocity` → Camera. **One-way.** Release produces nothing.
- **Charge** — Pending → held past `Charge.HoldDelay` within `Charge.HoldSlop` →
  Charging → `BeginCharge`. Later movement does *not* revoke it; the player is
  aiming. Release → `ReleaseCharge`.
- **Bottom swipe** — Pending in the strip → direction, distance, velocity and
  duration all satisfied → fires `NormalThrow` **on recognition**, marks the touch
  Consumed so release cannot fire again. Failing any signal kills the candidate
  and the touch falls through to normal camera-claim rules.
- **Hammer** — `Combat.hammerPressed()` from the HUD button. Bypasses
  classification entirely; never enters the touch table.
- **Cancellation** — `cancelAll()` on character removal, combat disable, cursor
  request or focus loss. Emits `CancelCharge` if one was live.

---

## 3. Combat camera state diagram

```
      setCameraEnabled(true)          requestCursor("Shop")
  DISABLED ----------------> ENABLED ---------------------> ENABLED
     ^                          |     <---------------------  but INACTIVE
     |                          |     releaseCursor("Shop")   (cursor free,
     |  setCameraEnabled(false) |                              input silent)
     +--------------------------+
```

Effective state is `enabled AND config.Enabled AND no outstanding cursor request`.

- **Active** — cursor hidden, mouse `LockCenter`, shoulder offset applied,
  sensitivity scale applied, combat input live.
- **Cursor released** — behaves exactly as disabled for as long as any requester
  holds it. Combat input goes quiet with no second flag to remember.
- **Restore** — the last `releaseCursor` re-engages everything. No snap: the
  offset is applied through the camera controller's own mouse-lock path.
- **`CharacterFollowsCameraYaw`** — toggles `RotationType.CameraRelative` only.
  Mouse lock, cursor hiding and shoulder offset are untouched by it.

State is re-asserted every frame because the active camera controller is swapped
whenever the camera mode changes and a fresh one knows nothing about our state.
The engine writes underneath are change-gated, so a steady state costs nothing.

---

## 4. Configuration guide

All in `Combat/CombatConfig.luau`. Full effect-and-symptom notes are in the file;
the headline values:

| Value | Default | Raise it | Lower it |
|---|---|---|---|
| `Charge.HoldDelay` | 0.18s | Taps safer; charging feels late | Charge feels instant; taps start charging |
| `Tap.MaxDistance` | ~2.2% of min axis | Forgives tremor | Camera nudges become throws if too high |
| `Camera.ClaimDistance` | ~2.8% | Camera feels sticky | Camera engages eagerly; taps get stolen |
| `Camera.ClaimVelocity` | ~1.4× | Flicks claimed later | Tap acceleration trips it |
| `Charge.HoldSlop` | ~5% | Charging survives shaky hands | Charging fails for unsteady players |
| `BottomSwipe.RegionHeightFraction` | 0.28 | Easier to start | Encroaches on the tap area |
| `BottomSwipe.DirectionDot` | 0.8 (~36° cone) | Stricter, fewer false positives | More false positives from panning |
| `BottomSwipe.MinVelocity` | ~0.9× | Demands a sharper flick | Slow pans start throwing |
| `Controller.TriggerPress/Release` | 0.55 / 0.35 | — | Gap is hysteresis; narrowing it causes chatter |
| `CombatCamera.ShoulderOffset` | `(1.5, 0.35, 0)` | Character further left | Reticle drifts onto the character's head |
| `CombatCamera.CharacterFollowsCameraYaw` | `true` | — | Body stops turning; camera unchanged |
| `Camera.ChargeSensitivityMultiplier` | 0.9 | Faster aim while charging | Steadier but sluggish |

Touch thresholds are a fraction of the **smaller viewport dimension**, clamped to
a pixel range, so a phone and a tablet need the same physical thumb travel.

There is deliberately **no** `CharacterYawResponsiveness`: body yaw uses Roblox's
own `CameraRelative`, so the engine remains the single owner of root rotation. A
custom spring would mean disabling `Humanoid.AutoRotate` and taking that
ownership away — a knob bought at the price of a fight over who turns the
character.

---

## 5. Upstream diff summary

Three files, each marked `GAME MODIFICATION (Combat)` so they are greppable when
diffing a future fork.

| File | Why | Isolatable further? |
|---|---|---|
| `init.luau` | Requires/starts `Combat` and exposes it on the previously-empty public API table | No — a fork has to have one entry point |
| `CameraModule/MouseLockController.luau` | The stock Shift toggle is not connected. Leaving it would give two sources of truth for the camera offset and Shift would silently fight the combat camera | Yes — could be replaced by rebinding `MouseLockSwitchAction` from outside if Roblox makes that possible |
| `CameraModule/CameraInput.luau` | One sensitivity multiplier on `getRotation`, set through a setter. Placed here because it is where every device's rotation converges | Partly — a fork-free version would need an upstream sensitivity hook |

Everything else is additive under `Combat/`. Lint and format exclusions cover
only the upstream directories, so `Combat/` is held to project standard while the
vendored files stay byte-identical to what Roblox ships.

---

## 6. Integration requirements

Already wired. `CombatInputSender` subscribes in `start()`:

```lua
Combat.onIntent(onIntent)
```

| Intent | What the game does |
|---|---|
| `NormalThrow` | `intentForTap()` picks Throw or Catch, then `CombatState.onThrow()` and `submit()` |
| `BeginCharge` | `CombatState.beginCharge()` if a ball is held |
| `ReleaseCharge` | Reads `CombatState.currentCharge()` **before** advancing state, then submits |
| `CancelCharge` | `CombatState.endCharge()` |
| `HammerAttack` | Submits `Throw`; the sim routes to the hammer because no ball is held |

Charge *progression* stays in the game layer: PlayerModule decides *that* a charge
began, `CombatState` times the ramp with `Gestures.chargeFor`. Cooldown buffering
also stays game-side, in `CombatInputSender`.

---

## 7. Camera API

`PlayerModule` lives at **`StarterPlayer.PlayerModule`**, not under
`StarterPlayerScripts`. `StarterPlayerScripts` is copied into every player's
`PlayerScripts`, so the four non-Legacy `RunContext` scripts in this fork
(`InputSetup`, `PlayerScriptsLoader`, and the `ServerAuthority` pair) would run
once in place and again in every copy — Roblox warns about exactly this. Under
`StarterPlayer` they run once, and the module is reachable from both the client
and the server without a copy.


```lua
local Combat = require(game:GetService("StarterPlayer").PlayerModule).Combat

Combat.setCameraEnabled(true)          -- over-the-shoulder locked camera
Combat.setInputEnabled(true)           -- produce intents
Combat.requestCursor("Shop")           -- menu needs the pointer
Combat.releaseCursor("Shop")           -- give it back
Combat.registerHudExclusion("Hammer", rect)
Combat.hammerPressed()                 -- from the HUD button
Combat.onIntent(fn)                    -- returns an unsubscribe
Combat.isCharging()
Combat.isCameraTouchActive()
```

Cursor release is **reference counted by reason**, so overlapping menus cannot
strand each other — the pointer returns only when the last requester releases.

Body-follow is a config flag (`CombatCamera.CharacterFollowsCameraYaw`) rather
than a call, because it is a design decision for the whole game, not per-moment
state.

Defaults are off with a free cursor: the lobby never calls any of this and keeps
a working mouse for its menus with no lobby-side code.

---

## 8. Debug instructions

In `Combat/CombatConfig.luau`:

- `Debug.Enabled = true` — on-screen overlay: the bottom-swipe region drawn to
  scale, plus a live row per touch showing state, age, peak drift, velocity and
  swipe candidacy, and a counter line (taps / camera claims / charges / swipes /
  ambiguous / cancelled).
- `Debug.LogClassification = true` — one line per decision, e.g.
  `-> Camera (displacement)`, `-> NormalThrow (tap 0.11s 5px)`,
  `swipe cancelled: direction`.

The overlay is built at startup but stays disabled, so the flag can be flipped
live in Studio without rejoining. Instances are created once and only updated —
a debug view that allocates per frame changes the timing of what it measures.

Combat camera state appears on the overlay's summary line (`combat=` effective,
`cam=` enabled, `charging=`).

---

## 9. Test checklist

**PC** — cursor hidden in combat; mouse centre-locked; right-shoulder offset;
smooth at fast and very slow mouse speeds; quick click throws; hold charges;
camera rotates freely while charging; **Shift does not toggle anything**; body
follows camera with the flag true and does not with it false while the camera is
identical in both; opening a menu frees the cursor and closing it restores the
camera without a jump; respawn and weapon switch leave the camera correct.

**Phone** — quick/normal/long taps, taps with tremor, repeated taps, taps while
moving, tap right after a camera drag; small/large/slow/fast drags in every
direction; stationary hold, hold-then-aim in each direction, charge while
walking, release just past the threshold, full charge, death mid-charge, menu
mid-charge; clean/medium/diagonal/sideways/downward swipes from the bottom, plus
slow upward pans that must **not** throw; multi-touch: move+camera, move+throw,
move+charge, charge+second-finger camera, hammer+movement.

**Tablet** — repeat the tap, drag and swipe rows. Thresholds should feel the same,
not proportionally smaller.

**Controller** — tap trigger throws; hold charges; release throws charged; right
stick aims freely while charging; hammer while moving; rapid attacks; **unplug
mid-charge** (must cancel, not stick); switch device mid-session.

---

## 10. Remaining feel risks

Code cannot settle these. Every value is a considered starting point, not a
measured one, and they interact — raising one usually means revisiting another.

- **`Charge.HoldDelay` (0.18s)** — the single biggest feel parameter. Too low and
  taps charge; too high and holding feels dead.
- **`Tap.MaxDistance` vs `Camera.ClaimDistance`** — the band between them is the
  ambiguous zone. Narrow it and fewer touches do nothing; widen it and either
  taps or drags get stolen.
- **`BottomSwipe.DirectionDot` and `MinVelocity`** — the whole gesture's
  false-positive rate. This is the one most likely to need real-thumb data.
- **`Camera.ChargeSensitivityMultiplier` (0.9)** — a guess. May want to be 1.0.
- **`ShoulderOffset`** — needs checking against the reticle and this game's
  proportions on both widescreen and phone aspect ratios.
- **Ambiguous-touch rate** — the debug counters exist precisely to measure this.
  If `ambiguous` is high relative to `taps` in real play, the thresholds are
  wrong, not the players.

Two gaps remain in the implementation itself: there is **no hammer HUD button**
(`Combat.hammerPressed()` and `registerHudExclusion` are ready and waiting for
one), and haptics are not wired.
