# Splashdown hazard kits

Phase 1 / Gate 2 review, 2026-09-15. Gate 1 approved; no Deprecated archive will be kept. Existing arena names and **all existing tuning values are unchanged**. New courses use attributes, never arena names. The pilot has not been built; it requires Gate 2 approval.

## Integration contract

Keep the existing tagged Scriptables root and kit folders. `ScriptableRoot` is a CollectionService tag, not a boolean attribute. Each rotating group has an Origin and Assembly; course Origins use `RotationSpeed=0`. Put the final, renamed geometry and attributes in place **before tagging** the root. Kits cache immutable assemblies. Attribute rotors turn around explicit mechanical pivots: an imported display pivot is not necessarily an axle. Change pivots, never distort the mesh. All motion/state is server-side; new effects use separate noncolliding client ghosts.

```text
Scriptables [CollectionService tag: ScriptableRoot]
  Rotating/<group>/Origin [RotationSpeed=0, ServerCarries=true for rides]
                   Assembly/<renamed asset hierarchy with kit attributes>
  JumpPads/<renamed Model>/Outer, Inner
  FoamPits/<renamed volume>
  Doors/<renamed slabs with DoorRow + DoorIndex>
```

Folders and pad roles are existing structural contracts, not arena name selectors. `JumpPad` and `FoamPit` are explicit authoring markers; their existing folders dispatch the runtime kits. `Spinner`, `Disc`, `SwingPanel`, `Rotating` and `RotorBump` are **not extra course selector attributes**: use the equivalent Rotor recipes below. Keep `EnabledNames` and prefix lists untouched. Do not double-drive a course with both Origin rotation and local Rotor motion.

Call `Shared.Game.MapFeatures.AttributeAudit.check(root, optionalMetadataAllowlist)` before activation and fail on returned errors. It checks unknown attributes, types, axes, combinations, container roles, anchoring, carry ownership and critical never-respawn tiles. `AttributeRules` is the pure rules layer. Course geometry, gate cut sets, timing and variety checks remain Phase 2/3 work; this validator does not claim those pass.

## Rotor composition, carrying and timed profiles

**Rotor / Sweepers / Pendulums.** A declared Rotor owns its part and descendants up to the next declared Rotor. Nested motion composes parent-local transforms; every part has exactly one owner. Surface velocity includes every ancestor's slide and angular motion. For a sweeper, put `Rotor="slide"` on the translating carrier/frame and `Rotor="spin", RotorAxis="X", Shove=true` on its long-axis drum. The drum alone can spin for a log-roll bridge. A mace uses `Rotor="rock"` at the top chain pivot; its links and ball are descendants. Set phase, period and amplitude explicitly. No new per-part heartbeat or physics constraint is used.

**Rides / gap platforms.** Set `RotorCarries=true` on a spin/rock/slide rotor and `ServerCarries=true` on its group Origin. The server transfers the actual support part's full XYZ rigid transform to the runner, with support ray, normal, frame-duration and teleport bounds. The client skips its old carry path for that group. Nested children inherit carry eligibility from a carrying ancestor. Standard character input ownership is unchanged; the hazard transform is server-issued. The pizza plate and carousel are normal Y-spin + carry recipes; their holes remain the source mesh's collision geometry. Optional `RotorAccel` is degrees/s² and requires a **live synchronized** `MotionEpoch` on Origin; do not save an epoch of zero in a course template. `RotorPhaseDegrees` sets initial spin angle; `RotorPhase` remains seconds for rock/slide. Ordinary arena motion remains unchanged.

**Hammer.** Set `Rotor="rock", RotorProfile="hammer"`, axle axis, `RotorAmplitude` in degrees, and phase in seconds. `WindupSeconds` defaults to 1.8 and `StrikeSeconds` to 0.3. Smooth endpoint easing moves from minus to plus amplitude on the wind-up, then returns on the strike. Add `Shove=true` and `ImpactVisual=true` on the moving hammer, not its static pillar. Pivot the moving head around the pillar's actual axle. Neighbour phases are declarative. Lane blocked fraction still needs measurement on the pilot; these defaults alone do not certify 40% coverage.

**Piston.** Set `Rotor="slide", RotorProfile="piston"`, axis pointing along the punch, `PistonPeriod`, `PistonPhase`, `PistonExtendStuds`, and `HoldSeconds`. Travel is home→extended→hold→home→rest, not a centred sine. Defaults are 3.2 s / 12 studs / 0.6 s. Of the non-hold time, extension is 20%, retraction 30%, rest 50%. Mark the moving head/spring assembly for shove, keeping the wall mount fixed. For the half-scale fixture, 6 studs is the tested profile extent; socket overlap must bound the final course's stroke so the spring does not detach visually. Do not stretch spring geometry.

