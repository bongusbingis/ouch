# Splashdown discovery — Gate 1

Date: 2026-09-15. Repository baseline: `059e509`. Place inspected: **121997450145716 (Match Place)**. This is discovery, not approval to build.

## Executive findings

- Capacity is **30 racers**. Falls cause **checkpoint respawn**, not elimination from the race. Three independently drawn courses award placement points; there is no qualification quota.
- Eight IDs are registered, but the open place has **zero active templates** and only **seven parked course models** under `Workspace.LegacyCourses`. CrossCurrent exists as a recipe, not an authored model. Boot fails before an ordinary Splashdown round starts.
- Actual movement is **WalkSpeed 26, JumpHeight 10, UseJumpPower false, gravity 120**, not the Roblox defaults. The server-owned R15 probe clears 22-stud flat gaps; 22.25 fails. Initial jump apex is about 10.10 studs; the Humanoid can step onto a ledge above that apex. See the calibration section and raw results.
- The showcase has **176 top-level MeshPart assets**, with children on multipart props, no attached scripts or attributes. The complete inventory and reference crosswalk are in [01-asset-inventory.md](01-asset-inventory.md).
- Uniform scaling exists. The existing author is procedural code, not a declarative socket builder. It also overwrites same-ID templates; it was **not run** against the authored place.
- Attribute paths already work for simple Rotor, Shove, Bumper and Fan course pieces. Nested Rotors, vertical carrying, per-pad LaunchSpeed, name-free beach balls and directional ball airflow need work. The source kit has considerably more geometry than implemented behaviours.
- No gameplay, tuning values, registrations, arena name lists, or existing courses were changed in discovery.

The brief appears to have lost range/comparison glyphs. This audit reads “6090” as 60–90 s, “35 doors” as 3–5, “58 beats” as 5–8, “0.60.9” as 0.6–0.9. The default-jump example also mixes two Roblox jump modes; see below.

## Evidence and limits

Reviewed all eleven `bad-map-refs/1.png` … `11.png`, current source, the seven parked models, and the older `.review/splashdown-candidates/VALIDATION.md` plus eight final-overhead images. The referenced tuning-module copy is **not present** in `bad-map-refs`; this audit uses the canonical [MapFeatures.luau](../../src/config/Gameplay/MapFeatures.luau).

Old gallery screenshots and its estimated pars are historical evidence, **not new traversal measurements**. Its reported headless count was 862; today's headless run is 960. Its copied/inline contract assertions and teleports do not establish an end-to-end clear time. CrossCurrent's old screenshot does not establish that its model is in today's place.

New raw evidence:

- [inventory.json](evidence/inventory.json): every source part's size, full CFrame, PivotOffset, MeshId, collision/anchor state, attributes, scripts, and mesh-matched course usage; current counts, bounds and clone timings.
- [contract-tests.json](evidence/contract-tests.json): real TestEZ course-contract results.
- [movement.json](evidence/movement.json), [movement-refinement.json](evidence/movement-refinement.json), [movement-threshold.json](evidence/movement-threshold.json), [movement-confirmed.json](evidence/movement-confirmed.json), [movement-final.json](evidence/movement-final.json): actual server physics, including the rejected short-input trials and corrected measurements.
- [kit-lineup.jpg](evidence/kit-lineup.jpg): new fixed-camera Studio capture. Further reference captures are indexed in the inventory.
- [probes](probes/): checked-in, reproducible discovery scripts. These are diagnostics, not new gameplay kits.

## 1. Lifecycle and race rules

Primary sources: [Splashdown config](../../src/config/Gameplay/Splashdown.luau), [course resolver](../../places/arena/server/Modules/Splashdown/SplashdownCourses.luau), [race service](../../places/arena/server/Modules/Splashdown/SplashdownService.luau), [VenueService](../../places/arena/server/Modules/VenueService.luau), [RaceRound](../../src/shared/Game/Splashdown/RaceRound.luau), [CourseSequence](../../src/shared/Game/Splashdown/CourseSequence.luau), [Queues](../../src/config/Gameplay/Queues.luau).

