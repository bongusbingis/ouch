# Tumble Tunnels

Course id `TumbleTunnels`. Built from `src/shared/Game/Splashdown/CourseSpecs/TumbleTunnels.luau`
through `CourseBuilder.build`. This document was written before the build, from HANDOFF.md section
7.4, and its measured columns were filled in afterwards from the evidence files it links.

## Concept and headline

**Headline: two real beach balls pushed back at the racers inside a constrained tunnel.** Beach
balls appear in no other course in the set. Everything else in Tumble Tunnels is glue the pilot
already proved — pendulum and spinner RotorBumps, a bumper chicane, jump-free precision boards,
foam and static ramps — posed around one idea: the course is a closed circuit, and its two most
dangerous moments both happen inside a tunnel on the spine that the circuit is built around.

Palette (HANDOFF section 7 override 1): base lime `#9BDD51`, accent purple `#8E63DE`. Walkable tops
keep the kit's blue. **Declared, not applied:** as with Ball Barrage, Whirlpool Waltz and Door Dash,
`CourseBuilder` performs no recolouring or dressing yet, so the built course ships in the kit's own
source colours. That is recorded as outstanding in `qa-report.md`, not as done.

Built: spec hash **`d390ff50`**, **163 BaseParts**, **880.45 measured studs** of route against the
880 target, six ordered checkpoints, zero attribute errors, zero route errors, zero bounds
violations, identical hashes across a double build.

## Layout: Loop

HANDOFF 5.2: *"A closed circuit around a central tunnel spine (arch_004 outbound, arch_006 return)
that the route crosses twice. Start and finish sit near each other on the outside of the loop but
are separated by enclosure so the finish is unreachable from the start plaza. Ball paths stay inside
the 380 radius."*

`Layout.Kind = "Loop"` is new in `CourseBuilder` and enforces five invariants, in the same style as
the Chute that Door Dash added:

1. The guide is five segments — **run, cross, run, cross, stub**.
2. Segments 1, 3 and 5 are parallel (3 reversed); segments 2 and 4 are each exactly `LanePitch`.
3. All four turns are the **same handedness** and sum to exactly **±360 degrees**. This is what
   separates a Loop from a Chute: a chute's two turns sum to 180 and double the route back on
   itself, while a loop comes all the way round to its own start.
4. The finish lands between `ClosureMinStuds` and `ClosureMaxStuds` of the start plaza — adjacent on
   the outside of the circuit, but never overlapping it.
5. The two long runs sit within `SpineHalfWidth` of the circuit's own centre line, and the two
   declared spine tunnels are placed one on each long run. That is what "the route crosses the
   spine twice" means in geometry: once outbound through `arch_004`, once returning through
   `arch_006`.

### Reading of "central tunnel spine"

The two long runs sit at `z = -49` and `z = +49`, straddling the map's centre line, 98 studs apart.
Together they are the spine: the whole middle of the course is the two tunnel corridors, and the
circuit wraps around them through the east and west crosses. `arch_004` sits on the outbound
(north) run inside beat 01; `arch_006` sits on the return (south) run inside beat 06.

The two arches are **not collinear**, and that is a measured constraint rather than a choice. With
the set-wide 880-stud route fixed, the two long runs of a closed circuit are each about 280–380
studs; beat 01 has to reach its tunnel inside its first 165 studs and beat 06 inside its last 154,
and solving for the two crossings being at the same offset along the spine drives the lane pitch
below 62 studs — inside the measured launch envelope of beat 05's fan, which the cut-set audit
rejects. The spine is therefore the corridor pair, not a single line of arches.

### Guide

`LanePitch = 98`, `BoundsRadius = 300`, `LiquidY = -20`, `Corner`/`Fill` are `platform_002` at 0.3.

