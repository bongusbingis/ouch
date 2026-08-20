# Throw pose

The throwing arm, and only the throwing arm. Authored animation carries the
body, the timing and the personality; a thin IK layer carries the wind-up, the
pause at the top of it, and then gets out of the way.

**The character's body is never driven by the camera.** No torso pitch, no head
tracking, no facing override. If something moves, it is either an authored
animation or the arm IK — nothing else. An earlier version leaned the spine
toward the camera; it made the character read as a turret rather than a cartoon,
and it is gone.

```
camera / touch / gamepad
        |
   AimDirector.currentAim()      <- the one canonical aimDirection
        |
        +-- SubmitCombatInput ----> server sim ----> projectile
        +-- ArmIK  (which way the ball is presented, nothing else)

CombatState  ---> ArmIK      (how hard the solver pulls, where the hand goes)
             ---> WeaponAnimations  (which clip plays)
```

Gameplay never reads a visual transform. The projectile launches from a
root-relative origin on the server and never consults the hand.

---

## How the wind-up works

Holding charge moves the IK target to a **fixed spot in the character's own
space** — back, up and slightly out from the shoulder. Not camera space: the
hand draws back to the same readable place every time, which is what makes a
charged throw feel like a committed action rather than a cursor.

The target is reached by an **under-damped spring**, so the hand overshoots
slightly and settles back into the pose. That small bounce is most of what makes
the action feel cartoony rather than mechanical.

**The pause is emergent, not scripted.** While charge is held the target stops
moving, so the spring arrives and has nowhere else to go. The hand simply stays
there for as long as you hold. No timer, no state to get stuck in.

As charge builds, the wind-up stretches further back (`ChargeStretch`), so a full
charge is visibly bigger than a light one.

On release, the weight collapses to zero across `Throwing` and `FollowThrough`
and the authored `Throw` clip owns the whole fast part of the motion.

If a `DodgeballCharge` animation exists, it plays alongside and freezes on its
`Charged` marker — the two reinforce, and the animation defines the body while
the IK refines the hand.

---

## Modules

| Module | Layer | Responsibility |
|---|---|---|
| `src/config/ThrowPose.luau` | config | Every tunable: offsets, weights, spring shaping, timings, remote rate. |
| `src/config/Animations.luau` | config | The only place a clip is named. Required vs optional, loop, priority, markers. |
| `src/shared/Game/Pose/AimPose.luau` | shared, pure | Weight and wind-up-reach maths. Spec-tested headlessly. |
| `.../Presentation/CombatState.luau` | client | The visual state machine and the single value of `chargeAlpha`. |
| `.../Presentation/ArmIK.luau` | client | The whole pose layer: `IKControl` lifecycle, target, pole, weight. |
| `.../Presentation/WeaponAnimations.luau` | client | Plays clips off the state machine. Owns the marker hookups. |
| `src/server/Modules/CombatPoseService.luau` | server | Projects replicated charge so opponents' wind-ups are readable. |

Remote characters get the wind-up too — their charge replicates as a player
attribute at 12 Hz, change-gated, so a player who is not charging sends nothing.
They do not get aim tracking; the coil is the part that reads at a distance.
That value is cosmetic and never touches hit resolution.

---

## Animations

Runs today on the two prototypes you already have.

**Required — already exist:** `Throw`, `Swing`. Both want one marker added.

**Worth making next:**

1. **`DodgeballHold`** — looping, ball at the chest, weight settled. ~1s.
   Two things matter: keep it **neutral** (the IK adjusts the hand on top of it,
   so a strong authored pose fights it), and **keyframe only the throwing arm**.
   Roblox blends per joint, so an arm-only clip overrides the default locomotion
   on that arm while the legs and torso keep running normally. Keyframing the
   whole body here would freeze the run.
2. **`DodgeballCharge`** — the wind-up. Arm draws back, weight onto the back
   foot, torso coils. Put a `Charged` marker where the arm reaches the wound
   pose; playback freezes there while charge is held, so the clip only covers
   the wind-up itself. ~0.3–0.5s. **This is the one that makes the feature
   land** — the IK can move a hand, but only animation can coil a body.
3. **`DodgeballRecover`** — ~0.25s settle back to the hold.

**Later:** `HammerIdle`, `HammerRecover`.

### Markers

| Clip | Marker | Where | Used for |
|---|---|---|---|
| `Throw` | `Release` | The frame the ball leaves the hand | Hands off to the follow-through on the authored beat instead of a guessed duration |
| `DodgeballCharge` | `Charged` | The frame the arm reaches the wound pose | Freezes playback there while charge is held |
| `Swing` | `SwingHit` | The frame the head passes through its arc | Effects and audio only — **never** gameplay |