1. Config `CourseOrder` is the registry; definitions live in `Courses`. Startup validates **every registered template**, not just the randomly selected one. Templates are expected at `ReplicatedStorage.Assets.Maps.Splashdown/<ID>`.
2. `CourseSequence.draw` chooses three distinct courses without replacement. The shared Splashdown mode delegates to the race service. The outer mode cap is 720 s; it does not preserve dodgeballs.
3. VenueService parks the arena interior (levels, boundary, Scriptables, player/team spawns) in `ServerStorage.ArenaInterior`, unregisters arena scriptables and stops ball supply. The separate showcase was absent from Workspace in the later Play probes; collect source inventory in Edit. Do not assume that display survives Play: its source parts are unanchored.
4. A template clone is named `SplashdownCourse`, `PivotTo(MapOrigin.CFrame)`, resolved, tagged through ScriptableRoots and parented into the arena. Its own pivot must agree with its Origin. Destruction untags and destroys the **live clone**, not the source.
5. Required contract: BasePart Origin; Scriptables Folder; Start/Pads with at least queue capacity immediate BaseParts; Checkpoints with one or more named/sorted Models each containing Trigger and Pad; matching CheckpointCount attribute; Finish/Trigger and Finish/Deck; nonempty direct-part Hazards and Boundary folders. Marker order is lexicographic; use zero-padded numbers.
6. Course spawn markers are sorted by name; the race uses `MapFeatures.Spawns.RootOffsetStuds = 3.5`. `MaxOriginDistanceStuds = 600` is an **arena spawn filter**, not a full-course bound check and not enforced on the course markers by this resolver. New QA must enforce it explicitly on corners and spawns. Current MapOrigin is (-537.767, 460.777, -54.314), identity rotation.
7. Server heartbeat checks racer root positions against course hazard/checkpoint/finish volumes. Checkpoints must be earned **in order**. Finish only counts after all checkpoints; trigger vertical padding is 4.
8. A course Hazards volume hit (padding 2), or a fall 80 studs below the course floor, records a splash and respawns after 0.8 s at the latest checkpoint/start. There is no per-fall knockout. A flooded spawn searches forward for a dry checkpoint pad, or uses Finish.Deck if none is dry; **checkpoint credit is not automatically advanced**. This merits a regression test: physical forward respawn and ordered checkpoint credit can disagree.
9. First finisher starts a close window, bounded by the course cap; all-finished can end early. There is no top-N qualification. Everyone runs all three rounds. First earns 30 points, then descending placement points; DNF earns zero and is charged the cap for the cumulative-time tiebreak. Winner: most points, then lower cumulative time.
10. Intro 9 s, countdown 3 s, results 6 s. Current queue minimum 2 / maximum **30**; author also hardcodes 30 pads.

### Registered timing (configuration, not measured clear time)

| ID | Par / cap / close window, seconds | Current model |
|---|---:|---|
| WhirlPool | 60 / 120 / 30 | Parked |
| DiscJockey | 70 / 135 / 30 | Parked |
| KnockKnock | 70 / 135 / 30 | Parked |
| BumperBay | 85 / 150 / 35 | Parked |
| SummitSplash | 115 / 210 / 45 | Parked |
| TiltTrip | 120 / 210 / 45 | Parked |
| CrossCurrent | 145 / 240 / 55 | Missing; recipe only |
| Downpour | 115 / 210 / 45 | Parked |

### ElimZone versus race liquid versus FoamPit

These are different mechanisms; do not interchange them.

- `ElimZones.luau`: direct BaseParts in a tagged root's ElimZones folder; oriented finite volume plus 2 studs vertical slack; calls MatchService elimination subject to invulnerability. It is an arena elimination kit.
- Splashdown `Hazards`: race-service root-volume checks, checkpoint respawn and splash presentation. The pink course floor belongs here. It does **not** rely on ElimZone name matching.
- `FoamPits.luau`: direct BaseParts in FoamPits, volume padding 2, WalkSpeed modifier ×0.45 while inside. No damage/elimination/checkpoint change. At nominal 26 this is 11.7 studs/s; a penalty lane must be measured to cost at least 5 s relative to its alternative, not merely take 5 s end-to-end.

## 2. Summit Splash and the builder

Source: [author-splashdown-courses.luau](../../src/scripts/studio/author-splashdown-courses.luau), especially `recipes.SummitSplash`; liquid reset/step and flood-safe respawn are in SplashdownService.

Summit uses eight curved arc sectors (90/45/56/56/90/45/56/45 degrees), nominal inner/outer radii 160/200; each rises 5 studs. It alternates windmills with paired triangular bumpers and chicane walls with mace-on-chain rockers, then turns inward over road pieces to a central raised finish. Four checkpoints. The maces **are scripted**: the root is a rock Rotor with Shove and descendant chain/ball followers, not loose physics/decorative chains.

