# Dodgeball Studio setup

Apply these changes manually in Studio. Repository tooling must not rewrite `game.rbxl`.

## Victory-emote preview rig

Both places use `ReplicatedStorage.Assets.Rigs.CharacterRig` for the free victory presentation and [Showtime](showtime-pass.md). It must be a complete R15 Model with HumanoidRootPart and paired `*RigAttachment` attachments forming the 15-link body graph. The preview renderer clones this model and strips physics/animation constraints from the clone only.

The previously missing `LeftFoot` was repaired in both open Studio documents during the arena redesign. Required authored properties:

| Property | Value |
|---|---|
| MeshId | `rbxassetid://134464286998182` |
| Size | `Vector3.new(0.9913692474, 0.3178193867, 1.0258681774)` |
| SurfaceAppearance.ColorMap | `rbxassetid://112685197447151` |
| SurfaceAppearance.NormalMap | `rbxassetid://136829035030080` |
| SurfaceAppearance.RoughnessMap | `rbxassetid://104036453087397` |
| SurfaceAppearance.MetalnessMap | `rbxassetid://92127305842810` |
| LeftAnkleRigAttachment.Position | `Vector3.new(-0.026809454, 0.154947519, -0.0771398768)` |

Align the foot with `LeftLowerLeg.LeftAnkleRigAttachment.WorldCFrame * LeftFoot.LeftAnkleRigAttachment.CFrame:Inverse()`. Authored LeftAnkle/LeftAnkleBallSocket constraints connect those two attachments. Keep all other authored rig content. Run `ServerStorage.Tests.Shared.VictoryRig.spec` in both places after saving/importing these asset changes. Do not reconstruct or patch `.rbxl` contents with repository tooling.

Arena loading now preloads this rig with the existing bounded critical manifest. ArenaService projects the authored `Workspace.Assets.Arena.MapOrigin.Position` as the nonstreamed arena Folder's `MapOriginPosition` attribute; loading and the vote camera use that projection so a streamed-out marker cannot stall the streaming request itself.

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
      │  └─ ArenaSpawn        (SpawnLocation)
      ├─ MapOrigin            (invisible BasePart)
      ├─ Scriptables
      │  ├─ ElimZones
      │  ├─ JumpPads
      │  ├─ FoamPits
      │  └─ Rotating
      │     └─ <AssemblyName>   (one Folder per rotating assembly)
      │        ├─ Origin        (BasePart, the axis)
      │        └─ Assembly      (Model, the geometry that turns)
      ├─ PlayerSpawns
      └─ TeamSpawns
         ├─ Red
         └─ Blue
