# Door Dash

Course ID `DoorDash`, display name DOOR DASH. Built from
`src/shared/Game/Splashdown/CourseSpecs/DoorDash.luau` by `CourseBuilder.build`; nothing in the
model is hand-placed.

| Item | Value |
|---|---|
| Layout kind | Chute (HANDOFF 5.2) — new in this build; Serpentine and Spiral already existed |
| Spec hash | **`8c00a748`**, identical across a double build (`80d817fc` pre-roof, then `77f14b71`, `29b28b88`, `57c87e64` through the roof and door-fit work) |
| Source hash | `e9e69d1defddda53ba439cf78660d1b668c489913c309b771cda7fcb7d9f7eec` (AssetManifest version 3) |
| BaseParts | **221** (201 before the door-section roof below) |
| Measured route arclength | **882.07 studs** against the set-wide 880 target (+0.23%) |
| Checkpoints | 5 ordered, one at each beat entrance after beat 1 |
| Par / Cap / Close | 75 / 180 / 60 seconds (section 3.1's fixed values for a new course) |
| Doors | `PerRow = 5`, `BreakablePerRow = 2` for the whole course (section 6) |
| Difficulty | 3 |
| Status | **BLOCKED** — every static check passes; the live-playtest checks below are the outstanding ones |

Evidence: `docs/splashdown/evidence/courses/DoorDash/qa.json`,
`docs/splashdown/evidence/courses/DoorDash/routes.json`,
`docs/splashdown/evidence/course-sockets-doordash.json`.

## Fix (2026-09-16) — HammerLarge was inert, exactly as Ball Barrage's two were

Found by the swept-reach regression added while fixing Ball Barrage, and measured on the promoted
`8c00a748` template rather than inferred. `obstacle_3_001` is an axle housing with its head
suspended a measured **8.925 studs beneath it** at scale 0.6, so the `OffsetUp`-0 mounting put the
head at **Y 5.694..24.456 under a deck at Y 23.997** — only the top **0.46 studs** of an 18.76-stud
head ever reached deck level, and its full ±55° swing lifted that to just 1.97 studs. Nothing a
runner's body occupies was ever in the head's path, and neither the build, the bounds audit, the
walkable graph nor the cut sets noticed: the hazard's attributes, motion profile and kit
registration were all correct.

`OffsetUp` is now `8.925 + hypot(11.115/2, 18.761/2) + 0.6 = 20.428` — the hang distance, plus the
head's maximum swept vertical half-extent (the head rocks about its OWN centre, so that maximum is
`hypot(halfX, halfY)` at 30.7°, not `halfY`), plus 0.6 studs of deck clearance. Measured after the
rebuild: the head spans **Y 26.122..44.883 at rest** and sweeps **24.600..46.406**, i.e. deck
**+0.600..+22.406**, with **±5.558 studs of lane at rest and ±10.872 at full swing** across an
18.22-stud slab, so it seals the lane on the strike and leaves 3.55 studs of corridor on each side
between strikes. HANDOFF 8.3's suspended-pendulum exemption covers the housing, which is the same
rule this course's two maces already use at `OffsetUp` 21.

## Concept and headline

Thirty racers leave a 48-stud plaza through a single 15-stud slab and fan out into a five-channel
corridor, where three rows of five doors each hide two that give. Nobody can see which. The corridor
then tapers back to one lane, drops down a slide, crosses three counterbelts under a paddle wheel,
launches over a foam gutter through the hairpin, and walks a narrowing mace gauntlet to one readable
finishing sweep.

Headline (declared in the spec, scored by `CourseQA.auditCrossCourse`): **Door**. Section 7.3 states
it as "three Door Dash rows, not fifteen identical straight-line gates", and the three rows are
posed differently from each other — square, yawed +15 degrees, yawed -15 degrees, at 26 and 34 studs
of spacing — and from Whirlpool Waltz's single 3-door row at quota 1.

Palette (HANDOFF section 7 override 1): base yellow `#FFD64A`, accent orange `#FF9E43`. **Palette and
dressing are declared here but NOT applied by the builder**, exactly as for Ball Barrage and
Whirlpool Waltz: `CoursePresets` clones the source meshes unrecoloured and places no flags, pennants
or inflatables. This is a known, recorded gap for the whole set (`qa-report.md`), not a Door Dash
omission.

## Layout and guide