Its liquid is already mode-owned, not a bespoke Script in the course. Builder writes `RiseStuds=60`, `RiseDelaySeconds=20`, `RiseSeconds=140` on a Hazards part. Resolver selects the first positive-rise hazard, caches its base CFrame; service resets and translates it over race elapsed time. That is a 0.428571 stud/s rise after 20 s, capped at +60. If no rising part exists, the first hazard is used for the liquid presentation reference.

Proposed extraction must be a reusable, side-effect-limited trajectory/config helper called by the existing service, with a legacy adapter preserving those exact numbers. It must not become a second heartbeat or change race/flood-respawn semantics. Requested MaxHeight must have explicit local-height units; pauses must preserve monotonicity.

The author clones showcase MeshPart roots into a temporary Model, uses **uniform Model:ScaleTo** (default 0.55, per-piece override supported), anchors parts, normalizes imported PivotOffset and establishes a bottom-centre placement frame. It has eight imperative recipes, reusable geometry/hazard helpers, and preview/restore methods. It does **not** expose declarative entry/exit sockets or named beats. Several helper names are misleading (see inventory).

`Author.build(ids)` removes an existing same-ID template before replacing it. It was not invoked during discovery. New building should be staged/versioned and transactional, preserve source models, validate before swapping registration, and operate only on approved IDs.

Current runtime requires top-level Start/Checkpoints/Finish/Scriptables. Beat folders therefore cannot simply replace that hierarchy. Proposed adapter: keep these public folders/markers; put beat-authored visual groups under numbered beat folders, attach explicit source/beat/gate metadata, and generate compatible scriptable indexes. Doors currently require direct parts under Scriptables.Doors, so preserve that index or deliberately extend only the resolver's traversal without changing results. Confirm at Gate 1.

## 3. Kit audit

Server kit sources are in [arena MapFeatures](../../places/arena/server/Modules/MapFeatures/). Motion math is in [RotatingPlatforms](../../src/shared/Game/MapFeatures/RotatingPlatforms.luau) and Rotation; support/carry is in [PlatformRider](../../places/arena/client/Modules/Movement/PlatformRider.luau). Shared settings are [MapFeatures](../../src/config/Gameplay/MapFeatures.luau); course-only defaults are Splashdown.HazardResponse.

### Discovery/registration and composition contract

MapFeatureService has one Heartbeat and a registry of nine kits: ElimZones, JumpPads, FoamPits, FanUpdraft, SpinnerBump, RotorBump, Bumpers, BeachBalls, Doors. Kits see tagged Scriptables roots in Workspace, then prescribed direct child folders and immediate instances of their declared class. Rotating-based kits inspect a `Rotating/<group Folder>/Assembly Model` with an Origin part. Tagged roots can be course clones; arbitrary attributes on arbitrary Workspace parts are **not sufficient**.

`Attributes.ScriptableRoot` names a **CollectionService tag**, not a boolean attribute. New course folder tagging must use ScriptableRoots and avoid double registration. No course name belongs in an arena EnabledNames/prefix table.