**Contact contract.** Bumper and Rotor shoves retain the bounded target velocity + brief LinearVelocity hold, not additive acceleration. They now read per-part `RetriggerCooldown` (0.1–10 s) and `GuardSeconds` (0.3–10 s); guard cannot be shorter than the existing safe hold allowance. One hit per continuous visit; a new visit must also clear cooldown. `ShoveSpeed`, `ShoveUpwardSpeed`, `ShoveSeconds` retain their existing bounds. `ShoveContact="mesh"` opts courses into actual collision-volume overlap; omit it for the legacy padded-box behavior. Some source meshes have hollow collision centers, so probe a real surface, not the bounding-box center. `ImpactVisual=true` adds the client-only ghost pulse. Actual surface queries use Roblox's [GetPartsInPart contract](https://create.roblox.com/docs/reference/engine/classes/WorldRoot#GetPartsInPart).

## Big Balls

Mark only `obstacle_23_002`'s renamed sphere with `BigBall=true`; its blue pole is support geometry. The nearest root-to-feet capsule point determines the contact normal. A descending contact within `CapDegrees` (40° default) of the sphere's pole axis bounces at `BounceSpeed=58`, with JumpPad-style gravity cancellation `FloatFactor=0.25`. Side contacts receive outward `RollOffSpeed=38`, upward 6, and a 0.18 s hold. Cooldown defaults to 0.65 s; guard defaults to 1 s for roll-off and covers the whole bounce float. Float expires at 3 s or landing and does not stack with JumpPad/fan float. A later pole-rock Rotor can bob/tilt the entire assembly. Put the balls over race liquid, never a walkable bypass slab. Server contact/state, client impact squash; no new meshes.

## Conveyors

Mark the actual chevron panel `Conveyor=true`. Signed `ConveyorSpeed` is studs/s along local `ConveyorAxis` X/Y/Z (default Z, speed 15.6). Match the sign to the visible chevrons after rotating the asset. The anchored part's `AssemblyLinearVelocity` drives both humanoids and physical beach balls; support contact grants a short bounded movement allowance. Unload restores authored surface velocity. Belt orientation and friction matter: the actual kit mesh moved an idle R15 runner at 14.31–15.68 studs/s across two runs and a rolling beach ball at ~8.18, not exactly the commanded 15.6. Use measured route trials to size side-belt fall windows.

## Falling tiles

Mark a rainbow tile `FallingTile=true`. First support contact arms one shared countdown; it keeps counting after the player leaves, and additional runners do not restart it. `DropDelaySeconds` defaults to 0.65; all clients see a shake while the server retains collision. On expiry the server hides the tile and disables collision/query/touch; geometry stays anchored. `RespawnSeconds` defaults to 5, measured from disappearance; zero never respawns until unload/reset. Reset restores each member's authored transparency and collision flags. Existing Splashdown uses checkpoints, so **critical route tiles must respawn**; the validator rejects zero when `CriticalRoute=true`. The non-respawning API is supported but is not approved for stranding later racers on Tiptoe Trials.

## Seesaws

Mark the moving board `Seesaw=true`, with explicit centre/axle pivot, `SeesawAxis` X or Z, `MaxTiltDegrees` (24° default), and optional `SeesawResponse` (3 default). Server support rays accumulate signed normalized rider offsets; equal opposite riders cancel, offsets add for crowds, and the result clamps before exponential easing. An empty board returns to level. The board and descendants move together; enable Origin server carry. `obstacle_25_002` is long in Z, so its tested axle is X. Seesaws require a stationary group and may not also inherit a Rotor: the audit rejects competing motion owners. This is not needed for the approved course set; nested Rotor-under-Rotor itself is supported.

## Fans, beach balls, pads and existing kits

**Fans.** Existing `Fan` + `FanBlade` selectors work after renaming. Add `FanAxis` for a directed local-axis column, `FanDirection=1|-1`, `FanColumnHeight`, and per-fan `LaunchSpeed` / `FloatFactor`. Rotate the fan so the visual grate faces the same direction. The launch sets a velocity floor along the axis and does not stack per-frame impulses. Attribute fans accelerate live attribute beach balls toward `FanBallSpeed=32` at up to 45 studs/s², preserving transverse physics. A ball can leave the column under gravity; tunnels and support floors must constrain it. Unmarked arena fans retain world-up launch behavior and original defaults.

**Beach balls.** `BeachBall=true` discovers multiple renamed descendants in an Assembly; do not also give them a kinematic motion owner. The kit moves them beside their own Scriptables root, unanchors them and assigns **server network ownership**. Existing density/friction/elasticity and 420-stud / -80-height reset limits are unchanged. Fans and anchored conveyors act on their real physics. Removing the owning assembly removes its detached runtime balls; reset restores the original parent, anchor/collision state and physical properties for attribute balls. Arena prefix compatibility remains.

**JumpPad.** Keep the existing JumpPads Model and Outer/Inner roles, and mark the model `JumpPad=true`. The previously ignored per-model `LaunchSpeed` is now honored (1–160); `FloatFactor` can override gravity cancellation (0–0.9). Omit both to retain BouncePower=85 / the existing shared float tuning. Cooldown, landing cleanup, MovementGuard and the existing client pad effect remain. A renamed-model test measures a configured 51-stud/s launch and 0.2 gravity cancellation.

