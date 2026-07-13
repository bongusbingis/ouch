# Dodgeball Studio setup

Apply these changes manually in Studio. Repository tooling must not rewrite `game.rbxl`.

## Dodgeball template

1. Open `ReplicatedStorage > Assets > Dodgeball`. It must remain a single anchored `BasePart` with `CanCollide`, `CanTouch`, and `CanQuery` disabled.
2. Add attachments named `TrailTop` and `TrailBottom`, placed on opposite sides of the ball.
3. Add a disabled `Trail` named `FlightTrail`, wired to those attachments. The client enables it only during flight, bounce, and recall phases.
4. Add disabled `ParticleEmitter` children named `Bounce`, `Landing`, `Pickup`, and `Hit`. Give each a numeric `BurstCount` attribute; a starting value of 8 is suitable.
5. Add `Sound` children named `Windup`, `Throw`, `Bounce`, `Landing`, `Pickup`, `Recall`, and `Hit`, and assign the intended published sound IDs.
6. Keep every trail and emitter disabled in the template. Sounds must not have `Playing` or `Looped` enabled.

## Character grip and animations

1. For R15 rigs, add an `Attachment` named `DodgeballGrip` under `RightHand`. Start at position `(0, -0.65, 0)` and rotate it to fit the authored mesh.
2. For R6 rigs, add the same attachment under `Right Arm`. The code falls back to a hand/arm-relative position if the attachment is absent.
3. Create `ReplicatedStorage > Assets > CombatAnimations`.
4. Add `Animation` children named `DodgeballWindup` and `DodgeballRelease`, each with its published animation ID. Author them for the rig type used by the prototype.

## Verification

1. Confirm `Workspace > Balls` is created at runtime and each spawn creates exactly one ball.
2. Test with **Server & Clients**, not a single local player process.
3. Verify held balls align to `DodgeballGrip`; adjust only that attachment to refine placement.
4. Exercise 0, 100, 150, and 200 ms simulated latency and check that throw/rebound effects do not replay during corrections.
