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

`HammerVisuals` uses a skin's authored `GripAttachment` when present. Without one, it measures that skin's own `BasePart.Size`, requires one clearly dominant axis, aligns that axis to the hand's local Y axis, and places the grip at `Config.Combat.Hammer.AutoGrip.GripAlongLongAxis` of the dominant length. The default hammer is Y-dominant, so the fallback holds its two heads vertically instead of applying the old sideways 90-degree rotation. Squash and stretch also follow each skin's resolved axis and original size.

Dimensions cannot identify an arbitrary mesh pivot or choose between nearly equal axes. For those assets, author `ReplicatedStorage > Assets > Cosmetics > HammerAssets > <Asset> > GripAttachment`; ambiguous assets without one fail immediately instead of displaying with a guessed offset.

1. Symmetric, centered, double-headed hammer skins may omit `GripAttachment` when their head-to-head dimension is clearly the largest local dimension.
2. Add `GripAttachment` to off-center, asymmetrical, or near-square skins and place it exactly where the hand should hold the mesh.
3. Verify every skin at rest, mid-swing, and mid-squash on both R15 and R6 rigs.

## Permanent arena

Create this exact Studio-authored hierarchy. Every named container is a `Folder`, and each spawn pool must contain at least one direct child `BasePart`:

```text
Workspace
└─ Assets
   └─ Arena
      ├─ Map
      ├─ Scriptables
      ├─ PlayerSpawns
      └─ TeamSpawns
         ├─ Red
         └─ Blue
```

`Map` contains all permanent static arena assets. `Scriptables` is reserved for a later world-feature pass. Put non-team spawn markers directly under `PlayerSpawns`, Red TDM markers directly under `TeamSpawns.Red`, and Blue TDM markers directly under `TeamSpawns.Blue`. Spawn markers should be anchored and normally invisible with `CanCollide`, `CanTouch`, and `CanQuery` disabled. Runtime code never clones, reparents, or destroys the arena.

## Matchmaking arrival

Lobby matchmaking sends a versioned TeleportData payload containing match identity, party identity, expected player count, and the allowed mode-vote options. The arena validates that payload and opens the authoritative 10-second vote when the first admitted player arrives; malformed or mismatched arrivals cannot vote or enter gameplay. Direct Studio joins use the enabled options in `Config.GameModes` but do not create a fake matchmaking session. Add FFA and TDM thumbnail asset IDs to `Config.GameModes`; the empty strings are intentional placeholders. Until they are set, each card renders a blank white thumbnail. Infection remains disabled until its gameplay rules exist.

The per-player selection checkmark on each mode card uses a placeholder image asset (`rbxassetid://72382658` in `GameModeCard`); replace it with the intended published asset. It is authored square at 100x100 pixels against a 1890x1200 reference viewport and scales with the card from there.

## Verification

1. Confirm `Workspace > Balls` is created at runtime and each spawn creates exactly one ball.
2. Test with **Server & Clients**, not a single local player process.
3. Verify held balls align to `DodgeballGrip`; adjust only that attachment to refine placement.
4. Exercise 0, 100, 150, and 200 ms simulated latency and check that throw/rebound effects do not replay during corrections.
5. Join the arena directly in Studio and confirm the FFA/TDM vote opens for 10 seconds without TeleportData.
6. Join through lobby matchmaking and confirm every party member is accepted into one arena session with the expected match and party identities.
7. Vote from multiple clients and confirm `XXX` counts, per-player checkmarks, vote changes, random no-vote selection, and random tie resolution. A delayed arrival must see the existing remaining bar time.
8. Let both FFA and TDM win. Confirm FFA uses `PlayerSpawns`; TDM uses the authored Red and Blue pools and keeps lobby parties together.
9. Verify Starting counts down for 3 seconds without accepting held combat inputs; then test Throw and Catch on mouse/keyboard, touch, and gamepad.
10. Verify FFA respawns in 1 second and TDM uses the displayed 4.5-second wave deadline. Confirm neither respawn creates a new ball, while a late join receives exactly one.
11. Score a dodgeball elimination and verify one splat burst plus the `Splat` sound at the impact point, colored to the thrower's equipped ball skin (default skin → rubber red), identical on every client. Repeat under the latency settings from step 4: exactly one splat, and exactly one hammer squash on hammer hits.
