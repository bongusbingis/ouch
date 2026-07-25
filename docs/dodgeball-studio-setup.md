# Dodgeball Studio setup

Apply these changes manually in Studio. Repository tooling must not rewrite `game.rbxl`.

## Dodgeball template

1. Open `ReplicatedStorage > Assets > Cosmetics > BallAssets > DefaultDodgeball`. It must remain a single anchored `BasePart` with `CanCollide`, `CanTouch`, and `CanQuery` disabled. This is both the authoritative ball template and the default visual.
2. Add attachments named `TrailTop` and `TrailBottom`, placed on opposite sides of the ball.
3. Add a disabled `Trail` named `FlightTrail`, wired to those attachments. The client enables it only during flight, bounce, and roll phases.
4. Add disabled `ParticleEmitter` children named `Bounce`, `Landing`, `Pickup`, and `Hit`. Give each a numeric `BurstCount` attribute; a starting value of 8 is suitable.
5. Under `SoundService > CombatAudio > Dodgeball`, add `AudioPlayer` children named `Windup`, `Throw`, `Bounce`, `Landing`, `Pickup`, and `Hit`, and assign the intended published audio asset IDs.
6. Keep every trail and emitter disabled in the ball template. The `AudioPlayer` templates must not start playing or looping.

## Elimination splat effect

This section is optional: when `ReplicatedStorage > Assets > Effects > Splat` is absent, the client builds an equivalent prototype in code (stock smoke/sparkle particle textures), and a missing `Splat` `AudioPlayer` is skipped silently. Authoring the assets below overrides the prototype with no code changes.

1. Create a `Folder` at `ReplicatedStorage > Assets > Effects` and inside it a `Part` named `Splat`: `Anchored` enabled, `CanCollide`, `CanTouch`, and `CanQuery` disabled, `Transparency` 1, `CastShadow` disabled, `Size` `(0.5, 0.5, 0.5)`. On a dodgeball elimination the client clones it to the impact point with its **Front** face pointing back along the incoming throw.
2. Add three disabled `ParticleEmitter` children. Author `Droplets` and `Sheet` with white/grayscale textures — the client tints them from the thrower's equipped ball skin (`SplatColor` in `Config.Cosmetics`); `Flash` stays untinted.
   - `Droplets` — the main paint spray: soft round droplet texture, `EmissionDirection` Front, `SpreadAngle` `(40, 40)`, `Speed` 25–45, `Lifetime` 0.35–0.7, `Acceleration` `(0, -60, 0)`, `Drag` 2, `Size` 0.4 → 0.15, `Transparency` 0 until ~60% of lifetime then → 1, `Rotation` `(-180, 180)`, `RotSpeed` `(-90, 90)`, `LightEmission` 0.15. Numeric attribute `BurstCount` = 28.
   - `Sheet` — a wide wet splash sheet: `EmissionDirection` Front, `SpreadAngle` `(75, 75)`, `Speed` 8–16, `Lifetime` 0.25–0.4, `Size` 1.2 → 2.8, `Transparency` 0.15 → 1, `LightEmission` 0.1. Numeric attribute `BurstCount` = 6.
   - `Flash` — the impact pop: white texture, `Speed` 0, `Lifetime` 0.12, `Size` 3 → 5, `Transparency` 0.3 → 1, `LightEmission` 1. Numeric attribute `BurstCount` = 1.
3. Keep all three emitters disabled in the template; the client fires them with `Emit(BurstCount)`.
4. Add an `AudioPlayer` named `Splat` under `SoundService > CombatAudio > Dodgeball` with a wet paint-splat asset id, matching the shape of the existing players (`Playing` and `Looping` disabled).

## Character grip and animations

1. For R15 rigs, add an `Attachment` named `DodgeballGrip` under `RightHand`. Start at position `(0, -0.65, 0)` and rotate it to fit the authored mesh.
2. For R6 rigs, add the same attachment under `Right Arm`. The client falls back to `Config.Combat.Dodgeball.HeldVisualHandOffset` when the attachment is absent.
3. Optionally add a `DodgeballReleaseSocket` `Attachment` anywhere under the character to author the server release point. Without it, the adapter uses `Config.Combat.Dodgeball.OverhandReleaseRootOffset`.
4. Under `ReplicatedStorage > Assets > Animations`, add `Animation` children matching `Config.Combat.Dodgeball.ThrowAnimationName` and `Config.Combat.Hammer.AnimationName` (`Throw` and `Swing` by default). Author them for the supported rig types.

## Hammer grip