| Vertex | Local X/Z | Segment | Heading | Length |
|---|---|---|---|---|
| V1 | (-88.5, -49) | 1 — outbound run | -90 (+X) | 277 |
| V2 | (188.5, -49) | 2 — east cross | 180 (+Z) | 98 |
| V3 | (188.5, 49) | 3 — return run | 90 (-X) | 377 |
| V4 | (-188.5, 49) | 4 — west cross | 0 (-Z) | 98 |
| V5 | (-188.5, -49) | 5 — finish stub | -90 (+X) | 31 |
| V6 | (-157.5, -49) | | | |

Four right turns, -360 degrees total. Corner vertices fall at route 277, 375, 752 and 850, which
puts one turn in each of beats 02, 03, 06 and 07 — no beat carries two of them and none of them is
an empty breather slab.

Maximum route radius 194.8 studs (limit 300); maximum geometry-centre radius is reported in
`qa.json` (limit 380). Route Y runs 0 to 24 inside the -30..90 band. Race liquid at Y -20.

### Start, finish and the enclosure between them

Start plaza centre `(-88.5, 0, -49)`, heading -90, a 6x5 grid on 6-stud centres (30 pads), circular
plaza radius 26.43. The finish lands at `(-157.77, 12, -49)`, radius 17. Centres are **69.27 studs
apart**, so the nearest walkable edges are **25.84 studs apart** — past the measured 22-stud
maximum jump — and the finish deck is also 12 studs higher than the start plaza.

Distance alone is not what section 5.2 asks for, so six coincident `platform_002` props at scale
0.30 stand in the water between them, stacked from the liquid plane to +31.43. Only the top face is
standable (each slab is covered by the one above, so there is no staircase — the exact failure the
Door Dash roof hit three times), that face is 21 x 27 studs so it cannot hold a 24 x 24 breather
square, and it sits 31.4 studs above the start plaza and 19.4 above the finish deck, both past the
14-stud anti-skip minimum. The cut-set audit is what actually proves the finish is unreachable from
the start: deleting beat 01's gate must disconnect all 30 spawn cells from `Finish`.

## Beats

Beat length targets are the **scaled** section 7.4 targets from `docs/splashdown/03-overrides.md`
(165 / 132 / 121 / 121 / 99 / 154 / 88, summing to 880), not the raw section 7.4 numbers. The route
total includes the 24 studs the start plaza's own exit offset contributes before beat 01 begins.

| Beat | Family / mechanic | Target | Measured | Ratio | Elevation | Primary encounters |
|---|---|---|---|---|---|---|
| 01_BallBore | Crowd / BallTunnel | 165 | 152.95 | 0.927 | +6 | 2 beach balls, 1 horizontal opposing fan at arch_004 |
| 02_TiltMouth | Ride / SeesawExits | 132 | 148.42 | 1.124 | -6 | 2 seesaws, max tilt 18 / 24 |
| 03_ArchAscent | Climb/Descend / ArchRamp | 121 | 132.03 | 1.091 | +12 | ribbed arch-ramp over liquid, 1 single mallet at the crest |
| 04_BumperBend | Precision / ForcedChicane | 121 | 106.49 | 0.880 | -6 | 1 cube+triangle chicane, 1 foam penalty lane |
| 05_AirArch | Launch / FanGate | 99 | 96.43 | 0.974 | +12 | 1 upward fan through arch_005, 1 dumbbell guarding the landing |
| 06_TunnelTug | Timing / ReturnTunnel | 154 | 141.50 | 0.919 | +6 | 1 paddle wheel and 1 swing panel inside arch_006, 1 foam penalty lane |
| 07_ExitSlide | Climb/Descend / ShortDescent | 88 | 78.63 | 0.894 | -12 | stock slide to the arch finish, no hazard |

Measured, from `evidence/courses/TumbleTunnels/build.json`: 152.95 / 148.42 / 132.03 / 106.49 /
96.43 / 141.50 / 78.63, ratios 0.880 to 1.124, elevation changes +6.00 / -6.00 / +12.00 / -6.00 /
+12.00 / +6.00 / -12.00 — section 7.4's profile to two decimal places. The circuit's measured
closure is **69.55 studs** and its measured total turn is exactly **-360 degrees**.