| Guide property | Value | Source |
|---|---|---|
| Kind | Chute: run, hairpin, run | design (5.2) |
| First run | local (-241.175, 56) to (241.175, 56), 482.35 studs | design |
| Cross segment | (241.175, 56) to (241.175, -42), **98 studs = `LanePitch`** | design |
| Second run | (241.175, -42) back toward (-241.175, -42); the route consumes 301.7 of it | design |
| **Measured route arclength** | **882.07 studs** | measured, `qa.json` `buildSummary` |
| **Hairpin position** | enters the turn at **53.19%**, reverses at **60.09%**, rejoins at **66.98%** | measured, build report |
| Run-to-pitch ratio | 4.92 (both runs), against the declared minimum of 2 | measured, build report |
| Y profile | 18 at the start plaza; 18 → 6 → 12 → 24 → 24 → 18 by beat | measured, build report |
| Liquid | Y -20, one plane under the whole course | design |
| BoundsRadius | 300 (mandatory); **measured worst route radius 245.43** | measured, `qa.json` |

The builder rejects a Chute guide that is not three segments, whose second run does not double back
on the first, whose cross segment is not exactly `LanePitch`, whose runs are shorter than twice the
pitch, or whose hairpin turns outside the declared 55–62% window. Those five assertions are what
make "Chute" a layout kind rather than a relabelled Serpentine.

### Where section 5.2 and section 7.3 disagree, and which one wins

5.2 describes the Chute as "descending overall". Section 7.3's elevation column is 0, -12, +6, +12,
-6 then +6, -6, which nets to **zero** from `StartY 18`: the course finishes at the height it
started. Section 7.3's explicit per-beat numbers are the ones this build follows, and the measured
dY column below matches them exactly. The descent 5.2 is describing is real but local — the chute
proper is beats 01 and 02, which fall 12 studs through the slide into the lowest point of the
course — and the hairpin then climbs back out. This is recorded as a deviation from 5.2's prose,
not hidden inside it.

### Why the corridor is five crowned channels

Five doors abreast is 98.1 studs of wall, so the corridor under it is wide by construction. A single flat slab that wide fails section 8.4's 24x24
breather-square test on its own, whatever hazards stand on it. Two ways out were measured: cutting
the corridor into five decks with water slots between them, and crowning it. The crown won —
channels are 19.62 studs wide at 0 / -1 / -2 studs from the centre outward, so the widest level
surface anywhere in the corridor is one channel, and no 24-stud square fits — because slots would
add a fall hazard to the exact place where thirty racers are shoulder to shoulder, and the crown
adds none. With the corridor crowned and before the roof below existed, the measured largest flat
square anywhere on the route was **16 x 16** (`qa.json`).

Each door's sill drops to the lowest channel its slab covers, so nothing opens underneath it.

### One door per channel

The first build scaled the doors independently of the floor, at 24.05 studs against 19.62-stud
channels, so a row of five overhung the corridor by 11 studs a side. That looked harmless until a
scripted trial walked through the OUTERMOST door and fell: half of that opening was over open water.
Each slab is now scaled so one door is exactly one channel wide (19.62 x 11.95 x 1.64 at 0.261), and
the row spans the corridor exactly — measured z 6.95 to 105.05 for both. Every sill sits on its own
channel at that channel's height, so no door bridges a step and no opening leads off the deck.

### The door tops were climbable, and what closed it

The first build reasoned that a 14.65-stud slab cannot be climbed, because the movement evidence
says an 11.5-stud ledge succeeds and 11.75 fails. **That reasoning was wrong, and the scripted trials
caught it**: the route rig spent every run standing on top of the door row, jumping.

The mechanism was then measured directly, on the built course, with a plain R15 rig walking into a
solid row-1 slab from the corridor floor and jumping repeatedly:

| Build | Max root rise | Where it ended | Door top, roof underside |
|---|---|---|---|
| Doors alone (14.65-stud slabs) | **+25.41 studs** | standing on the door top (+13.6) and jumping off it | +13.05, no roof |
| Roof flush above the tops | +11.4 (route rig) | **wedged** in the 0-1 stud gap, state `Climbing`, velocity ~0 | +13.05, +13.06 |
| Roof set INTO the tops | **+6.64 studs** | back on the corridor floor, state `Running` | +13.05, **+12.01** |