**FoamPit / Bumper / Spinner / Disc / SwingPanel.** FoamPit uses the unchanged volume folder, 0.45 speed multiplier and exit cleanup. Bumper is the existing explicit selector, now with the optional precise-contact/cooldown/guard overrides above; course placement must force contact. Spinner, Disc and SwingPanel meshes use attribute Rotor spin/rock (plus carry or shove as appropriate), not their legacy arena name paths. The contact probe confirms renamed actual meshes reach their configured response. This is kit compatibility, not proof of a fair lane or no bypasses.

**Doors.** Keep `DoorRow` and `DoorIndex` positive, paired, unique and contiguous from 1. `DoorRows.resolve` rejects duplicates, gaps and invalid numbers instead of silently losing rows. Course config supports PerRow=3/4/5 and BreakablePerRow=1..PerRow; the existing server-secret `DoorPlan` chooses that quota per row, and tests exercise every valid quota at all three sizes. Break/solid semantics, client animation and round reset are unchanged. There is no new checkpoint kit: the mode's existing ordered checkpoints already respawn racers and remain untouched.

## Reusable rising liquid

Set `RisingLiquid=true` on the course hazard volume, `StartDelaySeconds`, positive `RiseStudsPerSecond`, and `MaxHeight` as **rise above the authored liquid pose**, not world Y. Optional `PauseWaypoints="20:3,40:2"` pauses at +20 for 3 s and +40 for 2 s; heights must increase. `RisingLiquid.resolve/heightAt` is pure, deterministic and resettable; the existing race still owns start/reset/respawn decisions. The legacy Summit `RiseStuds`, `RiseDelaySeconds`, `RiseSeconds` adapter is regression-tested: +60 over 140 s after the same 20 s delay. No round, checkpoint, fall, qualification or finish behavior was rewritten. Only Piston Peak may reuse this twist in the new set.

## Gate 2 evidence and limits

- 967 headless tests, zero failures; includes trajectories and legacy Summit parity.
- 25 Studio TestEZ smoke tests, zero failures: [raw result](evidence/kit-tests.json). The first test harness attempted to create a Player, which Roblox forbids; it was corrected to an opaque test identity. Production Player-filtered contacts are tested separately below.
- Eighteen mesh/R15 physics trials, nine scenarios repeated: [first run](evidence/kit-physics.json), [confirmation](evidence/kit-physics-confirmation.json). First-run slide carry: 878/878 supported frames, max local drift 0.0108 studs; spin: 915/915, 0.00056 studs. Confirmation: 820/820 slide frames and 776/776 spin frames, each below 0.003 studs drift. Seesaw reached 10.67°, retained support and returned to 0.028° after two empty seconds. These are high-frame-rate, one-machine server-owned-R15 measurements, **not** 30-player, 60 Hz or adverse-latency certification. Big Ball side displacement varied 3.26–5.62 studs over 0.6 s: do not equate configured speed × hold with guaranteed travel to an edge.
- Actual Player + renamed mesh contact checks: [kit-contacts.json](evidence/kit-contacts.json). Bumper 54, all seven tested Rotor meshes ~48 studs/s, all holds created; FoamPit 0.45 then cleared. Contact tests intentionally place the root on sampled surfaces; they do not measure traversal time or shove travel to an edge.
- Client shake/impact observation: [kit-visuals.json](evidence/kit-visuals.json). Ghost moved/deformed, never collided/queried/touched; source CFrame/Size unchanged; cleanup restored local visibility.
- Fixed-camera kit-review capture was attempted but did not return and was cancelled. No new screenshot is claimed. Existing Phase 0 reference/identification captures remain available. Retry Studio capture before the mandatory pilot visual QA; do not waive that gate requirement.
- The existing empty Templates folder / missing CrossCurrent failures remain baseline course-registration problems, not kit-test passes. No course-wide cut-set, gap, density or clear-time certification is claimed at Gate 2.

Reproduce with `lune run src/scripts/lune/run-tests.luau`, plus the normal Studio Script bootstrap in `probes/run-kits.server.luau` in Play. `src/scripts/studio/author-splashdown-kit-lab.luau` creates **only existing uniformly scaled meshes** in a temporary fixture folder; `probes/measure-kits.server.luau`, `contacts.server.luau`, and the two `visuals.*.luau` probes exercise the real modules. Do not give MCP interactive code elevated capabilities: ordinary temporary Scripts/LocalScripts supply the supported test context. Remove those probes/fixtures before saving or publishing.

All temporary Edit probes, LocalScript observer, replicated fixture models and review gallery were removed after testing. Studio is back in Edit mode. The original source kit, seven parked course models and ninety Keyframes remain untouched at this kit-only gate. Source changes are committed locally by kit on `feature/splashdown-hazard-kits`; no PR has been pushed. The Studio unit-test skill guided the separation of deterministic assertions from measured physics/presentation probes; one is not substituted for the other.

The source asset gallery still lives in the open Studio place; the repo still lacks its authored base-place snapshot. Before the pilot, establish a source-only kit + Summit export/manifest, without copying any retiring courses into an archive. Old course retirement occurs at the validated replacement swap under the Gate 1 approval; no Deprecated archive will be created.