Cumulative elevation 0 / 6 / 0 / 12 / 6 / 18 / 24 / 12, matching section 7.4 exactly. Climax is
beat 06 (the second-to-last); beat 07 carries no encounter at all, which is the short easy sprint
HANDOFF 3.2 asks for.

## Encounters

13 encounters, counted by HANDOFF section 7 override 3 (one thing the runner solves as a unit).

| # | Beat | Encounter | Type | Source / scale | Tuning |
|---|---|---|---|---|---|
| 1 | 01 | Ball01 | BeachBall | ball_001 @ 0.5 | server-owned at runtime, anchored in the template |
| 2 | 01 | Ball02 | BeachBall | ball_001 @ 0.5 | offset to the opposite side of the lane |
| 3 | 01 | Fan01 | Fan | propeller_trampoline_1_001 @ 0.5 | pitched -90, facing back down the tunnel; LaunchSpeed 48, Float 0.2, column 55, FanBallSpeed 32 |
| 4 | 02 | Seesaw01 | Seesaw | obstacle_25_001 @ 0.6 | axis X, MaxTilt 18, response 3 |
| 5 | 02 | Seesaw02 | Seesaw | obstacle_25_001 @ 0.6 | axis X, MaxTilt 24, response 3 |
| 6 | 03 | Mallet01 | RotorBump | obstacle_1_001 @ 0.6 | rock Z, hammer profile, amplitude 55, windup 1.8, strike 0.3, shove 58 |
| 7 | 04 | Chicane01 | Bumper | obstacle_18_001 + obstacle_19_001 @ 0.5 | shove 54 / up 22 / hold 0.26, one encounter group |
| 8 | 04 | Foam01 | FoamPit | authored volume | 112 studs of channel, 0.45 speed |
| 9 | 05 | Fan02 | Fan | propeller_trampoline_1_001 @ 0.5 | upward, LaunchSpeed 48, Float 0.2 |
| 10 | 05 | Dumbbell01 | RotorBump | obstacle_6_001 @ 0.5 | Y-spin 205 deg/s, shove 48 |
| 11 | 06 | PaddleWheel01 | RotorBump | obstacle_24_001 @ 0.5 | X-spin 255 deg/s on the measured axle, shove 48 |
| 12 | 06 | Foam02 | FoamPit | authored volume | 112 studs of channel, 0.45 speed |
| 13 | 06 | SwingPanel01 | RotorBump | obstacle_8_001 @ 0.5 | panel rock X, amplitude 28, period 2.8, phase 1.4, carries and shoves |

Type mix: RotorBump 4 (30.8%), BeachBall 2, Fan 2, Seesaw 2, FoamPit 2, Bumper 1. **Six types, six
families** (Crowd, Ride, Climb/Descend, Precision, Launch, Timing), longest same-type run 2, and
the dominant type is under the 40% cap.

Per-instance counts, reported but never scored: 2 door slabs (none — this course has no doors), 2
bumper meshes, 2 beach balls, 2 seesaw boards, 3 tunnel arches, 6 enclosure props, 12 foam-channel
slabs, 2 foam volumes. `qa.json` carries the authoritative part and controller counts.

### Cross-course rules (override 2)

- **Headline exclusivity.** `Headline = "BeachBall"`. It is dominant only in 01_BallBore, inside its
  own course, and no other course uses a beach ball at all.
- **Three-course cap on non-glue mechanics.** Fan: Ball Barrage + Tumble Tunnels = 2. PaddleWheel:
  Door Dash + Tumble Tunnels = 2. Seesaw: Tumble Tunnels = 1. BeachBall: Tumble Tunnels = 1. All
  inside the cap with headroom for Tiptoe Trials and Piston Peak.
- **No shared beat recipe.** Every beat's family + mechanic + sorted encounter recipe is unique
  across the three staged specs; `auditCrossCourse` re-checks this over the whole staged set on
  every run.

## Measured geometry that the build depends on

