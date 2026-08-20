# Hit registration and latency audit

Read-only audit of the arena combat path: what resolves a hit, where time is
spent between a player's finger and that resolution, and which of those costs
fall unevenly on touch players. No behaviour was changed while producing this;
findings that call for a change say so and are not implemented here.

Everything under **Verified** was established by reading the code and is cited.
Everything under **Needs measurement** cannot be determined statically and needs
a live session with real clients.

---

## 1. Authority model

**Verified.** Hit resolution is fully server-authoritative and there is no client
input to it beyond intent.

- Clients send only `SubmitCombatInput` (kind, aim direction, optional target id,
  charge, lob). No position, no hit claim, no raycast result.
- The throw origin is taken from the server's own view of the thrower's root,
  not from the client: `ServerAuthAdapter.luau:260`.
- A client-proposed target is a *proposal only*. It is re-checked server-side
  against the widened validation cone and fails open to an unguided throw
  (`Dodgeball.validateTarget`).
- The elimination itself comes from the sim's own swept collision
  (`Projectiles.luau:457`), never from a client message.

This is the GDD section 8 invariant and it holds. Nothing below undermines it —
the findings are about *fairness and feel*, not exploitability.

---

## 2. Latency budget

Costs are grouped by who pays them. "Ours" means latency this codebase adds and
could in principle remove.

### Input to server (ours)

| Stage | PC | Touch | Notes |
|---|---|---|---|
| Edge detection | up to 1 frame (Heartbeat poll) | 0 | PC polls `InputAction:GetState()`; touch fires on the `TouchEnded` signal and emits the gesture synchronously |
| Resolution — swing | 0 | n/a | Hammer swings send on press, deliberately not deferred |
| Resolution — ball throw | click duration | tap duration | Both resolve on release so the throw style is known |
| Resolution — charge | hold duration | hold duration | Player-controlled and intentional; ramp is shared (`Gestures.chargeFor`) |
| Resolution — lob | click duration | swipe duration (max 0.35s) | |
| Buffer | 0 | 0 | `InputBuffer` engages only when the action is provably not yet legal; the happy path sends immediately |
| Send | immediate | immediate | |

### Server (ours)

| Stage | Cost |
|---|---|
| Intent waits for the next fixed step | up to 16.7 ms (`pendingIntents` is drained once per step, `ServerAuthAdapter.luau:244`) |
| Sim step | fixed 60 Hz |

### Server to client (ours)

| Stage | Cost |
|---|---|
| Events broadcast | once per step, unreliable (`ServerAuthAdapter.luau:311`) |
| Ball position | native CFrame replication, smoothed client-side at `Combat.Dodgeball.RemoteSmoothing = 18` |

### Not ours

Round-trip network time, client frame rate, and the player's own reaction time.
These dominate everything above and are the reason F1 matters most.

**Net:** on the happy path we add roughly **one client frame plus one sim tick**
(about 33 ms at 60/60) on top of the player's own gesture duration. That is a
reasonable budget. The problems below are not budget problems.

---

## 3. Findings

Ranked by how much they affect whether a mobile player can compete.

### F1 — No lag compensation. *Severity: high. Verified.*

The server resolves hits against character positions as they are **right now**,
read live from root CFrames each step. There is no position history, no rewind,
and no interpolation-delay compensation anywhere in the adapter or the sim.

Consequences, both of which scale with RTT:

- **The thrower must lead by their own latency.** They aim at where the target
  appeared RTT/2 ago; the server resolves against where it is now.
- **The dodger loses reaction time.** They see the ball RTT/2 late, plus
  `RemoteSmoothing` lag on top.

A player pays this penalty twice, on offence and on defence, and mobile
connections skew both higher and more variable than desktop. This is the single
largest mechanical disadvantage in the game, and none of the Phase 1-3 assists
touch it.

The fix is real work: a bounded ring of past character positions on the server,
resolving throws against the snapshot matching the thrower's reported client
time, with a cap so a lagging client cannot rewind arbitrarily far. It is a
deliberate architectural change and should be decided explicitly, not slipped in.

### F2 — Touch aim-assist cones are stale after the Phase 2 aim change. *Severity: high. Verified.*

`Config.AimAssist.Touch` sets `AcquireConeDeg = 60` and `StickyConeDeg = 75`.
Those were sized when touch aim **was** the direction to the auto-acquired
target — the camera was decorative, so a wide cone only meant "who do I snap
to", and 60 degrees was harmless.

Phase 2 removed that. Aim is now camera look on every device, and those same
cones feed `AimDirector`'s target pick, which feeds `CameraAssist` adhesion. A
60 degree acquisition cone now means the camera can be pulled toward a target at
or beyond the edge of the screen, and 75 degree sticky means it keeps being
pulled there. Confidence tapers from 0.6x the cone (36 degrees), so meaningful
pull persists well past what the player can see.