The shipped build uses shorter, channel-width doors: tops at 9.95, 10.95 and 11.95 above the
corridor, with the roof undersides at 8 and 9, so every slab is set into the roof.

Sampled root heights in the first case: 6.8, 10.6, 12.2, **13.6** — on the slab within about 0.6
seconds, from a standing start, with no other geometry involved. Repeated jumps into a flat wall
climb further than a single jump onto a ledge, which is what the 11.5-stud calibration measured, so
`CourseQA`'s graph (which caps a jump's rise at that calibration) did not model it either. That is a
limit of the graph worth carrying forward, not a Door Dash quirk.

Section 6 already prescribes the fix — "close their over-jump space with VISIBLE stock supported
tunnel/roof geometry" — so the door section is roofed: five stepped bands of stock slabs, rotated so
their long axis spans the corridor, 20 parts in total.

It took three passes to get the roof right, and the cut-set audit caught each wrong one:

1. **Undersides flush with the door tops** removed the standing space but left a 0-1 stud gap, and
   the route rig climbed into it and jammed, motionless, in Roblox's `Climbing` state.
2. **Undersides just below the tallest top** still left the outer doors 0.46 studs proud of one
   band, and that was a real staircase: the audit traced a racer jumping 11 studs onto an exposed
   top, then onto the roof, then walking the corridor and dropping past **five gates**.
3. **A roof 25 studs wider than the corridor** was itself the bridge: the trace jumped from the
   overhang to the second run, 18 studs across and 18 down, inside the measured envelope.

The shipped roof fixes all three: undersides at 8 and 9 studs above the corridor, below every door
top, so no top is exposed and there is neither a ledge to catch nor a pocket to wedge in; and the
bands are exactly the corridor's width (measured z 6.71 to 105.29 against the corridor's 6.95 to
105.05), so there is no overhang to stand on. The roof's own top is 17 studs above the floor, well
past the 11.5-stud ledge. Bands alternate 8 / 9 so no 24-stud square of level roof exists either;
the measured largest flat square on the whole course is 16 x 16, and the corridor keeps 8 studs of
headroom against a 5-stud character.

## Beats

| Beat | Family / mechanic | Target | **Measured arc** | **Ratio** | **Measured dY** | Primary encounters |
|---|---|---|---|---|---|---|
| 01_DoorDrama | Crowd / door choice | 180 | 199.76 | 1.110 | 0.0 | 3 rows of 5 doors, quota 2 per row; row yaw 0 / +15 / -15; spacing 26 / 34 |
| 02_SlideSwipe | ClimbDescend / slide exit | 100 | 106.11 | 1.061 | -12.0 | 1 cross spinner at the slide bottom; 1 forced bumper on an 11.9-stud lane |
| 03_BeltBrawl | Ride / counterbelts | 150 | 162.97 | 1.086 | +6.0 | 3 conveyors at -13 / -15.6 / -18.2; 1 paddle wheel crossing the middle belt |
| 04_PadParade | Launch / successive launches | 130 | 144.56 | 1.112 | +12.0 | 3 pads at 48 / 50 / 52 over a foam catch basin; 1 forced landing bumper |
| 05_MaceMarch | Timing / pendulum gauntlet | 160 | 169.86 | 1.062 | 0.0 | 2 maces at phases 0 / 1.07 over a narrowing lane; 1 forced triangular bumper; 1 large hammer at the exit |
| 06_CrossFinish | Timing / one readable sweep | 80 | 74.81 | 0.935 | -6.0 | 1 two-arm cross, the easiest window in the course; finish |

Every beat sits inside section 5.2's 0.85–1.15 band, and the dY column reproduces section 7.3's
elevation column exactly. The climax is 05 (4 encounters) and the final beat carries 1, so the
finishing sprint is short and easier as section 3.2 requires.

### Piece detail