| Feature / implementation | Attribute inputs | Shared tuning / behaviour | Course support and gaps | Client presentation |
|---|---|---|---|---|
| Rotor spin/rock/slide — RotatingPlatforms, Rotation | Rotor mode; RotorAxis X/Y/Z; RotorSpeed deg/s; RotorAmplitude degrees for rock / studs for slide; RotorPeriod seconds; RotorPhase seconds; RotorCarries | Spin linear phase; rock/slide sinusoidal. Period floored at 0.05. Invalid axis silently falls back to Y. Phase affects rock/slide, **not spin**. Descendant BaseParts follow root | Simple roots work. Nested rotors **do not compose correctly**: child and parent transforms are independently assembly-relative; parent follower ownership overlaps child ownership. Needs ordered parent-local solve | Server motion replicates; client loads support geometry |
| RotorCarries — RiderSupport / PlatformRider | RotorCarries true | Rotating carry tolerance .75; support normal ≥.5; carry height 16; airborne retention ≤4 s on previous support; dt ≤.2; assembly displacement ≤16; carry delta ≤4; minimum delta .001 | Spin/horizontal slide carry exists. Client applies **horizontal delta only**; vertical slide/rock carrying incomplete. Requires actual rider regression tests | Existing carry moves client character root; it is **not visuals-only**. Guard validates allowance. New authority path must be opt-in/preserve arena |
| Shove / RotorBump | Shove true plus ShoveSpeed, ShoveUpwardSpeed, ShoveSeconds; uses owning Rotor surface velocity | Default 34 horizontal /14 up / .15 hold, outward bias .35, padding .75, minimum surface speed .5; cooldown .8, guard .8 | Attribute-compatible. Contact is a padded part OBB including followers, not mesh-spike contact; holes/nonconvex shapes can falsely hit. Nested ownership ambiguous | No dedicated rotor impact visual today |
| Bumper — Bumpers | Bumper true; same three Shove overrides | 36 /14 / .12; padding .75; cooldown .6, guard .6; prefixes obstacle_18_001 / obstacle_19_001 kept for arena | Course attributes work inside supported Assembly. Static bumper under moving rotor can be a follower; no independent motion | BumperHit: client impact sound/spring squash; beat-locked ambient squash. Server collision remains unchanged |
| Fan / FanBlade — FanUpdraft + RotatingPlatforms | Fan true on base, FanBlade true on blade | Shared 300 deg/s blade; LaunchSpeed65; FloatFactor.65; opening radius .7 × half-width; entry6, column18, bottom tolerance.5; max lift.45; cooldown.75; guard3 | Course base/blade attributes work. Launch is **world up**, not rotated fan direction. No per-fan overrides or beach-ball force today | Four airflow beams; replicated blade rotation |
| DoorRow / DoorIndex — Doors, DoorPlan, SplashdownCourses | Numeric row/index on direct Scriptables.Doors slabs | Course config Doors.PerRow / BreakablePerRow; random chosen breakable subset; contact padding3 / vertical1; BrokenSeconds1.6 | 5/2 used by KnockKnock; selection supports variable counts, including 3–5. Missing index uniqueness/range checks and sparse-row handling. Broken state stays until reset | DoorBroken fall/fade animation (1.6 s), separate from authoritative collision state |
| JumpPad — JumpPads | **LaunchSpeed is documented but not read**; no registered JumpPad selector attribute | Folder JumpPads, Models with Inner/Outer convention; BouncePower85; FloatFactor.65; contact.75; FallSpeed5; max float8; cooldown.15 | Works by course folder/model convention, not arena names. Per-pad speed bug must be fixed without changing unspecified-pad defaults | Spring squash on inner/outer; launch sound/particles; server gravity cancellation |
| FoamPit — FoamPits | No registered FoamPit selector/override | Folder FoamPits, direct BaseParts; speed ×.45; vertical padding2 | Folder-compatible course volume; no instances in current recipes | No dedicated dynamic foam visual |
| ElimZone — ElimZones | No registered ElimZone selector/override | Folder ElimZones, direct BaseParts; padding2 | Generic tagged-root kit, but course liquid intentionally uses race Hazards instead | Match elimination presentation, not course splash |
| Spinner — SpinnerBump / RotatingPlatforms | No Spinner selector attribute | Exact EnabledNames; spin100 deg/s; shove42/16/.15; outward bias.3; padding.75; cooldown1; guard.8 | Legacy name-matched arena pieces only. Course author instead uses Rotor+Shove; don't copy arena names to activate Spinner | Replicated motion; no special impact squash |
| Disc — RotatingPlatforms | No Disc selector attribute | HubPrefix obstacle_14_001, PlatePrefix obstacle_14_002;45 deg/s; plate carries | Legacy prefix path. Current course discs use Origin RotationSpeed on whole Assembly. Attribute Rotor+Carries can be canonical course preset | Replicated rotation plus existing carry |
| SwingPanel — RotatingPlatforms | No SwingPanel selector attribute | obstacle_8 axle/panel prefixes; rock X ±28°,2.8 s, suffix phase step.55; legacy panel does not carry | Course flap helper instead gives child Rotor rock ±18°,2.8 s and Carries. Parent should be static | Replicated panel motion |
| Rotating assembly — RotatingPlatforms | Numeric RotationSpeed on Origin (outside Attributes registry) | Whole Assembly default1 deg/s; support limits above | Works on course clones; overlaps local Rotors conceptually. Proposed course convention: Origin RotationSpeed=0; all motion explicit Rotor presets | Client support/carry, server transforms |
| BeachBall — BeachBalls | **No BeachBall attribute** | ball_001 prefix, immediate Assembly children; density.08/friction.7/elasticity.45; check.5 s; reset beyond radius420 or below MapOrigin−80 | Multiple balls already supported; reparented outside mover to sibling runtime BeachBalls folder, unanchored. Builder reuses ball_001 names: violates new rule. No SetNetworkOwner(nil), fan force or conveyor kit | Ordinary replicated physics; no separate visual solver |