This is a config change, not a code change: the touch acquire and sticky cones
should come down toward the gamepad row (24/32) and be re-tuned from there.
Flagged rather than done — it changes feel and wants a playtest, not an audit's
opinion.

### F3 — The sim clock can fall behind wall clock permanently. *Severity: medium. Verified.*

`ServerAuthAdapter.luau:376` clamps the accumulator to `STEP_SECONDS * 8`
(about 133 ms). Time beyond that is **discarded, not deferred**. After any server
hitch longer than 133 ms, the simulation is permanently that much behind real
time and never catches up.

Everything measured in sim ticks stretches with it: throw and catch cooldowns,
the 0.18 s catch window, hammer active and recovery windows, projectile flight
time. Players experience this as combat going briefly sluggish with no visible
cause.

The clamp itself is correct — without it a long hitch spirals into a death-loop
of catch-up steps. What is missing is any signal that it fired. A counter
incremented on discard would turn an invisible feel regression into a number,
and costs nothing.

### F4 — Elimination feedback rides an unreliable remote with an unbounded payload. *Severity: medium. Verified, with one part needing measurement.*

`CombatSimEvent` is declared `unreliable` and is fired once per step with the
**entire event array for that tick** (`ServerAuthAdapter.luau:311`).

The design is right: gameplay state does not depend on it. Aliveness lives in
the `CombatAlive` attribute and replicates reliably, and `MatchService` owns
elimination consequences server-side. A dropped packet costs an effect, not a
result.

The risk is that unreliable remotes have a per-call payload ceiling. A busy tick
— several simultaneous eliminations, bounces and hits — produces the largest
array, so packets are most likely to be dropped or rejected exactly when the
most is happening on screen. Whether real ticks approach that ceiling is the one
item here that needs measurement.

### F5 — Touch has a measurably larger hit sphere than mouse. *Severity: low, by design. Verified.*

The projectile's effective radius against **characters** is
`Radius + HitForgiveness + MagnetismRadius` (`Projectiles.luau:194`), and
`MagnetismRadius` is per device:

| Device | Effective radius vs. players | vs. static geometry |
|---|---|---|
| Mouse | 1.35 | 1.0 |
| Gamepad | 1.65 (+22%) | 1.0 |
| Touch | 1.95 (+44%) | 1.0 |

This is the intended assist and it is applied server-side, which is the correct
place for it. It is listed because it is completely invisible: it does not appear
in any per-player assist config, is not gated by `PlayerAssist`, and cannot be
A/B'd or dialled back at runtime like everything added in Phases 1-3. If the
assist set is ever tuned as a whole, this one will be missed.

### F6 — Targets are not swept, only projectiles. *Severity: low. Verified.*

`sweepCharacters` tests the projectile's swept sphere against character capsules
at their position in the current snapshot. A target's own motion during the tick
is not swept, so a character moving laterally can in principle cross the swept
volume without registering.

Bounded and small in practice: at 16-25 studs/s a character moves 0.27-0.42
studs per tick, against a swept radius of 1.35-1.95. Not worth fixing on its own,
but worth knowing it exists if F1 is ever addressed — a rewind system would be
the natural place to fix both.

### F7 — Dead input surface. *Severity: cosmetic. Verified.*

`DoubleTap` is classified, published in the gesture stream, and carried into
`CombatInputSender`, where it is handled identically to `Tap`. Either it should
mean something or the classification should go: right now it is a distinction the
player can make that the game ignores.

### F8 — Flood limits have ample headroom. *No action. Verified.*

`SubmitCombatInput` is rate-limited to 20/s and `MAX_QUEUED_INTENTS` is 16 per
step. Legitimate play tops out around 3/s given a 0.6 s throw cooldown and a
0.65 s catch cooldown. No legitimate input can be dropped by either limit.

---

## 4. Needs measurement

None of these can be settled by reading code. Each needs a live session with real
clients on real connections.

1. **RTT distribution by device class.** F1's severity is proportional to it. The
   analytics layer already carries an input-device dimension, so this is a query,
   not new instrumentation.
2. **Peak `CombatSimEvent` payload size** during a full fight, against the
   unreliable-remote ceiling (F4).
3. **How often the accumulator clamp fires** in a live server (F3).
4. **Whether observed hit rate differs by device** once F2's cones are corrected.
   The assists are tuned but have never been measured against a human.
5. **Client frame rate on low-end phones.** PC edge detection costs one frame, so
   a 30 fps phone pays double what a 60 fps desktop does.

---

## 5. Summary

The authority model is sound and the per-frame budget is reasonable. Two things
are worth acting on: **F1** (no lag compensation — the largest real
disadvantage, and a deliberate architectural decision to make) and **F2** (touch
cones left over from an aim model that no longer exists, currently letting the
camera pull toward off-screen targets).

F3 and F4 are cheap to instrument and currently fail silently. F5 through F8 are
documentation, not defects.