All from `docs/splashdown/evidence/course-sockets-tumbletunnels.json`, taken on a disposable clone
parked 12,000 studs above the arena so no other collision geometry could answer a ray.

**The arches** (`arch_004/005/006`, one mesh at three colourways, 57.07 x 40.78 x 89.86). The bore
runs along local Z and is genuinely open in collision. In root-local studs at scale 1: part bottom
-20.3889; end threshold slabs -20.39 to -14.43, present only within about 6 studs of each mouth;
side skirts from |x| 21.17 out to 28.53, rising from the bottom to about -6.4; open bore |x| <= 21.6
at deck level; canopy underside +8.28 at |x| = 14 rising to +12.06 on the centre line. A deck laid
at the threshold therefore gets 43.2 studs of bore, 7.6 studs of solid wall each side — which is
what pens a beach ball — and 22.3 to 26.06 studs of headroom.

**The seesaw** (`obstacle_25_001` + `obstacle_25_002`). 1,767 of 2,525 downward rays returned the
board's top between 17.7227 and 17.8301 in pedestal-local studs, across |x| <= 4.50 and |z| <=
23.00. The pedestal's lowest collision point is -9.3184. At scale 0.6 the board is 5.59 studs wide
and 27.6 studs long, and its top sits 16.22 studs above the pedestal's base.

**The single mallet** (`obstacle_1_001`). The top-surface grid shows a rounded head centred near
x = -5.5 and a striped post between x = +1 and +9 that is thin in Z. Its imported display pivot,
(7.1026, -5.9487, -0.2810), is the post's own base — the only point the mesh can stand on and the
only plausible axle. Head-to-axle distance 12.6 studs at scale 1.

**The beach ball** (`ball_001`, 9.18 x 9.32 x 9.32). The only standalone ball in the kit;
`air_balloon_001` is a basket balloon and is not collision-equivalent.

## Build notes, one beat at a time

**01_BallBore.** A 26.4-stud approach, a +6 ramp, then three 18.22-stud-wide slabs that carry the
route through `arch_004` at scale 0.58 (52.11 studs long, 25.06-stud bore, 4.41 studs of wall,
12.93 to 15.11 studs of headroom). The deck is deliberately narrower than the bore: at 18.22 studs
it cannot hold a 24 x 24 breather square, and the 3.4-stud gap to each skirt is narrower than a
4.66-stud ball, so a ball rolls against the wall instead of through it. Both balls are mounted
inside the tunnel on opposite sides of the lane.

The fan stands just past the tunnel's far mouth on a 22.98-stud deck, laid on its side by
`PitchDegrees = -90` so the visible grate faces back down the tunnel, as 02-kits requires. It is
offset 2.6 studs to one side, which leaves a 5.25-stud passage on the other — past the 4.5-stud
minimum lane width, and the squeeze IS the encounter. It is sunk so its column axis sits 2.4 studs
above the deck rather than 8.85, because the measured column is a cylinder of radius 6.19 studs at
this scale and a ball's centre is only 2.33 studs up: mounted flush, the balls would have sat
outside their own fan's column. `FanColumnHeight` is raised from section 6's seed of 18 to 55 so
the column reaches the length of the tunnel; every other fan attribute is the section 6 seed.

**02_TiltMouth.** Two 3-stud ramps bracket the first board, the first east corner falls between the
two seesaws, and the beat ends on the second board. The boards are chained surfaces, not mounts:
`obstacle_25_001` carries Entry/Exit sockets on its measured walkable top, so the 21-stud lane meets
a 5.59-stud board flush and the narrowing is the hazard rather than an invented gap. Each pedestal
reaches 16.22 studs below its own board, so each one stands on a `platform_002` plinth scaled to
reach exactly from the liquid plane to the pedestal's base (0.2371 and 0.1321).

**03_ArchAscent.** A 26.4-stud run to the second east corner, then `box_011` reversed at 0.42105 —
the kit's only climb — rising 12 studs over 58.1. The mallet stands 4 studs past the crest on the
right-hand side of the lane; its head reaches 7.56 studs, so at rest it blocks the lane's centre
line and the hammer profile lifts it clear for 1.8 seconds before a 0.3-second strike.