### Contact cooldown and movement guard semantics

Bumper, RotorBump and SpinnerBump keep per-player contact membership and a per-kit per-player cooldown. One continuous overlap causes **one shove**, not a shove every cooldown; leave/re-enter after the cooldown to retrigger. Different hazards using that same kit share the player's cooldown, so closely packed phase arrays need tests. Fan also tracks entry/membership; JumpPad uses surface proximity and jump/downward-speed conditions.

ShoveTuning clamps horizontal speed to 8–80, upward to 0–36, duration to .08–.4. The movement guard is at least the kit default and at least hold+0.3; it is an anti-cheat movement allowance, **not invulnerability** and not the cooldown. A temporary server LinearVelocity holds the response; upward handling preserves a stronger existing upward launch. Fan guard=3; JumpPad allows its launch/float envelope (max float+1, default9). Doors/FoamPit/ElimZone/BeachBall have no shove cooldown/guard.

Course response defaults: Rotor 48/20/.24, Bumper54/22/.26; hammer horizontal58, mace54, roller48, sliding wall44. Nominal hold-only distances are 11.52 and 14.04 studs before drift; those are **not measured total shove ranges**. Phase 1 must measure support/material-dependent drift and validate the edge rule. Shared arena values remain untouched.

### Cosmetic tuning ownership

All the following are shared tuning, not per-course attributes today. JumpPadVisuals reads OuterFrequencyHz / OuterDampingRatio (1.7796 / .1342), InnerFrequencyHz / InnerDampingRatio (.3183 / .025), OuterImpulse / InnerImpulse (−2 /−1), MinimumSquash .5. JumpPads uses ParticleBurst50 / ParticleLifetime2 for the launch burst. BumperVisuals reads SquashFrequencyHz3.2, SquashDampingRatio.22, SquashImpulse−8, BeatImpulse−4, MinimumSquash.6, WidenScale.35, plus BeatsPerPulse4 and all Beat* clock/tempo settings: DefaultPeriodSeconds.5, MinPeriodSeconds.3, MaxPeriodSeconds1, LoudnessFloor8, Sensitivity1.35, EnvelopeResponseHz3, OnsetGapSeconds.25, TempoSamples8, TempoAdaptRate.35, PhaseCorrection.12, PhaseWindow.25, LockedScale.25. These cosmetic pulses never change authoritative contact geometry. FanAirflow discovers the same Fan attribute/legacy enabled names; Doors uses shared BrokenSeconds for client fall/fade. Future course impact effects should use the same network-event/cosmetic separation.

### Dead assets and extension boundary

No BigBall, Conveyor, FallingTile or load-driven Seesaw kit exists. Pistons and asymmetric hammer timing need new motion profiles; ordinary sweepers/pendulums/gapped ride platforms should be Rotor compositions after fixing nesting. A static/periodically rocking plank is not rider-weight simulation. Directional fan force and attribute-controlled beach balls are needed for tunnels. Collectibles have no Splashdown pickup system and remain out of scope.

Visual identification corrected two assumptions in the brief: cyan half-pipe cradles are **obstacle_24**, the existing paddle-wheel asset, whereas legacy **SwingPanel is obstacle_8**, a flat square flap. The old author calls obstacle_25 a windmill but its mesh is a narrow yellow-topped plank/pedestal, suitable for a seesaw preset. The blue obstacle_20/21 humps are neither spring buttons nor half-pipes. Keep these separate in coverage tests; see the inventory captures.

Use new attribute selectors/presets where legacy kits are name-only; keep all legacy names, defaults and public behaviour. Tests must distinguish (a) asset/preset counts from (b) actual runtime kit counts, so six differently skinned Rotors do not falsely satisfy six kits.

## 4. Existing course baseline

Scores below are a **source + visual baseline**, not completed geometry graph / loophole / traversal certification. Scale 0–3: 0 clearly fails; 1 substantial faults; 2 partly meets; 3 meets and verified. No old course is awarded 3 without the requested measured checks. Columns S/E/D/B correspond to structure, enclosure, difficulty/pacing, build quality (§5.1–5.4).

