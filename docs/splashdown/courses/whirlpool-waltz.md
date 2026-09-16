# Whirlpool Waltz

Status: **BUILT AND STATICALLY AUDITED — not certified.** Written before the build as HANDOFF
section 7 requires, then updated in place with measured results. Every figure below is marked
either as a design input or as a measurement with the file it came from. Nothing is a measured
claim unless it says so.

- Spec: `src/shared/Game/Splashdown/CourseSpecs/WhirlpoolWaltz.luau`
- Measured build evidence: `docs/splashdown/evidence/courses/WhirlpoolWaltz/build.json`. Its route,
  beat, gap and bounds figures are the ones quoted throughout this document, and its `specHash`
  agrees with `qa.json`.
- Measured audit evidence: `docs/splashdown/evidence/courses/WhirlpoolWaltz/qa.json`
- Measured scripted trials: `docs/splashdown/evidence/courses/WhirlpoolWaltz/routes.json`
- Measured source geometry: `docs/splashdown/evidence/course-sockets-whirlpoolwaltz.json`

## Concept and headline

A descending waltz around a whirlpool. The route spirals clockwise and inward over open water, and
the floor is deliberately not continuous: the racer steps between tangent slabs and rotating ride
decks with real gaps between them, so the pressure is footing and timing rather than a gauntlet of
shoves. **Headline: descending ride platforms with real gaps.** There is no rising liquid here
(that is Piston Peak's headline, HANDOFF 7.6) and no Big Ball (Ball Barrage's).

The climax is `05_DiscDive`, the second-to-last beat: three discs of three different diameters
alternating with two jump pads, over the tightest part of the spiral. `06_HubHurry` is the short,
readable finish HANDOFF 8.4 asks for — one cross spinner on the widest lane in the course, then
the hub.

Palette (HANDOFF section 7 override 1): base cyan `#27C8E8`, accent cream `#FFF0CA`. Walkable tops
keep the kit's blue. Pads are `trampoline_3` (striped).

**Palette and dressing are declared here but NOT applied by the builder.** `CoursePresets`
contains no recolouring or dressing code, so Ball Barrage shipped in the kit's own source colours
and this course does too. That is a known set-wide gap carried from the pilot, recorded honestly
rather than claimed as done; see HANDOFF section 1.

## Layout and guide

Layout kind: **Spiral** (HANDOFF 5.2, one layout kind per course).

The section 5.2 guide for this course is "clockwise descending, angle 180 -> 660 degrees, radius
190 -> 65 linearly, Y 36 -> 0 linearly, then a radial finish to the hub". The shape is used
exactly: 480 degrees of sweep (1.333 turns), a radius ratio of 2.92:1, descending, with a radial
run inward to the hub at the end.

**The radii are scaled to 149.2 -> 51.04.** The stated 190 -> 65 curve measures about 1,141 studs
of arclength including its radial finish, while the set-wide route-length target fixed from the
pilot's measured pace is 880 measured studs (`docs/splashdown/03-overrides.md`). A guide a third
longer than its route would end the course at radius 88 instead of on the hub, contradicting 7.2's
"finish on the hub". Scaling the radii uniformly keeps every stated property of the shape — sweep,
ratio, sense, descent, radial finish — and is exactly the proportional scaling override 4 calls
for. The sweep is NOT shortened, because the number of turns is what makes a spiral read as a
whirlpool.

| Guide property | Value | Source |
|---|---|---|
| Kind | Spiral, clockwise descending, inward | design (5.2) |
| Angle | 180 deg -> 660 deg (480 deg of sweep) | design (5.2) |
| Radius | 149.2 -> 51.04, linear in angle (ratio 2.9232; the stated 190:65 is 2.9231) | design, scaled |
| Radial finish | from radius 51.04 inward to the hub centre | design (5.2) |
| **Guide arclength** | **896.04 studs** | measured, `build.json` |
| **Route arclength consumed** | **884.78 studs**, leaving the finish about 11 studs from the hub centre, inside its 34-stud plaza | measured, `build.json` |
| **Worst route-to-guide deviation** | **7.07 studs** against a 12-stud tolerance | measured, `build.json` |
| Radial pitch between successive turns | 73.62 studs | design |
| Y profile | 36 at the start plaza to 0 on the hub, produced by ramps and one slide, never by floating slabs | design (7.2) |
| Liquid | Y -20, a single plane under the whole spiral | design |
| BoundsRadius | 300 (mandatory); **measured worst route radius 151.70** | measured, `build.json` |