All are optional in the sense that absence is survivable: the state machine falls
back to `ThrowPose.Timing`.

---

## Tuning

Set `Debug.StudioVisuals = true` and `Debug.ThrowPoseTuner = true`, then play.
Every value in `Config.ThrowPose` appears under **`Workspace.ThrowPoseTuning`**
as a Value object; edit one in the Explorer and the arm changes on the next
frame. Nothing is saved — once a number feels right, copy it into
`src/config/ThrowPose.luau`, which stays the source of truth.

The folder is built by walking the config tree, so a value added to the config
shows up there automatically. It is client-side and Studio-only, so it cannot
reach a live server.

Also worth turning on: `Debug.PoseWindupAnchor` draws the wind-up spot whether
or not you are holding charge, so you can place it without a third hand, and
`Debug.PoseElbowPole` shows where the elbow is being pushed.

1. **`Arm.ShoulderOffset`** — measure this for your rig first. Everything else is
   relative to it, so a wrong value makes every other number feel wrong.
2. **`Arm.WindupOffset`** — *the* value. Where the hand pauses. Back and up
   (`+Z` is behind the character) gives a classic overhand coil.
3. **`Motion.WindupDamping`** — the cartoon dial. Below 1 overshoots and settles;
   lower is bouncier. At 1 the bounce disappears and it reads mechanical.
4. **`Motion.WindupFrequency`** — how fast the hand snaps back into the coil.
5. **`Weights.Charging`** — how strongly the wind-up overrides the animation.
6. **`Arm.ChargeStretch`** — how much bigger a full charge looks than a light one.
7. **`Arm.PoleOffset`** — where the elbow points. Adjust until it flares out
   instead of clipping the torso.
8. **`Arm.ReadyDistance`** — how far the ball is presented at rest. R15
   shoulder-to-hand is ~2.8 studs; staying under that keeps the elbow bent.
9. **`Weights.Max`** — the guardrail. Raising it toward 1 progressively deletes
   the authored animation.

---

## Ordering

Three things move the hand each frame, and they have to run in this order or the
ball chases a stale pose:

| Priority | Who | Does |
|---|---|---|
| `Character` (300) | Roblox Animator | Writes the frame's animation pose |
| `Character + 1` | `ArmIK` | Blends the solver over it |
| `Character + 2` | `BallVisuals` | Reads the final hand transform to place the held ball |

`BallVisuals` used to run at the default `RenderStepped` priority (0), i.e.
before all of it, so a held ball was drawn at where the hand had been on the
previous frame. Standing still that error is invisible; a running arm swing or a
wind-up moves the hand far enough per frame that the ball visibly judders
against it.

---

## Known limitations

- **Without `DodgeballCharge`, only the hand coils.** The IK moves an arm; it
  cannot shift weight onto a back foot or rotate a torso. Expect the wind-up to
  read as "hand pulled back" until that clip exists.
- **R6 and custom rigs get no IK.** The chain needs `RightUpperArm` and
  `RightHand`. Missing them means the authored animation plays unmodified, which
  is the correct fallback rather than an error.
- **Left-handed throws are not modelled.** The chain is hardcoded to the right
  arm, matching the single authored `Throw`.
- **Remote wind-ups are charge-only and 12 Hz**, so an opponent's coil lags
  slightly and does not track their aim.
- **Tuned values are not persisted.** The tuner deliberately does not write to
  disk; copy what you settle on back into the config.
- **`ChargeAim.luau` still derives its own press state** from the Throw
  `InputAction` rather than reading `CombatState`. It is your prototype so I left
  it; pointing it at `CombatState.getSnapshot()` would remove the duplication.

---

## Test checklist

- [ ] Hold charge — hand draws back and **pauses**, holding as long as you hold
- [ ] Watch the settle — slight overshoot then rest, not a linear glide
- [ ] Full vs light charge — full visibly reaches further back
- [ ] Release — weight collapses, follow-through fully visible, no snap back
- [ ] Aim up / down / sideways while holding — **torso and head never move on
      their own**; only the arm responds
- [ ] Walk and run while charging — locomotion plays normally underneath
- [ ] Repeated rapid throws — no stuck wind-up
- [ ] Switch to hammer — arm IK drops to zero, swing unaffected
- [ ] Die mid-charge, respawn — pose resets, exactly one `ThrowArmIK` on the
      Humanoid, no duplicates
- [ ] Second client — their wind-up is visible to you
- [ ] Mobile: charge while dragging the camera — both work, no arm jitter
- [ ] `Debug.PoseReleaseOrigin` on — origin stays rigid through the whole throw