**04_BumperBend.** The chicane is the bend: the cube sits 6 studs left and the triangle 6 studs
right and 12 studs further on, so a walking runner cannot hold a straight line past both. The
descent then runs 12 studs down to the lower half of the beat. The foam channel runs the whole beat
beside the lane, 6 studs lower and 14.86 studs wide, in two groups so it steps down with the lane
instead of rising to meet it.

**05_AirArch.** A short deck, a +6 ramp, a launch deck with the fan sunk 12 studs (the pilot's own
mounting, so the grate is flush with the deck), a 14-stud flight rising 6 studs, and a landing deck.
`arch_005` at 0.45 stands entirely on the landing deck with a 19.44-stud bore, and the dumbbell
spins inside it: at 19.18 studs the bar sweeps the arch's full width, so the landing gate really is
guarded rather than merely decorated.

**06_TunnelTug.** `arch_006` at scale 0.98 — 88.05 studs long, a 42.3-stud bore and 25.54 studs of
headroom on its centre line — is sized by what has to live inside it. The paddle wheel at scale 0.5
is 29.91 studs across its axle and stands 24.02 studs above the deck it sweeps; nothing smaller
than a near-full-size arch clears it. The deck through the tunnel stays 23.12 studs wide (under the
breather-square limit) and the bore is wider than the deck, so the tunnel reads as an arch over a
bridge and a shove off the edge is a fall into the liquid. The swing panel is raised 5 studs and
phased at 1.4 so it is posed differently from Whirlpool Waltz's, as override 2 requires. The second
foam channel runs 112 studs from under beat 05's landing deck to the west corner's approach.

**07_ExitSlide.** A 26.4-stud run, `slide_001` at 0.2317 dropping 12 studs, the last corner, and a
20-stud stub to the finish. No hazard, by design.

## Foam penalty, measured

Section 7.4 requires each foam detour to cost **at least 5 extra seconds** against the direct path,
and HANDOFF 13 is explicit that five seconds total is not enough — it has to be five seconds more.

The kit multiplier is 0.45 (`MapFeatures.FoamPit.WalkSpeedScale`, confirmed by the Gate 2 contact
probe in `evidence/kit-contacts.json`: "FoamPit 0.45 then cleared"). At WalkSpeed 26 that is 11.7
studs/s against 26, so every stud of foam costs `1/11.7 - 1/26 = 0.04696` seconds. Both channels are
built at **112.0 studs** of foam-covered centreline, which is why section 7.4 names that number:

| Detour | Foam centreline | Direct | Foam time | Direct time | Extra |
|---|---|---|---|---|---|
| Foam01 (beat 04) | 111.98 studs | 111.98 studs | 9.57 s | 4.31 s | **+5.26 s** |
| Foam02 (beat 06) | 111.98 studs | 111.98 studs | 9.57 s | 4.31 s | **+5.26 s** |

Both channels sit 6 studs below the lane and rejoin it with a 6-stud step up, inside the measured
11.5-stud ledge, so neither is a dead end a racer can be stranded in. Neither skips a gate: both run
alongside the route and inside the beat gate's own 60 x 60 volume. The direct path is strictly
faster, so the channel is a penalty, not a choice.

The figures above are derived from the measured multiplier and the built channel length. The
**live-player timing of a real foam traversal is recorded separately** — see the QA section below
for its status.

## Loophole table

Section 11 step 1's five questions, verbatim, per encounter. The first four must be NO.