```

`Map` contains all permanent static arena assets, including exactly one `SpawnLocation`
named `ArenaSpawn`. It is required: `MatchService` only teleports a character into the
arena while a match is running, so between matches — including for the whole mode vote —
the engine's default spawn is what places the player. With no `SpawnLocation` in the
place, that is world origin, and a character spawned into empty space falls past
`Workspace.FallenPartsDestroyHeight` and is destroyed.

Position `ArenaSpawn` just above solid arena floor and set:

| Property | Value | Why |
|---|---|---|
| `Enabled` | true | Otherwise it is ignored and spawning falls back to origin |
| `Neutral` | true | Arena teams are a `TeamId` attribute, not Roblox `Team` objects; nothing reads `player.Team` |
| `AllowTeamChangeOnTouch` | false | Prevents touching it from writing an unused `player.Team` |
| `Duration` | 0 | No engine ForceField; MatchService owns spawn protection through the `minv` attribute |
| `Anchored` | true | Must not fall |
| `CanCollide` | false | The floor beneath it catches the player; avoids adding collision geometry |
| `CanQuery` | false | Keeps it out of the sim's line-of-sight raycasts |
| `Transparency` | 1 | Not visible in play |

Also check `Workspace.FallenPartsDestroyHeight` sits below the arena's lowest walkable
point but above where a fall is unrecoverable. There is currently **no void recovery**: the
per-map `RecoveryY` died with the removed `MapService`, so a player who falls off the
arena during a match is destroyed rather than returned to a spawn.

`MapOrigin` is an invisible `BasePart` marking the point the vote camera orbits. Place it
at the centre of the playable arena; the camera circles it at `Config.UI.VoteCamera`
`Distance` studs out and `Height` studs above, looking back at it, for as long as the mode
vote is open. Keep it `Anchored` with `Transparency` 1 and `CanCollide`, `CanTouch`, and
`CanQuery` disabled so it never affects play or the sim's raycasts.

`Scriptables` holds one folder per authored map feature, each named after the feature kit
that drives it. Every direct `BasePart` child of a feature folder is driven by that kit,
and parts may be added or removed at runtime — the service re-reads the folder on change,
so moving or spawned hazards work without extra code.

| Folder | Effect on a player inside one of its parts |
|---|---|
| `ElimZones` | Immediate elimination, scored exactly like a dodgeball elimination |
| `JumpPads` | Bounced upward with a floaty arc. Children are **Models**, not BaseParts |
| `FoamPits` | Movement slowed while inside |

Feature parts are volumes, not touch triggers: a player counts as inside when their
`HumanoidRootPart` is within the part's box, plus `VerticalPadding` studs vertically
(`Config.MapFeatures`). Size them as volumes a falling player passes through rather than
as thin planes. Keep them `Anchored`, and set `CanCollide` false on `ElimZones` so players
fall into them rather than landing on them.

Eliminations only apply during an Active match, so a player standing in an `ElimZone`
between matches is left alone.

A registered kit with no authored folder warns once at startup and stays inactive.

### JumpPads

Each child of `JumpPads` is a **Model** — the trampoline, with a `MeshPart` named `Inner`
and one or more other parts forming the outer shell. The trigger volume is not authored:
it is derived from the model's bounding box, so size the model to the surface you want
players to bounce off.

Parts must be `Anchored`. The client resizes them for the squash, and an unanchored part
would fall the moment it is written to.

`Inner` is matched **by name** and gets the slower, looser spring; every other part follows
the outer spring. That two-spring split is what gives the delayed second bounce, so a pad
whose inner mesh is named something else will squash as one rigid shell.

Author the burst effect at `ReplicatedStorage > Assets > VFX > CloudJumpParticleEmitter`
as a `ParticleEmitter`. The server clones it onto the bouncing character's
`RootRigAttachment`, emits `ParticleBurst` particles, and removes it after
`ParticleLifetime` seconds (`Config.MapFeatures.JumpPad`). It is required — a missing
emitter surfaces as an infinite-yield warning rather than a silent no-op.

Bounce feel lives in `Config.MapFeatures.JumpPad`: `BouncePower` is the vertical speed on
launch (horizontal is preserved), and `FloatFactor` is the fraction of gravity cancelled
while airborne, which is what makes the arc floaty rather than a plain high jump.

### Rotating

`Rotating` holds one **Folder per rotating assembly**. Each contains an `Origin` BasePart
and an `Assembly` Model. The Assembly turns about `Origin`'s **up axis**, keeping the pose
it was authored in relative to Origin, so tilt Origin to tilt the axis of rotation. Speed
is `Config.MapFeatures.Rotating.DegreesPerSecond`, overridable per assembly with a numeric
`RotationSpeed` attribute **on that assembly's Origin**.

Both children are required and are resolved with `WaitForChild`: a folder missing either
one is a setup error and should surface as such.

Only the **server** drives the spin; clients receive the pose through ordinary
replication. Both sides moving the same anchored assembly fight each other, each write
undoing the other's, which shows up as the ring stuttering violently instead of turning.

**Riders.** The local client carries its own character with the platform it is riding
(`PlatformRider`). Under default network ownership that position replicates outward, so
other clients and the server see it without a second mover. Only position is carried, never
facing — rotating the camera under a player would fight aiming.

The carry measures the assembly's movement frame over frame from the assembly itself,
so it stays correct under replication lag rather than assuming the client's clock.

Carry continues while the rider is **airborne above the assembly's footprint**, which is
what makes a jump land in the same spot relative to the platform instead of the platform
turning out from under them. The window is the assembly's bounding box extended
`CarryHeight` studs above its top (`Config.MapFeatures.Rotating`); jump past the edge and
carry stops, so you can still leave normally. Note this is a deliberate assist rather than
physical behaviour: a real jump from a turntable leaves tangentially.

Size each `Assembly` so its bounding box matches the ridable surface — the footprint test
uses that box, so a stray decorative part sticking far out widens the carry area with it.

## Matchmaking arrival

Lobby matchmaking sends a versioned TeleportData payload containing match identity, party identity, expected player count, and the allowed mode-vote options. The arena validates the payload and its authenticated source place/universe, starts a 20-second arrival/readiness gate on the first matched admission, and opens the authoritative 10-second vote when all expected clients are ready or the gate expires with at least one ready client. A zero-ready gate remains closed. Late-ready clients receive at least five visible voting seconds within the extension cap, or join the active match. Malformed, untrusted, or mismatched arrivals cannot vote or enter gameplay. Direct Studio joins use the enabled options in `Config.GameModes` and release their gate once the local client and profile are ready. Add FFA and TDM thumbnail asset IDs to `Config.GameModes`; empty strings intentionally render the readable card fallback. Infection remains disabled until its gameplay rules exist.

Apply the CollectionService tag `CriticalPreload` only to authored arena instances visible from the vote camera or the initial spawn areas. Do not tag the whole map. The loading client already includes the loading and ballot images, configured thumbnails, fonts, required animations, default weapon carriers, and immediate gameplay audio in its explicit preload manifest. No Studio UI instances are required for the loading screen.

The per-player selection checkmark on each mode card uses a placeholder image asset (`rbxassetid://72382658` in `GameModeCard`); replace it with the intended published asset. It is authored square at 100x100 pixels against a 1890x1200 reference viewport and scales with the card from there.