A point on the guide is `(R cos t, 0, R sin t)` in course-local X/Z. Travelling with t increasing,
the inward (hub-side) direction is the route's **right**, so a positive `OffsetSide` points at the
hub and a negative one points outboard. Wide features are placed outboard.

### How a spiral is built without illegal seams

A straight slab cannot follow a curve. Chaining slabs nose-to-tail while turning would open a wedge
at every joint: on this guide a 26-stud slab turns about 10 degrees, which is roughly a 1.8-stud
notch on the outer edge and the same depth of interpenetration on the inner edge. HANDOFF 8.3
allows at most 0.1 studs of either.

So the builder never turns at a joint. On a Spiral layout:

- **Chain pieces keep the cursor's heading**, so consecutive slabs are exactly collinear and their
  sockets meet flush, with zero wedge.
- **Every heading change happens at an `Advance` (a declared gap) or across a round deck.** An
  `Advance` re-anchors the cursor onto the guide at the new arclength and takes the guide's tangent
  there; the builder then measures the real straight-line gap that produced and fails the build if
  it exceeds the 19.8-stud ordinary-jump ceiling. A round deck — a `Ride` platform, or the static
  `RoundLanding` at the hub corner — has no preferred heading, so a heading change across it costs
  no seam at all: the cursor enters at the rim, the deck's axis sits one measured radius along the
  guide, and the cursor leaves at the opposite rim on the new tangent.
- After every chained piece the builder measures how far the route has drifted from the parametric
  guide and **fails the build past `GuideTolerance` (12 studs)**. A collinear run is a chord of the
  arc it approximates, so a bounded drift is expected; an unbounded one would mean the course had
  stopped being a spiral. It caps a collinear run at about `sqrt(2 * radius * 12)` studs, which is
  why every beat below breaks its runs with declared gaps, including across beat boundaries.

**The guide has one sharp corner and the route does not cross it with a slab.** Where the spiral
meets its radial finish, the spiral's tangent at radius 51 is still mostly circumferential while
the radial run turns straight in: a measured 77-degree corner. A slab across it drifted 12.6 studs
off the guide, and a declared 14-stud gap across it measured only 11.4 studs, because the corner
folds the two anchors together — both outside their allowed bands. `Corner01`, a static
`water_platform_001` round deck at scale 0.45, absorbs the turn instead, and both neighbouring gaps
measure inside the ordinary band.

## Beats

Length targets are the section 7.2 targets, **unchanged**. The pilot produced 881.05 measured studs
from 800 studs of beat targets, and the set-wide target fixed from its measured pace is 880
measured studs, so the scale factor is 880/881.05 = 0.9988 and the targets stay as section 7 wrote
them (`docs/splashdown/03-overrides.md`). Elevation is the section 7.2 Y column exactly.

Each beat after the first opens with a checkpoint pad on stable static support before its first
hazard, and a QA gate volume at its entrance. Measured arclengths and elevation changes are from
`build.json`.

| Beat | Family / mechanic | Target | **Measured arc** | **Ratio** | **Measured dY** | Primary encounters |
|---|---|---|---|---|---|---|
| 01_ArchDrop | ClimbDescend / arched descent | 120 | 125.61 | 1.047 | -6.0 | 1 two-arm cross at the enclosed landing mouth; 1 forced cube+triangle chicane; 1 foam side basin |
| 02_WedgeWake | Ride / missing-wedge platforms | 180 | 198.65 | 1.104 | -6.0 | 2 pizzas, opposite rotation and distinct entry phases; 1 carousel |
| 03_DoorDock | Crowd / door choke | 90 | 97.54 | 1.084 | -4.0 | 1 row of 3 doors, quota 1 |
| 04_SpinSpan | Timing / dumbbell bridges | 150 | 159.77 | 1.065 | -6.0 | 2 dumbbells, opposite spin; 1 SwingPanel after a height-changing transition |
| 05_DiscDive | Precision / disc landing chain | 180 | 196.72 | 1.093 | -10.0 | 3 discs, three diameters, alternating with 2 pads; 1 forced triangular bumper at the approach |
| 06_HubHurry | Timing / one readable sweep | 80 | 82.50 | 1.031 | -4.0 | 1 cross spinner at the hub approach, easiest window; finish on the hub |