| Encounter | walk-around | edge-hug | bypass-jump | launched-past | safe-wait |
|---|---|---|---|---|---|
| Ball01 | NO — the tunnel deck is 18.22 studs wide between two skirts and the balls roll its full width | NO — both edges are open air over the race liquid | NO — the canopy underside is 12.93 studs above the deck at the bore's edges, under a 10-stud jump plus a 5.6-stud body | NO — the only launch in the course is beat 05's fan, 470 studs later on the other run | YES — waiting at the tunnel mouth for a ball to pass costs time and the fan keeps sending them |
| Ball02 | NO — same corridor, the second ball sits on the opposite side so the two cover the lane between them | NO — same | NO — same | NO — same | YES — same, and the two balls are phased by their own physics rather than a timer |
| Fan01 | NO — the cage covers 17.69 of the 22.98-stud deck; the 5.25-stud passage is the only way past | NO — the passage is bounded by the deck edge and open water | NO — the column is 6.19 studs in radius about an axis 2.4 studs above the deck, so a jump stays inside it | NO — no launch reaches this beat | YES — the launch has a 0.75-second retrigger cooldown, so hanging back costs seconds without avoiding it |
| Seesaw01 | NO — the board is the only floor across its 27.6 studs | NO — the board is 5.59 studs wide with liquid on both sides | NO — 27.6 studs is past the measured 22-stud jump | NO — no launch reaches this beat | YES — waiting for the board to level costs time; it returns to level in about 2 seconds empty |
| Seesaw02 | NO — same, after the first corner | NO — same | NO — same | NO — same | YES — same, at max tilt 24 instead of 18 |
| Mallet01 | NO — the head reaches 7.56 studs from a post 8 studs off centre, so at rest it covers the lane's centre line | NO — the crest deck is 21.02 studs wide with liquid either side, and the mallet sweeps across it | NO — the mallet sweeps vertically through the jump envelope, not under it | NO — no launch reaches this beat | YES — the 1.8-second windup is a readable free window that costs 1.8 seconds to take |
| Chicane01 | NO — the cube and the triangle overlap in the lane's cross-section, so no straight line clears both | NO — the free strip at the triangle is 11.5 studs on one side and nothing on the other | NO — a jump over either bumper lands inside the other's footprint | NO — no launch reaches this beat | NO — both bumpers are static; there is no window to wait for |
| Foam01 | NO — it is not an obstacle to avoid; it is the penalty for being shoved off the lane | NO — the channel runs the whole beat, so there is no clean strip beside the lane | NO — the 6-stud drop into it is one-way at walking speed | NO — no launch reaches this beat | NO — waiting in foam only adds to the 5.26-second cost |
| Fan02 | NO — the fan is sunk into a 14.08-stud launch deck with liquid beyond it and a 14-stud gap after | NO — the deck is narrower than the fan's own 6.19-stud column radius | NO — the gap is 14 studs and the landing is 6 studs up; an unlaunched jump falls short | NO — it IS the launch | YES — re-entering the column costs the 0.75-second cooldown each time |
| Dumbbell01 | NO — the 19.18-stud bar sweeps the whole 19.44-stud arch bore | NO — the bore's legs are the lane edges here | NO — the bar spins 2.78 studs above the deck, inside the jump envelope | NO — the landing is the only approach and it is inside the arch | YES — the 205 deg/s spin gives a readable window that costs about a second |
| PaddleWheel01 | NO — the wheel is 29.91 studs across a 23.12-stud deck, overhanging both edges | NO — both deck edges are open air inside the arch | NO — the cradles sweep from deck level to 24.02 studs up | NO — no launch reaches this beat | YES — the 255 deg/s wheel gives four windows per revolution, each costing time to wait for |
| Foam02 | NO — same as Foam01, on the return run | NO — same | NO — same | NO — the beat 05 launch lands 100+ studs earlier and cannot reach it | NO — same |
| SwingPanel01 | NO — the panel is 19.63 studs across a 23.12-stud deck | NO — the 1.7 studs left at each edge is under the 4-stud avatar width | NO — the panel rocks through the jump envelope at amplitude 28 | NO — no launch reaches this beat | YES — the 2.8-second period gives a readable window |
| Start-to-finish enclosure | NO — the gap between the two plaza edges is 25.84 studs of open water | NO — the plazas are circular; every line between them crosses the gap | NO — 25.84 studs is past the measured 22-stud maximum, and the finish deck is 12 studs higher | NO — there is no launch on the start plaza | n/a — this is not an encounter; it is the wall the cut-set audit has to prove |