## Verification

1. Confirm `Workspace > Balls` is created at runtime and each spawn creates exactly one ball.
2. Test with **Server & Clients**, not a single local player process.
3. Verify held balls align to `DodgeballGrip`; adjust only that attachment to refine placement.
4. Exercise 0, 100, 150, and 200 ms simulated latency and check that throw/rebound effects do not replay during corrections.
5. Join the arena directly in Studio and confirm the FFA/TDM vote opens for 10 seconds without TeleportData.
6. Join through lobby matchmaking and confirm every party member is accepted into one arena session with the expected match and party identities.
7. Vote from multiple clients and confirm `XXX` counts, per-player checkmarks, vote changes, random no-vote selection, and random tie resolution. A client becoming ready during the ballot must receive at least five visible seconds within the ten-second aggregate extension cap; a later client must join the current match exactly once.
8. Let both FFA and TDM win. Confirm FFA uses `PlayerSpawns`; TDM uses the authored Red and Blue pools and keeps lobby parties together.
9. Verify Starting counts down for 3 seconds without accepting held combat inputs; then test Throw and Catch on mouse/keyboard, touch, and gamepad.
10. Verify FFA respawns in 1 second and TDM uses the displayed 4.5-second wave deadline. Confirm neither respawn creates a new ball, while a late join receives exactly one.
11. Score a dodgeball elimination and verify one splat burst plus the `Splat` sound at the impact point, colored to the thrower's equipped ball skin (default skin → rubber red), identical on every client. Repeat under the latency settings from step 4: exactly one splat, and exactly one hammer squash on hammer hits.

## Lobby scene streaming

`Workspace.Views.Party` must be a **Model** with `ModelStreamingMode = Persistent`. Keep its existing `Background`, `Players`, `Static`, `podium_002`, `SplashScreenCamera`, `InventoryCamera`, and `ShopCamera` children and their authored properties. The backdrop and camera markers are required before the lobby loading controller finishes; a streamed Folder can lose its BaseParts and deadlock that initialization.

This conversion was performed in the open lobby Studio document through MCP on 2026-09-06, preserving all children, attributes and tags. Save it through Studio together with the authored victory-rig repairs above before running the saved-place deployment suite. The lobby `Matchmaking/Scene.spec` asserts this requirement. The source controllers still use required-asset `WaitForChild` checks.