Every beat sits inside the 0.85-1.15 band. Elevation sums to exactly -36, from Y 36 at the start
plaza to Y 0 on the hub, matching the section 7.2 Y column beat for beat.

### Piece detail

Travel figures are the measured socket arclength each piece contributes; ramp and slide scales are
derived from their measured geometry (`box_011` travels 138*s and drops 28.5*s; `slide_001` drops
51.8*s over 25*s of travel).

**01_ArchDrop.** Floor01 `platform_001` 0.22 (22.0 wide, 19.36 travel) / Gap01 14 / Ramp01
`box_011` 0.2105 (descends 6, 29.05) / ArchMouthL+R `arch_003` 0.6 as Props at side +-10 / Gap02 14
/ Floor02 `platform_002` 0.22 / TwoArm01 `obstacle_27_001` 0.5 at -10 along / Gap03 14 / Floor03
`platform_003` 0.18 / Bumper01 `obstacle_18_001` 0.5 at -12 along, -4 side / Bumper02
`obstacle_19_001` 0.5 at -5 along, +4 side (one `Chicane01` encounter) / Foam01 authored 24x10x20
volume at -9 along, -15 side, outboard.

**02_WedgeWake.** Ramp02 `box_011` 0.2105 (descends 6) / Gap04 14 / Pizza01 `obstacle_16_001` 0.4
(usable radius 33.0*0.4 = 13.2, travel 26.4) / Gap05 14 / Floor04 `platform_001` 0.15 / Gap06 14 /
Carousel01 `obstacle_13_001` 0.4 (radius 25.5*0.4 = 10.2, travel 20.4) / Gap07 14 / Pizza02
`obstacle_16_001` 0.4 / Gap08 14 / Floor05 `platform_002` 0.15.

**03_DoorDock.** Ramp03 `box_011` 0.1404 (descends 4) / Gap09 14 / four `Flank` approach tiles at
side +-14.71 and +-29.42 / Floor06 `platform_001` 0.21 (the corridor centre tile) / Door01-03
`door_002`/`003`/`004` at 0.32, DoorRow 1, DoorIndex 1-3, at side -24.05 / 0 / +24.05 / four
`Flank` exit tiles / Floor07 `platform_002` 0.21 / Gap10 14 / Floor08 `platform_003` 0.15.

**04_SpinSpan.** Gap11 14 / Floor09 `platform_001` 0.18 / Dumbbell01 `obstacle_6_001` 0.5 at -8 /
Gap12 14 / Floor10 `platform_002` 0.18 / Dumbbell02 same source, opposite spin / Gap13 14 / Ramp04
`box_011` 0.2105 (descends 6, the height-changing transition) / Gap14 14 / Floor11 `platform_003`
0.18 / SwingPanel01 `obstacle_8_001` 0.5 at -8 / Gap15 14 / Floor12 `platform_001` 0.15.

**05_DiscDive.** Slide01 `slide_001` 0.1931 (descends 10 in 4.83 studs of travel) / Floor13
`platform_001` 0.15 / Bumper03 `obstacle_19_001` 0.5 at -5 / Gap17 14 / Disc01 `obstacle_14_001`
0.5 (radius 19.3*0.5, travel 19.3) / Gap18 14 / Landing01 `water_platform_001` 0.28 / Pad01
`trampoline_3_001` 0.3, LaunchSpeed 51 / Gap19 14 / Disc02 `obstacle_15_001` 0.45 (travel 29.43) /
Gap20 14 / Landing02 `water_platform_001` 0.28 / Pad02 0.3, LaunchSpeed 54 / Gap21 14 / Disc03
`obstacle_26_001` 0.6 (travel 39.24).