| Course | Hazard mechanisms (instances) | Distinct source families | Parts / all descendants | S/E/D/B | Main faults |
|---|---|---:|---:|---|---|
| WhirlPool | dumbbells6, windmills6, paddle wheels2 (14 spin); Bumper4; Fan2; beach balls4 | 19 | 297 /313 | 0/0/0/1 | Broad mostly level spine, repeated rotor rows, scattered balls and side bumpers; only four runtime kits. Several long empty transitions |
| DiscJockey | pizza platforms6, small discs11, medium discs4 (21 Origin-rotation assemblies); JumpPad2 | 12 | 387 /447 | 0/1/0/1 | Eleven same-family discs in a line, ride mechanic dominates; minimal elevation until pad finish; per-pad launch ignored; only two mechanism families |
| KnockKnock | Door20 in4×5; slide walls6; rocking flaps3 | 18 | 758 /774 | 0/1/0/1 | Four repeated door rows before another repeated gauntlet; wide shoulders/endcap jumpability still unproved; few families; doors dominate count |
| BumperBay | Bumper9; beach balls4; hammer rock4; roller spin2; arched bridge rock2 | 19 | 317 /334 | 1/0/0/0 | Four consecutive hammers, bumper placements against nominal flat support on curved ramps; screenshot11 floating/avoidable pattern; only three runtime kits |
| SummitSplash | windmill spin8; mace rock9; Bumper16; rising liquid1 (course mechanism) | 15 | 258 /275 | 2/1/1/1 | Strong readable rising route/palette/climax. Bumpers near shoulders can be skipped, repeated two-kit vocabulary, gentle/unverified sweeps; nominal walls can be jumped with measured movement |
| TiltTrip | rocking rafts7; pendulums5 (12 rock); Bumper19 | 12 | 453 /469 | 0/0/0/1 | Two main families, bumper-heavy count, five repeated pendulums; vertical carry deficiency; previous navigation failure is not a completed playtest |
| CrossCurrent | Recipe only: slide walls10, dumbbells6, pendulums6, windmills2, Bumper6 | Not measured | **Missing** | 1/0/0/1* | Crossing elevations improve structure but two very long straight corridors, repeated walls/pendulums; historical image only; no current model to certify |
| Downpour | windmills6, paddle wheels6 (12 spin); Bumper6; pendulum1; static slide assets | 15 | 521 /537 | 1/0/0/1 | Descending perimeter then slide, but long repeated encounters and avoidable side bumpers; two runtime kits; no measured hazard coverage/pace |

*CrossCurrent score applies to the recipe/history, not the absent model. Part counts include invisible markers/liquid/boundary; descendants include folders/models. Hazard counts count active roots/assemblies, not every arm, chain link, door decoration or fan blade. Exact source-family names are in inventory.json and the inventory's usage column. Counts differ from older gallery documents; do not mix revisions.

All seven parked models have 30 start pads, 3 checkpoints except BumperBay/SummitSplash with4, and maximum corner radius about **539.73 studs** (the large liquid floor dominates). Maximum start-pad distance stays below600. Clone timings on this machine: BumperBay5.84 ms; DiscJockey8.97; Downpour9.56; KnockKnock14.04; SummitSplash5.51; TiltTrip8.17; WhirlPool6.55. These are one-shot **unparented Model:Clone** times, not build, replication, streaming or kit startup timings.

No complete baseline clear-time, hazard hit-rate, graph cut-set, full-width or groundedness result is claimed. Those validators/playtests are Phase 3 deliverables; their absence is visible here.

## 5. Movement calibration

### Inputs and theory

Edit StarterPlayer and actual Play R15 agree: WalkSpeed26; JumpHeight10; CharacterUseJumpPower / UseJumpPower=false; JumpPower50 is inactive. Workspace.Gravity120. Live HipHeight1.60470, root size (2.03554,2.03554,1.01777), MaxSlopeAngle89. No Splashdown-specific jump/speed override was found; generic game movement modifiers and FoamPit can change speed.

For this jump-height mode: launch speed = sqrt(2×120×10)=48.9898; ideal same-height airtime = 2v/g=0.81650 s; nominal flat reach = 26×0.81650+1 =22.2289 studs. These are only predictions.

Correction to the brief's default check: 16/50/196.2 implies airtime0.50968, movement8.1549 (+~1 body ≈9.15), apex50²/(2×196.2)=6.371. JumpHeight7.2 belongs to the alternate JumpHeight default, not that JumpPower calculation.

### Measured protocol and results

[measure-movement.luau](probes/measure-movement.luau) clones the actual spawned avatar, strips cloned scripts, keeps the Humanoid settings, makes its root server-owned, and uses Humanoid:Move / Jump on temporary anchored SmoothPlastic surfaces at Y=2000. Teleports happen **only between trials**. Each speed trial warms up .45 s then samples ~1.55 s. Gap trials run three times. Step trials vary takeoff position; refinement repeats near thresholds. No movement numbers were altered to make a test pass.