Four "safe-wait YES" rows are periodic hazards where waiting is legal and costs measured time, which
HANDOFF 8.2.9 permits. None of them is a permanent bypass lane.

## Top-down schematic

Generated from the spec's guide and beat boundaries. Route runs clockwise from S.

~~~text
                 z = -49  (outbound run, arch_004 on it)
   x=-188.5                x=-88.5            x=+41                      x=+188.5
      +-----[stub 5]--------S===============[01 arch_004]=========>----------+
      |  F<--[07]--+        |                                                |
      |            ^        v 02 seesaws                                     | 02
   [06]            |  (enclosure stack in the water between S and F)         v
   west            |                                                       east
   cross           |                                                       cross
      |            |                                                        |
      +-----<======[06 arch_006]==[06/05]==[04 chicane+foam]==[03 ramp]<----+
                 z = +49  (return run, arch_006 on it)
~~~

`S` start plaza (Y 0), `F` finish deck (Y 12), 69.27 studs apart with the enclosure stack between
them. The two horizontal runs are the spine; the circuit wraps around them.

## Automated QA — measured

`CourseQA.check` over a real Workspace clone, run both from the Edit Command Bar and again inside a
Studio Play session by `run-course-qa.server.luau`: **zero errors, zero warnings, 43 findings PASS,
0 FAIL, and the 9 NOT RUN items that keep every course at BLOCKED.** Studio TestEZ over
`SplashdownQA.spec`: **16 passed, 0 failed, 0 skipped.**

- **Cut sets.** All seven beat gates are true cut sets: **0 of 30 spawn cells bypass any of them**,
  over a 20,739-node / 789,860-edge graph sampled from 28,807 real surface cells. The ordered route
  from all 30 spawn cells through all 6 checkpoints to Finish is proved with 0 failing legs.
- **Breather square.** Largest flat hazard-free square on the route is **21 x 21** (limit 24). That
  is the widest in the set so far — Door Dash's was 16 — and it comes from the return tunnel's
  23.12-stud deck, which is sized by the paddle wheel inside it.
- **Bounds.** Worst part corner 494.78 of 600; geometry centres 194.76 of 380; route radius 192.45
  of 300; static route envelope -22.00..62.00 inside the -30..90 band.
- **Variety.** 13 encounters, 6 types, 6 families, dominant type 30.8%, longest same-type run 2.
- **Cross-course.** All 12 findings PASS over the four staged specs.
- **Beach balls.** The engine test drives the real `BeachBalls` kit over the built model and asserts
  what the kit ends up owning: both balls are authored anchored with no motion owner, sit as
  BaseParts under `Rotating/<group>/Assembly` where the kit actually scans, and after one
  `tickWorld` are unanchored, colliding, server-owned (`GetNetworkOwner() == nil` with
  `Anchored == false`) and reparented into `Scriptables/BeachBalls`. This is deliberately a kit-level
  test rather than a preview screenshot: the door-slab defect that cost the Door Dash build a rebuild
  was invisible to both the build and the audit.

### The bypass the audit caught

The first build put a stack of six coincident `platform_002` props between the start plaza and the
finish. The audit rejected it outright: a platform's top is a broad bevelled face, so every slab left
a standable rim proud of the one above, and the graph found a 21-stud hop from the start plaza onto
the third rim and a second hop from there straight onto the finish deck — **30 of 30 spawn cells
bypassing all seven gates**. Two thinner door panels failed the same way. The shipped enclosure is a
single door panel at uniform scale 1.2, 90.2 studs across and 54.9 tall, with no intermediate top at
all; every gate then passed with 0 of 30. This is the third time in this project that stacked stock
geometry has quietly become a staircase, and the lesson is the same each time: **check the cut sets,
never the screenshot.**

## Fixed cameras, compared against the bad references