**06_HubHurry.** Ramp05 `box_011` 0.1404 (descends 4) / Gap22 14 / Corner01 `water_platform_001`
0.45 as a static `RoundLanding` absorbing the guide's 77-degree corner / Gap23 14 / Floor14
`platform_001` 0.2 (14.0 studs wide, the widest lane in the course) / Cross01 `obstacle_12_001` 0.5
at -8. The finish deck and its 34-stud plaza are then built at the cursor.

### Speeds, all from the section 6 formulas at measured radii

| Piece | Source, scale | Measured contact radius | Speed |
|---|---|---|---|
| TwoArm01 | `obstacle_27_001`, 0.5 | 29.038 * 0.5 = 14.519 | `ceil((33.8*180/(pi*14.519))/5)*5` = **135 deg/s** |
| Cross01 | `obstacle_12_001`, 0.5 | 14.519 | **-135 deg/s** (sign alternates per section 6) |
| Dumbbell01 / 02 | `obstacle_6_001`, 0.5 | 19.177 * 0.5 = 9.589 | **+205 / -205 deg/s** |
| SwingPanel01 | `obstacle_8_001`, 0.5 | n/a (rock) | amplitude 28, period 2.8, phase 0.6 |
| Pizza01 / Carousel01 / Pizza02 | 0.4 each | ride-only | **+45 / +60 / -45 deg/s**, phases 0 / 0.9 / 1.7 |
| Disc01 / 02 / 03 | 0.5 / 0.45 / 0.6 | ride-only | **-60 / +75 / -75 deg/s**, phases 0.4 / 1.2 / 2.0 |

Ride-only decks carry riders and never shove: their hazard is lost support and the plate's real
holes. The three disc scales are section 6's fixed 0.5 / 0.45 / 0.6 on `obstacle_14` / `obstacle_15`
/ `obstacle_26`, which is what produces three genuinely distinct diameters (19.8, 29.9 and 39.9
studs of plate) rather than three copies of one disc.

**The pizza plate is the course's signature.** Its raycast map
(`course-sockets-whirlpoolwaltz.json`: 8,507 hits against 14,581 misses) shows an entire band of
cells through the middle of the plate and a second radial slot returning no hits at all. At scale
0.4 the missing band is about 4 studs wide — a step-over on a plate that is turning underneath the
racer, not a decorative texture.

### Why the door row is scaled 0.32 rather than section 6's initial 0.2

`door_00x` is 75.152 x 45.790 x 6.277. Uniform scale 0.2 gives a slab 9.16 studs tall, and the
measured movement envelope is a 10-stud JumpHeight with an 11.5-stud step, so a 9.16-stud door is
simply jumped. Section 6 requires the over-jump space to be closed with visible stock supported
tunnel/roof geometry, and explicitly permits the alternative: "If stock geometry cannot close the
jump envelope, increase the uniform door/frame scale together; never make a thin invisible
ceiling." There is no measured roof-plus-pillar assembly in `AssetManifest` and inventing one would
mean adding unmeasured sources, so the scale is raised instead. At 0.32 a door is
24.05 x 14.65 x 2.01: 14.65 studs is above the 14-stud anti-jump minimum section 6 sets for wall
pieces, and the scale is uniform, as required.

**Why there is no edge bypass.** Three 24.05-wide doors centred at -24.05 / 0 / +24.05 tile edge to
edge and span -36.07 to +36.07. The corridor floor is five 0.21-scale slabs, 14.71 studs wide each,
spanning -36.78 to +36.78. That leaves 0.71 studs of floor outboard of the outermost door on each
side — less than a third of a character's width — and beyond the floor edge is open water. Walking
around the row means falling in the whirlpool. No invisible wall is used.

**Why the corridor is not a breather.** HANDOFF 8.4 fails any hazard-free, gap-free,
elevation-free 24x24 square on the route. The corridor is wide but shallow: 18.48 studs of approach
and 18.48 studs of exit, with the door row itself between them. No 24x24 square fits on either
side, and any square large enough to span both contains the row, which is a hazard.