| Trial | Measured result |
|---|---:|
| Flat | 25.94 studs/s |
| Uphill15° /30° /45°, along surface | 26.03 /25.96 /22.21 studs/s |
| Downhill15° /30° /45°, along surface | 25.98 /26.04 /26.16 studs/s |
| Belts opposing at13 /15.6 /18.2 | Net forward12.99 /10.39 /7.81 studs/s |
| Belt assisting15.6 | Net forward41.66 studs/s |
| Sideways belt15.6 | Forward25.99, lateral15.59 studs/s |
| Flat gap16 /18 /20 /21 /22 | 3/3 successful for each;22 repeated3/3 in refinement |
| Gap22.25 | 0/3; collisions/edge recovery do not complete the crossing |
| Gap23 /24 | 0/3 |
| Free jump apex on low-gap runs | ~10.102 studs |
| FloorMaterial-reported air interval, gaps16–20 | ~.766 s; this detects contact before root is at its resting height |
| Gap22 air/contact interval | ~.985 s due to ledge recovery, not extra ballistic flight |
| Step8 | All three takeoff positions succeed |
| Step9–11 | −9/−13 takeoffs succeed; −5 is too late;11 repeats3/3 at−11 |
| Step11.375 /11.5, corrected .1 s input pulse | 3/3 successful at each height |
| Step11.75 /12 /12.5 /13, corrected input | 0/3 at each height; all had one recorded jump |

This is a finite-resolution threshold under **one avatar, material and input policy**, not a proof of the global maximum across all avatars/angles/client frame rates. The first refinement cleared Jump after one Heartbeat (~.004 s); some requests were missed (zero apex/jump count). Those failed-input trials are retained but excluded from threshold claims. The probe now holds a single request for .1 s and records exactly one jump in every final trial. Corrected input also changes edge recovery: final step bracket is **11.5–11.75**, superseding the earlier11.375–11.5 bracket. Final gap bracket remains **22–22.25**. Mesh collision, low-friction ramps, client-owned riders, 30-player crowding and assisted launches require their own kit/pilot measurements.

Provisional conservative authoring inputs: **22 stud measured flat-gap reference; intended unassisted gaps13.2–19.8 studs**. Upper unintended-gap warning interval19.8–26.4; report endpoints explicitly. Minimum two-body-width clearance uses the actual avatar width (root≈2.04 is not necessarily the full collidable shoulder width). Use **at least14-stud anti-skip walls**, not12, because measured edge stepping exceeds nominal JumpHeight10. Launch-assisted edges must be audited separately. Rotor tip speed must be ≥1.3×26=33.8 studs/s at the actual player contact radius; degrees/s alone is not a difficulty metric.

## 6. Tooling and reproducibility

Studio MCP is connected to Match Place, studio id `678ffc4f-39f1-48b9-be3e-f2b54a54e984`. Lobby is a separate process; tests/captures used the match process. Rojo-sync source was read alongside live place content.

Commands used from repository root:

~~~powershell
lune run src/scripts/lune/run-tests.luau *> .review/splashdown-discovery/shared-tests.txt
~~~

Result: **960 passed, 0 failed**. The file is an ignored local log; summary is recorded here.

Studio sequence (exact tool/method protocol):

1. `list_roblox_studios({})` / `get_studio_state({studio_id=...})`.
2. Edit `execute_luau` with [inspect-assets.luau](probes/inspect-assets.luau); prefix `local ASSET_FIRST, ASSET_LAST = 1, 8`, then paginate all176. Optional `local COURSE_INDEX=n` retains detailed course attributes.
3. Install [run-contract.server.luau](probes/run-contract.server.luau) as temporary `game.ServerScriptService.SplashdownDiscoveryProbe` via `multi_edit` (class Script), then `start_stop_play({is_start=true,studio_id=...})`. Ordinary server-script context runs the **real TestEZ** module/spec, avoiding the interactive command runner's require-capability restriction without changing security settings.
4. Read `ServerStorage.SplashdownDiscoveryContractResults.Value` via Server execute_luau. As-opened: **0 pass /16 fail**, all missing templates. Temporary Play-only copies of seven LegacyCourses: **14 pass /2 fail**, both CrossCurrent missing. Probe removes only its owned temporary copies. It does not repair active registration.
5. Server `execute_luau` with movement probe. Read `ServerStorage.SplashdownMovementResults.Value`; refinement prefix:
   `local PROBE = {outputName="SplashdownMovementRefinement",skipSpeed=true,gaps={22,22.25,22.5,22.75},heights={11,11.5,12,12.5,13,14},triggers={-11,-11,-11}}`.