`evidence/course-cameras.json` records both poses. The preview was lifted 9,000 studs so the arena's
own hazard ring could not fill the frame; `workspace.Assets.Arena.Map.Model` was never moved and is
still at its recorded pivot.

Compared explicitly against the four named references, all four opened:

- **1.png** (a flat magenta field with decorative discs sprinkled across it and empty blue slabs each
  carrying one tiny spinner): Tumble Tunnels has no field at all. Every walkable surface is a lane
  between 5.6 and 23.1 studs wide with race liquid on both sides, and each of its 13 encounters sits
  on the lane rather than beside it.
- **9.png** (five identical swing-panel pairs in a row, with a clear walkable strip beside them):
  Tumble Tunnels has one swing panel, posed differently from Whirlpool Waltz's, and no strip beside
  any lane to walk on.
- **10.png** (a huge flat plaza with a handful of sparse hazards): the only unrestricted plazas are
  the start and finish, which 5.1.9 exempts, and the audit's largest flat square elsewhere is 21.
- **11.png** (empty ramps and floating single bumpers over acres of floor): every ramp here carries
  the route between two beats at a measured elevation change, and both bumpers are in one forced
  chicane whose footprints overlap in the lane's cross-section.

Honest weakness in the same frames: the return tunnel's deck and the lower half of `04_BumperBend`
are plain lane for 25 to 30 studs at a stretch. They are inside every limit, but they are the
emptiest geometry in the course and are the first thing to look at if the interactive run reads as
sparse.

## Automated QA

Raw evidence:

- `docs/splashdown/evidence/courses/TumbleTunnels/build.json` — the full `BuildReport`.
- `docs/splashdown/evidence/courses/TumbleTunnels/qa.json` — the full `CourseQA.check` report.
- `docs/splashdown/evidence/courses/TumbleTunnels/routes.json` — scripted trial record.
- `docs/splashdown/evidence/course-sockets-tumbletunnels.json` — the source measurements above.
- `docs/splashdown/evidence/courses/TumbleTunnels/top-down.png`, `three-quarter.png` — fixed cameras.

See `docs/splashdown/qa-report.md` for the per-course acceptance matrix and the status of every
check, including everything still NOT RUN.

## Scripted trials — NOT COMPLETED

`run-course-routes.server.luau` was pointed at `TumbleTunnels` and run in a Studio Play session. It
published its deterministic double build to `build.json` and then **did not terminate**: over a
continuous 3.5-hour window it never wrote `ServerStorage.SplashdownCourseRouteResults`, although its
own per-run ceiling is 150 seconds and it runs 8 trials, which should bound the whole pass at about
25 minutes. The rig was sampled repeatedly during that window and was always alive and walking under
`Humanoid:MoveTo` — observed on the outbound run, at the east cross and back at the start plaza
across successive resets — so the harness was working, not hung on the course. The most likely cost
is `buildRig`'s per-run `CreateHumanoidModelFromDescription`, which is an async web call the harness
makes once per trial and does not time out.

**No trial numbers are claimed.** This is recorded as NOT COMPLETED rather than as a pass or a
failure, and `qa-report.md` carries the same row. It does not change what the course still needs
either way: HANDOFF 8.5's interactive keyboard run, the deliberate missed-timing contacts and a user
mid-skill calibration run are outstanding for this course exactly as they are for Whirlpool Waltz
and Door Dash, whose scripted trials did complete and failed 0 of 8.

Per the user's standing decision (2026-09-16) this category of blocker is not chased further in the
build session; it is reported plainly and the next course proceeds.

## Manual checklist

- [ ] Both tunnels read as tunnels from 15 studs out, and the beach balls are visible before the
      first one is in range.
- [ ] The horizontal fan's grate visibly faces back down the tunnel.
- [ ] Both seesaw boards visibly tilt under a single rider and return level when empty.
- [ ] The mallet's windup is readable from the bottom of the arch ramp.
- [ ] Falling off either lane lands in the race liquid or in a foam channel, never on a hidden ledge.
- [ ] The finish is visible from the start plaza but provably unreachable from it.