**Why a 73.5-stud-wide feature does not collide with the neighbouring turn.** Successive turns of
this spiral are 73.62 studs apart radially, which a 73.5-wide corridor would cross. It does not,
because this beat is in the part of the spiral that has no neighbour: the sweep is 480 degrees, so
a point at angle t only has a radial neighbour when both t and t+360 are inside [180, 660], i.e.
for t in [180, 300] and its partner in [540, 660]. Beat 03 runs from about 326 to 374 degrees, so
its would-be neighbours at t+360 lie past the end of the guide and at t-360 before its start. The
QA lane-envelope check is what proves this, not this paragraph.

## Measured bounds

From `build.json`, all inside their limits:

| Bound | Measured | Limit |
|---|---|---|
| Max part corner distance from Origin | 494.78 | 600 |
| Max geometry centre radius | 150.06 | 380 |
| Max route radius | 151.70 | 300 (BoundsRadius) |
| Static route envelope Y | -18.00 .. 74.00 | -30 .. 90 |
| Whole-model Y (boundary ring and liquid included) | -21.00 .. 285.12 | reported, not banded |
| Violations | 0 | 0 |

## Measured gaps

Every `Advance` on a spiral is a real transition between two walkable edges, because a piece is
placed with its Entry socket at the cursor and leaves at its Exit socket, so the cursor is the
walkable edge. `build.json` records the straight-line distance between consecutive anchors:

**All 23 gaps measure between 13.5 and 19.5 studs**, the band HANDOFF section 9 step 6 authorises
(18 initially, reducible to 13.5, increasable to 19.5). None is in the 19.8-26.4 band 8.3 fails as
an unintended reachable-looking gap. Getting there took one tuning pass: at 13 studs declared,
seven gaps measured 12.84-13.19 and two in beat 06 measured 13.34 and 11.36; raising every declared
advance to 14 and replacing beat 06's corner slab with the `Corner01` round deck brought all 23
inside the band.

## Encounters and variety

Seventeen encounters, counted by primary behaviour per HANDOFF section 7's counting rule
(override 3). Per-instance counts are reported separately in `qa.json` and are never scored.

| Type | Count | Share | Instances |
|---|---|---|---|
| RotatingPlatforms | 6 | 35.3% | Pizza01, Carousel01, Pizza02, Disc01, Disc02, Disc03 |
| RotorBump | 5 | 29.4% | TwoArm01, Dumbbell01, Dumbbell02, SwingPanel01, Cross01 |
| Bumper | 2 | 11.8% | Chicane01 (Bumper01 + Bumper02 as one encounter), Bumper03 |
| JumpPad | 2 | 11.8% | Pad01, Pad02 |
| Door | 1 | 5.9% | DoorRow01 (3 slabs, one breakable) |
| FoamPit | 1 | 5.9% | Foam01 |

Six primary types; largest share 35.3%, under the 40% cap. Five families: ClimbDescend, Ride,
Crowd, Timing, Precision. Six real elevation changes. Longest same-type run is 3 (the three ride
decks in beat 02 and the three RotorBumps in beat 04), the allowed maximum, and each consecutive
pair differs in speed, direction or phase. The `arch_003` frames and the `Corner01` round deck are
`Prop` and `RoundLanding` presets: they carry no kit attributes and are never encounters.

Cross-course rules (override 2), scored by `CourseQA.auditCrossCourse` over both specs that exist:

- Headline exclusivity: this course's headline is RotatingPlatforms; Ball Barrage's climax beat
  (`05_HammerHour`) is dominated by RotorBump, and Ball Barrage's headline (BigBall) appears in no
  beat here.
- Three-course cap on non-glue mechanics: ride platforms appear in one course of the set so far;
  doors in this course and Door Dash (two of six planned).
- No shared beat recipe: no family+mechanic+encounter-recipe triple here matches any of Ball
  Barrage's six.

## The five loophole questions

These are HANDOFF section 11 step 1's five questions, cited rather than re-derived:

1. **Walk-around** — can a racer walk around the encounter at the same level?
2. **Edge-hug** — can a racer hug an edge past the encounter?
3. **Jump-over** — can a racer jump over the encounter?
4. **Launch-past** — can a racer get launched past the encounter?
5. **Wait-out** — can a racer wait it out at zero risk while others pass?

The pass rule is asymmetric: **questions 1-4 must be NO** for every encounter; **question 5 may be
YES**, but only if waiting costs the racer measured time. A timed jump THROUGH the intended gate is
legal; jumping past the beat is not.