6. Final confirmed runs use the same probe with outputName="SplashdownMovementConfirmed", gaps={22,22.25}, heights={11.375,11.5}; then outputName="SplashdownMovementFinal", gaps={22.5,22.75,23}, heights={11.75,12,12.5,13}, skipSpeed=true and triggers={-11,-11,-11}. The .1 s jump pulse is in the checked-in probe. Historical raw files record earlier inputs; do not pool them blindly.
7. Stop Play; remove only the temporary discovery bootstrap. Capture Edit screenshots using `screen_capture({studio_id=...,capture_id="SplashdownKit",camera_position={-4380,105,665},look_at_position={-4490,5,550}})`. Evidence stores JPEG and camera metadata. Seven new parked-course overheads use camera Y650, centred on each stored course pivot; [cameras.json](evidence/cameras.json) records all18 captures.

**Pipeline limitations:** no authored `places/arena/*.rbxl` is checked out; standard `lune run src/scripts/lune/build-place.luau arena <outdir>` requires exactly one. Existing code-only CI artifacts cannot reconstruct the current showcase/map assets. Before repeatable new builds, save/export an approved source snapshot and establish asset manifest/socket metadata. Do not import new assets or overwrite the place casually. Direct Studio edit tools, Play and screenshot capture work. The separate Windows desktop helper is unavailable; Studio has its own character-navigation/keyboard APIs, which will be used/validated for subsequent interactive QA. No “manual course playthrough” is claimed in this discovery.

## 7. Gate 1 issues requiring an explicit decision

1. **Archive policy:** retain all seven parked models and the CrossCurrent recipe; recommend preserve as Deprecated, disable old IDs only when new templates are validated. No deletions. Current empty active folder must be repaired as part of approved build staging.
2. **Shared values:** no existing MapFeatures values changed. Request additive attributes/config sections and narrowly tested bugs (LaunchSpeed, nested transform/carry, Door validation, name-free balls). Keep arena defaults and legacy name routes.
3. **Server authority:** new hazards/riders/balls must be server-authoritative. Existing PlatformRider is client carry, and beach-ball ownership is automatic. Introduce an opt-in course authority path with regression tests, not a silent arena rewrite.
4. **Permanent falling tiles versus checkpoint respawn:** recommend positive respawn times for all race-critical tiles. A never-respawn final bridge needs a viable recovery route or a rule change; the latter is outside scope.
5. **Four/five consecutive Big Balls versus same-hazard cap3:** recommend three differently timed balls for the pilot (or two clusters separated by a genuinely different encounter), not silently exempting the headline.
6. **Literal “cannot jump over” versus intended sweeper jumps:** distinguish crossing the intended hazard gate with a timed jump (allowed) from skipping the gate/beat (fail). Otherwise two brief rules contradict.
7. **Walkability graph:** static top-face samples alone cannot prove periodic motion, launches, doors or falling tiles. Use static reachability + phase/time-aware transition edges and separate assisted-flight tests; gate cut sets must include all legal movement modes. State sampling resolution and limitations.
8. **Course hierarchy:** preserve lifecycle-required folders and direct Door index while retaining numbered beat ownership in specs/metadata; agree an adapter rather than changing round flow.
9. **Timing:** 60–90 s is a target, not a value to set in ParSeconds and call verified. Define repeatable novice/mid/expert input policies and obtain interactive runs. Expert ≤60% of each measured mid-policy median. Gate3 calibrates this before the other five.
10. **Kit counting:** report runtime modules and mechanical presets separately; require six actual participating kits per new course. Big Balls exclusive to pilot; rising liquid only Summit and Piston Peak.
11. **Asset ambiguities / source snapshot:** inventory flags unresolved decorative mappings and missing exact “third Disc size”; request permission to use uniform scale variants of verified discs, not invent a mesh.
12. **Footprint:** all course corners≤600; any ball home and complete intended travel envelope≤420 relative to MapOrigin (3D). Invisible liquid/boundary and tall dressing count too.

See [Gate 1 proposal](gate-1-plan.md) for the proposed kit sequence, six courses and requested approvals. **Implementation is paused at Gate 1.**