`HammerVisuals` aligns each hammer skin against the hand using a `GripAttachment` child on the skin's `BasePart`, matched against the character's own grip reference frame (R15's built-in `RightGripAttachment` on `RightHand`, or a small config-driven fallback for R6/custom avatars). No `GripAttachment` exists in Studio today: `HammerVisuals` seeds one at runtime from `Config.Combat.Hammer.GripOffset`/`GripRotationDeg` on any cloned hammer part that lacks its own.

1. To author placement directly instead of iterating the config numbers: for each hammer skin under `ReplicatedStorage > Assets > Cosmetics > HammerAssets`, add an `Attachment` named `GripAttachment` on the part. A Studio-authored one always takes precedence over the config-seeded default.
2. Because the mesh is a symmetric, double-headed inflatable hammer, one `GripAttachment` roughly 3/4 down the shaft (from either head) should read correctly held from both orientations — no separate top/bottom variant needed.
3. Verify by equipping the hammer and checking it sits naturally in the hand at rest, mid-swing, and mid-squash (the stretch animation keeps the `GripAttachment` point anchored to the hand; only the visible mesh stretches around it).

## Intermission lobby

1. Keep the Studio-authored lobby permanently at `Workspace > Lobby`. Do not place it under `ReplicatedStorage > Assets > Maps`; runtime map cleanup must never move or destroy it.
2. Add a direct child folder at `Workspace > Lobby > PlayerSpawns` with at least one anchored `BasePart` spawn marker.
3. Make each marker invisible with `CanCollide`, `CanTouch`, and `CanQuery` disabled. The server teleports returning match participants 3.5 studs above a random marker.
4. Place the lobby at its final world position, separated from match arenas. New arrivals are not automatically teleported there; it is reserved for players returning from a completed match.

## Match maps and recovery

Each enabled `Config.Maps.Pool` entry requires `ReplicatedStorage > Assets > Maps > <AssetName>` as a `Folder` or `Model` authored at its final world position. It must contain `Scriptables > BallSpawns` and `Scriptables > PlayerSpawns`, each with at least one anchored `BasePart`; optional `Scriptables > BouncePads` and `Scriptables > FoamPits` folders contain their feature parts. `ThePit`, `FoamCourt`, and `SkyBounce` are configured but disabled until these trees exist. Set `Enabled = true` only after the matching tree is complete. `RecoveryY` in `Config.Maps` is the out-of-bounds threshold; recovered balls reuse the same instance and cycle across `BallSpawns`.

## Code-built HUD replacement trees

While Studio UI authoring is unavailable, `UIResolver` builds these exact temporary trees. A Studio-authored root with the same name wins later and must provide every listed child. All positions and sizes use `UDim2` scale with anchor points matching their placement.

- `StarterGui > Hud > CatchButton` (`ImageButton`): `AspectRatio` (`UIAspectRatioConstraint`), `Corner` (`UICorner`), `Outline` (`UIStroke`), `Gradient` (`UIGradient`), and `Label` (`TextLabel`).
- `StarterGui > Hud > MatchFlow` (`Frame`): `Respawn`, `Tutorial`, and `ActionFeedback` (`TextLabel`); `CombatFeed` (`Frame`) with `Line1`–`Line3` (`TextLabel`); `Vote` (`Frame`) with `Corner`, `Outline`, `ColorWash`, `Title`, `Timer`, and `Options`; `Options` contains `Option1`–`Option3` (`TextButton`), each with `Corner`, `Outline`, `ColorWash`, `Mode`, `Map`, and `Count`; `Summary` (`Frame`) with `Corner`, `Outline`, `ColorWash`, `Title`, `Stats`, and `Rewards`.

## Verification

1. Confirm `Workspace > Balls` is created at runtime and each spawn creates exactly one ball.
2. Test with **Server & Clients**, not a single local player process.
3. Verify held balls align to `DodgeballGrip`; adjust only that attachment to refine placement.
4. Exercise 0, 100, 150, and 200 ms simulated latency and check that throw/rebound effects do not replay during corrections.
5. Complete a match and verify that participants remain in the arena for Results, then move to `Workspace > Lobby` for Intermission before the arena clone is destroyed.
6. Join with a new client during Intermission and verify that the new arrival is not teleported to the lobby.
7. Verify Starting counts down for 3 seconds without accepting held combat inputs; then test Throw and Catch on mouse/keyboard, touch, and gamepad.
8. During Intermission, vote from multiple clients and confirm counts, selection color, server tie handling, and the winning compatible mode/map pair.
9. Verify FFA respawns in 1 second and TDM uses the displayed 4.5-second wave deadline. Confirm neither respawn creates a new ball, while a late join receives exactly one.
10. Drop every match ball below the map RecoveryY and confirm the same instances return across BallSpawns without changing the total count.
11. Score a dodgeball elimination and verify one splat burst plus the `Splat` sound at the impact point, colored to the thrower's equipped ball skin (default skin → rubber red), identical on every client. Repeat under the latency settings from step 4: exactly one splat, and exactly one hammer squash on hammer hits.