The table is filled in from `qa.json` and `routes.json` in the Measured results section below.

## Manual checklist

| Check | Status |
|---|---|
| Built twice with identical SpecHash | **PASS** — `2fbc899c` both times (`build.json`) |
| AttributeAudit zero errors | **PASS** — 0 (`build.json`) |
| Bounds: corners within 600, route radius within 300, route Y within -30..90 | **PASS** (`build.json`) |
| Every beat inside 0.85-1.15 of its length target | **PASS** — 1.031 to 1.104 |
| Route arclength inside the 800-1000 window | **PASS** — 884.78 |
| Route stays on its guide | **PASS** — worst deviation 7.07 of 12 |
| Every spiral gap inside 13.5-19.5 studs | **PASS** — all 23 |
| 30 start pads, 5 ordered checkpoints, one Finish | **PASS** (`qa.json`) |
| Boundary: 24 walls at radius 390 | **PASS** (`qa.json`) |
| DoorRows.resolve passes; DoorRow/DoorIndex unique and contiguous | **PASS** — structure audit reports no error |
| Sampled walkable graph: ordered route from all 30 spawn cells | **PASS** (`qa.json`) |
| Every beat gate proved a true cut set | **PASS** — all six, after the gate and sampling fixes |
| Cross-course rules over every existing spec | **PASS** — all twelve findings |
| No hazard-free 24x24 square on the route | **PASS** — coverage audit reports no error |
| Scripted expert/mid trials | NOT RUN — see Measured results |
| Ride decks: measured transfer window at each rim, at every rotation phase | NOT RUN |
| Launch envelopes from Pad01/Pad02 measured against the neighbouring turn | NOT RUN |
| Blocked fraction >= 0.4 for each spinner crossing | NOT RUN |
| Measured shove travel per hazard and direction | NOT RUN |
| Foam01 detour measured at >= 5 extra seconds versus the direct line | NOT RUN |
| Readability: every hazard visible >= 15 studs before commitment | NOT RUN |
| Deliberate missed-timing contact at every encounter | NOT RUN |
| One interactive keyboard run | NOT RUN |
| Checkpoint recovery after a fall at each beat | NOT RUN |
| Two fixed-camera captures inspected against bad-map-refs 1/9/10/11 | NOT RUN |
| 30-rider load test and Studio local multi-client session | NOT RUN |

## Measured results

### Independent audit — `qa.json`, executed against a real Workspace clone

`CourseQA.check` returns **zero errors and zero non-PASS findings**. Status is **BLOCKED**, which is
correct rather than a failure: nine live-playtest checks remain NOT RUN and the module never reports
PASS while any of them is outstanding.

| Measured | Value |
|---|---|
| SpecHash | `2fbc899c` |
| Sampled surface cells | 14,844, from real downward raycasts on a disposable clone |
| Walkable graph | 12,181 nodes, 383,518 edges |
| Start pads | 30 |
| Ordered checkpoints | 5, matching the model's `CheckpointCount` |
| Boundary walls | 24 |
| Encounters | 17 |
| Cross-course specs scored | 2 (Ball Barrage and this course) |
| Errors / warnings | 0 / 0 |

**Every one of the six beat gates is a proved cut set**: `01_ArchDrop`, `02_WedgeWake`,
`03_DoorDock`, `04_SpinSpan`, `05_DiscDive` and `06_HubHurry` all PASS, meaning no spawn cell
reaches Finish with that gate's nodes and edges removed.

All twelve cross-course findings PASS: headline exclusivity both ways, the three-course cap on each
of the seven non-glue presets in use (BigBall, Conveyor, Door, Fan, Piston, RidePlatform, Sweeper —
one course each so far), and no shared beat recipe.

### The loophole that got here, and the two audit defects it exposed

The first audit run **failed**: `GateCutSet:05_DiscDive`, all 30 spawn cells still reaching Finish
with that gate removed. The audit was extended to trace the actual bypass, which named the illegal
edge: a 22-stud `Jump` from `04_SpinSpan(-11,16,86)` to `05_DiscDive(-33,5,84)`. Two separate
defects let it through, both in the audit rather than in this course:

1. **The QA gate could be passed underneath.** It spanned only 2 studs below the beat entrance, and
   that jump crossed the gate plane about 7 studs below the entrance while falling. Gates now span
   22 studs below the entrance to 38 above.
2. **The edge-versus-gate test sampled a fixed twelve points**, which is 2-stud resolution on a
   22-stud jump. The jump did clip the gate's corner, but over roughly 0.3 studs of travel, between
   samples. Edges are now sampled every 0.5 studs, and `src/shared/Tests/CourseGraph.spec.luau`
   carries a seeded corner-clip fixture the old test provably missed.

**Ball Barrage was re-audited under the stricter gate and still passes all six of its own cut
sets**, so the tightened audit confirmed the pilot rather than contradicting it.

A third change came out of the same failure and is a course change, not an audit one: `Floor13` now
comes **before** `Slide01` in beat 05. With the slide first, its exit sat almost directly beneath the
beat gate, because `slide_001` drops 10 studs in 4.83 studs of forward travel.

### Scripted trials — `routes.json`

NOT RUN for this course. A first attempt ran for roughly half an hour without clearing
`02_WedgeWake` and its Play session ended before a result file was written. The diagnosed cause is
a proxy limitation rather than a course defect, and it is worth recording precisely:

A rider standing still on `Pizza01` was measured standing safely for 1.0 s and then falling —
carried by the plate into one of its real missing wedges. That is the headline mechanic working
exactly as section 7.2 intends. But crossing a 26.4-stud deck takes about 1.0 s at WalkSpeed 26, so
a `Humanoid:MoveTo` proxy walking a straight line meets the sweeping hole about as often as not,
falls, respawns at the previous checkpoint and repeats. A human reads the hole and times the
crossing; the proxy cannot. HANDOFF 8.5 anticipates exactly this — "if proxy results and interactive
experience disagree, obtain a user mid-skill calibration run before approval" — so the interactive
run is the evidence this course still needs, not a softer proxy.

### The five loophole questions

| Encounter | 1 Walk-around | 2 Edge-hug | 3 Jump-over | 4 Launch-past | 5 Wait-out |
|---|---|---|---|---|---|
| TwoArm01 | PASS — `01_ArchDrop` cut set | PASS (same proof) | PASS (same proof) | NOT RUN | NOT RUN |
| Chicane01 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| Foam01 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| Pizza01 | PASS — `02_WedgeWake` cut set | PASS | PASS | NOT RUN | NOT RUN |
| Carousel01 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| Pizza02 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| DoorRow01 | PASS — `03_DoorDock` cut set; the row spans the corridor to within 0.71 studs of each floor edge | PASS | PASS — 14.65-stud slabs clear the measured 11.5-stud step | NOT RUN | NOT RUN |
| Dumbbell01 | PASS — `04_SpinSpan` cut set | PASS | PASS | NOT RUN | NOT RUN |
| Dumbbell02 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| SwingPanel01 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| Bumper03 | PASS — `05_DiscDive` cut set | PASS | PASS | NOT RUN | NOT RUN |
| Disc01 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| Pad01 | PASS (same gate) | PASS | PASS | NOT RUN — this beat's own pads are what question 4 needs measured | NOT RUN |
| Disc02 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| Pad02 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| Disc03 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| Cross01 | PASS — `06_HubHurry` cut set | PASS | PASS | NOT RUN | NOT RUN |

Questions 1-3 are answered together by the beat-gate cut-set proof over the sampled walkable graph:
its edges are `Walk` (adjacent standable cells, which is what a same-level walk-around or an
edge-hugged path must use) and `Jump` (gaps inside the measured 22-stud / 11.5-step envelope), and
both kinds participate in every gate's proof, now at 0.5-stud edge resolution.

**Question 4 is a genuine unfilled gap, not a pass.** `CourseQA.buildGraph` still constructs no
`Launch` edges from Pad01 and Pad02's measured trajectories, so nothing has proven a racer cannot
vault a later gate with them. This is the same gap recorded for Ball Barrage and it needs the same
measured reach-window work.

**Question 5 needs a measured time cost**, which only the trials and the interactive run can give.