| Piece | Source, scale | Measured size | Placement |
|---|---|---|---|
| Funnel01 | `platform_001`, 0.22 | 15.4 wide, 19.4 travel | the whole start plaza drains through it, inside the 60-stud gate plane |
| W1–W6 channels | `platform_001/2/3`, 0.28 | 19.62 wide, 24.64 travel | 5 abreast at 0 / -1 / -2 studs, tapering to 3 then 1 |
| Door01–15 | `door_002`…`door_007`, 0.261 | 19.62 x 11.95 x 1.64 | one slab per channel, edge to edge; rows at 0 / +15 / -15 degrees |
| Slide01 | `slide_001`, 0.2317 | drops 12.0 in 5.79 of travel | the same scale the pilot uses for the same drop |
| RoofA-D | `platform_001/2/3`, 0.34, rotated 90 degrees | 29.92 across, 23.8 deep, 9.7 thick | four stepped bands over the door section, undersides at 13.65 / 14.65 |
| Cross01 | `obstacle_12_001`, 0.5 | 29.04 across | centred on an 18.2-stud lane, so the sweep covers both edges |
| Bumper01 | `obstacle_18_001`, 0.5 | 7.17 across | centred on an 11.9-stud lane with liquid off both edges |
| Belt01/02/03 | `obstacle_9_001`, 0.5 | 13.98 wide, 27.95 travel | signed -13 / -15.6 / -18.2 along local Z |
| PaddleWheel01 | `obstacle_24_001`, 0.5 | cradles orbit 7.74 about an X axle | axle 1.5 studs above the middle belt; cradles sweep its full width |
| Pad01/02/03 | `trampoline_4_001`, 0.6 | 8.9 across | on 10.5-stud launch decks, launch speeds 48 / 50 / 52 |
| BasinRamp/Deck + Foam01 | `box_011` 0.4211, `platform_002` 0.3 | 84 studs of gutter 12 below the route | the only way out is back up to the beat entrance |
| Mace01/02 | `obstacle_5_001`, 0.7 | ball hangs 14.53 below the axle | axle 21 studs above the deck; the ball's underside sweeps 2.89 above it |
| HammerLarge | `obstacle_3_001`, 0.6 | head 18.5 x 31.3 | on the beat's widest slab, readable from the ramp below; hung at `OffsetUp` 20.428 — see the fix below |
| TwoArm01 | `obstacle_27_001`, 0.5 | 29.04 across, two arms | half the circle is open at any moment: the easiest window in the course |

### Speeds, all from the section 6 formulas at measured radii

