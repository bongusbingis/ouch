# Dodgeball Studio setup

Apply these changes manually in Studio. Repository tooling must not rewrite `game.rbxl`.

## Dodgeball template

1. Open `ReplicatedStorage > Assets > Cosmetics > BallAssets > DefaultDodgeball`. It must remain a single anchored `BasePart` with `CanCollide`, `CanTouch`, and `CanQuery` disabled. This is both the authoritative ball template and the default visual.
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

## Intermission lobby

1. Keep the Studio-authored lobby permanently at `Workspace > Lobby`. Do not place it under `ReplicatedStorage > Assets > Maps`; runtime map cleanup must never move or destroy it.
2. Add a direct child folder at `Workspace > Lobby > PlayerSpawns` with at least one anchored `BasePart` spawn marker.
3. Make each marker invisible with `CanCollide`, `CanTouch`, and `CanQuery` disabled. The server teleports returning match participants 3.5 studs above a random marker.
4. Place the lobby at its final world position, separated from match arenas. New arrivals are not automatically teleported there; it is reserved for players returning from a completed match.

## Verification

1. Confirm `Workspace > Balls` is created at runtime and each spawn creates exactly one ball.
2. Test with **Server & Clients**, not a single local player process.
3. Verify held balls align to `DodgeballGrip`; adjust only that attachment to refine placement.
4. Exercise 0, 100, 150, and 200 ms simulated latency and check that throw/rebound effects do not replay during corrections.
5. Complete a match and verify that participants remain in the arena for Results, then move to `Workspace > Lobby` for Intermission before the arena clone is destroyed.
6. Join with a new client during Intermission and verify that the new arrival is not teleported to the lobby.