| Piece | Source, scale | Measured contact radius | Speed |
|---|---|---|---|
| Cross01 | `obstacle_12_001`, 0.5 | 29.038 * 0.5 = 14.519 | `ceil((33.8*180/(pi*14.519))/5)*5` = **+135 deg/s** |
| TwoArm01 | `obstacle_27_001`, 0.5 | 14.519 | **-135 deg/s**, phase 0.5 (opposite sign and phase to Whirlpool Waltz's two-arm) |
| PaddleWheel01 | `obstacle_24_001`, 0.5 | 15.4862 * 0.5 = 7.743 | `ceil((33.8*180/(pi*7.743))/5)*5` = **255 deg/s**, tip speed 34.4 studs/s |
| Mace01 / Mace02 | `obstacle_5_001`, 0.7 | swing radius 20.756 * 0.7 = 14.53 | rock, amplitude 45, period 3.2, phases **0 and 1.07** (section 6's mace neighbours) |
| HammerLarge | `obstacle_3_001`, 0.6 | n/a (rock) | amplitude 55, windup 1.8, strike 0.3, phase 0 |
| Belt01/02/03 | `obstacle_9_001`, 0.5 | n/a | **-13 / -15.6 / -18.2** studs/s, inside section 9.7's 13–18.2 band |
| Pad01/02/03 | `trampoline_4_001`, 0.6 | n/a | LaunchSpeed **48 / 50 / 52**, FloatFactor 0.2 |

Shove settings are section 6's fixed seeds: ordinary 48 / up 20 / hold 0.24, bumper 54 / 22 / 0.26,
hammer 58, mace 54, all with `ShoveContact = "mesh"`, `ImpactVisual = true`,
`RetriggerCooldown = 0.8`, `GuardSeconds = 1.0`.

### The two new presets, and the pivot the paddle wheel needed

`Mace` puts `Rotor = "rock"`, axis Z, and `Shove` on the top link, which is both the axle and the
shove owner: `RotorBump` tests a shoving rotor's followers as well as the rotor part, so the nine
links and the ball all shove without needing their own motion owners — which `AttributeAudit` would
reject as competing owners on the same assembly. HANDOFF 8.3 covers the fact that the chain hangs
from nothing visible: "suspended mace links are supported by their chain and axle, not required to
touch a floor".

`PaddleWheel` was the one piece that needed more than attributes. An attribute rotor turns about its
part's own pivot, and the builder clears every imported display pivot, so the wheel would have spun
about the root mesh's bounding centre — 4.25 studs (at scale 1) away from the axle its four cradles
actually orbit, which reads as a wobble, not a wheel. The measured axle is set back as an explicit
`PivotOffset` after scaling, which is exactly what 02-kits.md asks for: "attribute rotors turn
around explicit mechanical pivots; an imported display pivot is not necessarily an axle. Change
pivots, never distort the mesh."

## Measured bounds

| Bound | Measured | Limit |
|---|---|---|
| Max part corner distance from Origin | 494.78 | 600 |
| Max geometry centre radius | 247.59 | 380 |
| Max route radius | 245.43 | 300 (BoundsRadius) |
| Static route envelope Y | -16.00 .. 62.00 | -30 .. 90 |
| Whole-model Y (boundary ring and liquid included) | -21.00 .. 285.12 | reported, not banded |
| Violations | 0 | 0 |

## Measured gaps

Door Dash has **no ordinary jump gaps**. Every walkable transition is a socket-chained join; the only
three `Advance` steps on the route are beat 04's launch transfers.

| Transition | Measured | Classification |
|---|---|---|
| 04_PadParade/Gap01 | 14.00 studs, +4 studs of rise | launch transfer (pad 48) — NOT RUN against an ordinary-gap rule by design (8.3) |
| 04_PadParade/Gap02 | 14.00 studs, +4 | launch transfer (pad 50) |
| 04_PadParade/Gap03 | 14.00 studs, +4 | launch transfer (pad 52) |

Section 8.3 is explicit that launches "use separate measured reach-window acceptance; do not falsely
force them through the ordinary gap formula", so the audit reports these three as NOT RUN until the
scripted and interactive trials measure the reach window.

## Encounters and variety

19 encounters, scored the way section 7 override 3 defines them (a door row is one encounter however
many slabs it has; a chicane is one however many bumpers).

| Type | Count | Share | Instances |
|---|---|---|---|
| RotorBump | 6 | 31.6% | Cross01, PaddleWheel01, Mace01, Mace02, HammerLarge, TwoArm01 |
| Door | 3 | 15.8% | DoorRow01, DoorRow02, DoorRow03 (5 slabs each, two breakable) |
| Conveyor | 3 | 15.8% | Belt01, Belt02, Belt03 |
| JumpPad | 3 | 15.8% | Pad01, Pad02, Pad03 |
| Bumper | 3 | 15.8% | Bumper01, Bumper03, Bumper02 |
| FoamPit | 1 | 5.3% | Foam01 |

Per-instance counts, reported and never scored: 15 door slabs, 3 bumper cubes/triangles, 3 pads,
3 belts, 2 maces (11 parts each), 1 paddle wheel (5 parts), 1 hammer, 2 spinners, 1 foam volume.

Measured against the section 8.4 rules: 6 distinct types (needs 6), 5 families (needs 4), dominant
type 31.6% (cap 40%), longest same-type run 3 (cap 3), climax is the second-to-last beat. All twelve
cross-course checks over the three staged specs pass, including the three-course cap on every
non-glue mechanic and the ban on a shared beat recipe.

## The five loophole questions

Section 11 step 1's exact five questions, per encounter. The first four must be NO. A timed jump
THROUGH the intended gate is legal; jumping past the beat is not. Every "no bypass" answer below is
backed by `CourseQA.checkCutSets`, which removed each beat's gate volume in turn and found **0 of
30 spawn cells** could still reach the finish — over a graph of 28,121 nodes and 1,272,671 edges
sampled from 38,241 real surface cells.

| Encounter | Walk-around | Edge-hug | Bypass-jump | Launched-past | Safe-wait |
|---|---|---|---|---|---|
| DoorRow01 | NO — the row is 98.1 studs of continuous wall across a 98.1-stud corridor, measured edge to edge | NO — the outer slabs end exactly where the deck does, and past that is liquid | NO — **measured**: the roof leaves 0-1 stud over a door top, and the climb test that reached +13.6 studs without it reaches +6.64 with it | NO — no launcher in beat 01 | YES, free before the row: 30 racers pick a channel. Costs nothing by itself, which is why the quota is 2 of 5 |
| DoorRow02 | NO — same wall, yawed +15 degrees, 94.8 studs of lateral cover against the corridor's 98.1 measured on its own line | NO | NO — roofed, as above | NO | YES, but every wrong slab is a rebound: the scripted mid policy pays for its guesses |
| DoorRow03 | NO — yawed -15 degrees | NO | NO — roofed, as above | NO | YES, same as above |
| Cross01 | NO — 29.04-stud sweep across an 18.22-stud lane | NO — the arms pass beyond both lane edges | NO — gate 02's cut set holds | NO | YES, on the slide run-out; costs the wait, no shortcut |
| Bumper01 | NO — 7.17-stud bumper centred on an 11.9-stud lane leaves 2.4 studs a side against a ~2-stud body | NO — liquid off both edges | NO | NO | NO — the bumper is static; waiting changes nothing |
| Belt01/02/03 | NO — the belts are the floor, 13.98 studs wide with liquid either side | NO | NO | NO | NO — standing still on a counterbelt moves you backwards |
| PaddleWheel01 | NO — cradles orbit 7.74 and sweep the full 13.98-stud belt | NO | NO | NO | YES, on the belt behind it, and the belt pushes you back while you wait: the wait has a measured cost |
| Pad01/02/03 | NO — the decks are 10.5 studs wide with the foam gutter below and liquid beyond | NO | NO — the landings are launch transfers, and gate 04's cut set holds with the basin in the graph | NO — the audit found no reachable later-beat landing | YES on each deck; free, and the pads are always armed |
| Foam01 | n/a — it is the penalty, not an obstacle | n/a | NO — the gutter's only exit is back up to the beat entrance | NO | n/a |
| Bumper03 | NO — centred on the 15.4-stud landing deck | NO | NO | NO | NO |
| Mace01 | NO — ball sweeps 10.3 studs either side of centre over a 15.4-stud lane | NO — liquid off both edges | NO — gate 05's cut set holds | NO | YES, before the swing; costs the wait |
| Bumper02 | NO — centred on a 14.0-stud lane | NO | NO | NO | NO |
| Mace02 | NO — same sweep over a 12.6-stud lane, phase 1.07 out of step with Mace01 | NO | NO | NO | YES, costs the wait |
| HammerLarge | NO — 18.5-stud head across a 22.9-stud slab at amplitude 55 | NO | NO | NO | YES, costs the wait |
| TwoArm01 | NO — 29.04-stud sweep across a 22.9-stud lane | NO | NO — gate 06's cut set holds | NO | YES, and it is meant to: this is the readable finishing window |

The blocked fractions those "NO" answers imply are **not yet measured**: section 8.4's ≥0.4 blocked
fraction per pendulum crossing and the five-contact shove-travel measurements are live-playtest
items and are listed as NOT RUN below. What is measured is the geometry (spans against lane widths)
and the graph (no gate bypass from any spawn).

## Scripted route trials

Eight trials per HANDOFF 8.5 (3 expert, 5 mid at seeds 101-105), driven by
`docs/splashdown/probes/run-course-routes.server.luau` against the built course in an isolated
clone lifted to Y 20,000. Raw: `evidence/courses/DoorDash/routes.json`.

**0 of 8 cleared.** This is a measured FAIL of section 8.5's pace gate, and it is reported as one.

| Policy | Seeds | Cleared | Elapsed | Falls | Checkpoints | Doors opened | Ended |
|---|---|---|---|---|---|---|---|
| expert | 901-903 | 0 of 3 | 15.9-18.9 s | 0 | 0 | 1-2 rows | stuck in the door corridor |
| mid | 101-105 | 0 of 5 | 24.4-150 s | 0-11 | up to **2 of 5** | 1-3 rows | two at the 150 s ceiling, three stuck |

What the runs do establish: the proxy opens door rows and crosses them, walks the slide and the
spinner, rides all three counterbelts under the paddle wheel and reaches the foam basin under the
launch chain. 15 distinct pieces were contacted across the set — eight door slabs, both beat-02
hazards, all three belts, the paddle wheel and the foam pit — and the best run earned two of the
five checkpoints with eleven checkpoint respawns. (An earlier build of the same course, before the
last two roof passes, reached three checkpoints and the second launch deck; the geometry difference
between them is roof-only.)

What they do not establish is whether a human clears it in 60-90 seconds. The straight-line proxy
has no steering: it walks into walls it cannot slide around, and a five-slab door row is a wall with
one hole in it. Seven harness defects were found and fixed during this work (see the changelog) and
the runs improved from "stuck at row 1 in every trial" to "three of five checkpoints", but the
remaining failures are the proxy's own pathing, not a measured statement about the course.
**HANDOFF 8.5's stated resolution applies: an interactive keyboard run and, if it disagrees with the
proxy, a user mid-skill calibration run. Both are outstanding.**

## Fixed-camera captures

`evidence/courses/DoorDash/top-down.png` and `three-quarter.png`, with the camera CFrames recorded in
`evidence/course-cameras.json`. Both use the section 8.6 offsets relative to the course's own origin
at a documented 70-degree FOV; the preview was lifted 9,000 studs first, because the arena's own
hazard ring sits at MapOrigin and filled the frame.

Compared against `bad-map-refs/1.png`, `9.png`, `10.png` and `11.png`:

- **1 (flat sprinkled field):** no. The course is a ribbon of 14-20-stud lanes over open water; there
  is no wide flat plane with hazards scattered on it. The one wide area is the door corridor, and it
  is wall-to-wall doors.
- **9 (repeated narrow swing-panel bypass):** no. No mechanic repeats identically down a lane; the
  three door rows differ in yaw and spacing, the three belts differ in speed, the three pads differ
  in launch speed, and the two maces are 1.07 s out of phase.
- **10 (empty slabs, lone open spinner):** no. Every slab on the route carries or adjoins an
  encounter; the only exempt plazas are start and finish.
- **11 (vast empty plaza, avoidable bumper):** no. Both bumpers on narrow lanes sit centred with
  2.4-4 studs of clearance a side against a ~2-stud body.

The one thing the top-down does show is that the roofed door section reads as a solid block from
directly above, which is what a roof looks like; the three-quarter view and the intro camera's
second shot both look along the corridor instead.

## Automated QA, as measured

| Check | Result |
|---|---|
| Build determinism | **PASS** — `8c00a748` on a double build |
| AttributeAudit | **PASS** — 0 errors |
| Bounds | **PASS** — 0 violations, see table above |
| Beat length band 0.85–1.15 | **PASS** — 0.935 to 1.112 |
| Route arclength 800–1000 | **PASS** — 882.07 |
| Chute invariants (3 segments, doubling back, pitch, run ratio, hairpin window) | **PASS** — hairpin reverses at 60.09% |
| 30 start pads, 5 ordered checkpoints, 1 finish, 24 boundary walls at 390 | **PASS** |
| Ordered route from every spawn | **PASS** — 30 spawn cells, 6 ordered waypoints, 0 failing legs |
| Gate cut sets (all six beats) | **PASS** — 0 of 30 spawn cells bypass any gate |
| No 24x24 breather square | **PASS** — largest flat square 16 x 16 |
| Variety (types, families, dominance, runs, climax) | **PASS** |
| Cross-course rules over all three staged specs | **PASS** — 12 of 12 |
| Door rows resolve | **PASS** — 15 slabs as immediate `Scriptables.Doors` children, rows of 5/5/5, contiguous indices |
| Studio TestEZ (`SplashdownQA.spec`) | **PASS** — 12 passed, 0 failed, 0 skipped |

`CourseQA.check` returns **0 errors and 0 warnings**; 37 of 50 findings are PASS and the other 13 are
NOT RUN with a reason. Status stays **BLOCKED** because the module never reports PASS while a live
check is outstanding.

## Manual checklist

| Check | Status |
|---|---|
| Built twice with identical SpecHash | **PASS** — `8c00a748` |
| Scripted expert/mid route trials | **FAIL** — 0 of 8 cleared; best run earned 3 of 5 checkpoints (`routes.json`) |
| Deliberate missed-timing contacts | NOT RUN |
| Interactive keyboard run | NOT RUN |
| Checkpoint recovery | **PARTIAL** — the mid trials fell 11-12 times and respawned at their last checkpoint every time, earning up to checkpoint 3; not verified in the actual mode with a real Player |
| Fixed-camera captures and bad-map-refs comparison | **PASS** — both views captured and compared above |
| 30-rider start load test | NOT RUN |
| Studio local multi-client session | NOT RUN |
| Lane cross-section coverage and pendulum blocked fraction | NOT RUN |
| Five-contact shove travel per hazard | NOT RUN |
| Line-of-sight readability corroborated by screenshots | NOT RUN |
| Palette and dressing applied | NOT RUN (set-wide gap) |
