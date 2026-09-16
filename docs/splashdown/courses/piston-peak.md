# Piston Peak

HANDOFF.md section 7.6. Layout kind **StackedSwitchback** (section 5.2). Written before the build,
from the section 7.6 table and the scaled route-length targets in `03-overrides.md`; every number
below was then re-measured off the built model and corrected where the plan and the geometry
disagreed.

## Concept and headline

A climbing tower. Five short runs stacked over two centrelines 40 studs apart, joined by four
switchback landings, rising 66 studs from a start plaza that the liquid eventually swallows. The
headline is the **piston** — the punch cascade across the highest ledge at beat 06 — and Piston Peak
is the only new course that reuses HANDOFF section 6's rising-liquid twist.

Palette (override 1): base orange `#FF9E43`, accent cyan `#27C8E8`, walkable tops keep the kit's
blue. **Not applied by the builder.** `CoursePresets` clones source parts without recolouring, which
is true of all five courses built before this one; the palette is recorded here as the design intent
and the recolouring pass is an open set-wide item, not something this course invented.

## Layout and guide

`Layout.Kind = "StackedSwitchback"`, `LanePitch = 40`, `BoundsRadius = 300`, `LiquidY = -30`.

A switchback staircase in plan view is a rectangle walked in one rotational direction, so the guide
is an ordinary polyline that deliberately retraces itself: runs 1/3/5 share the `Z = -20`
centreline, runs 2/4 share `Z = +20`, and every turn is a right angle turned the same way. The X
extents are **computed in the spec from the beats**, not drawn — each run segment is exactly the
lateral its incoming corner spends, plus its own pieces, plus a 14-stud approach deck, plus the
along its outgoing corner spends — so the route closes on 880 studs and no corner can overrun its
vertex.

| Guide point | X | Z | segment | length |
|---|---|---|---|---|
| P1 | -120.0000 | -20 | run 1 (+X) | 174.5048 |
| P2 | 54.5048 | -20 | cross 1 (+Z) | 40 |
| P3 | 54.5048 | +20 | run 2 (-X) | 118.9091 |
| P4 | -64.4043 | +20 | cross 2 (-Z) | 40 |
| P5 | -64.4043 | -20 | run 3 (+X) | 156.1008 |
| P6 | 91.6965 | -20 | cross 3 (+Z) | 40 |
| P7 | 91.6965 | +20 | run 4 (-X) | 140.9404 |
| P8 | -49.2439 | +20 | cross 4 (-Z) | 40 |
| P9 | -49.2439 | -20 | run 5 (+X) | 145.5449 |
| P10 | 96.3010 | -20 | — | — |

The route uses 129.5449 of the last segment and finishes at X 80.3010, Y 66. Measured worst route
radius **92.6** against the 300 bound; worst part corner **489.1** against 600; worst geometry
centre radius **121.7** against 380.

### Corner sockets: the first defect this course found

`water_platform_001` is the only stock piece square enough to turn a 40-stud pitch on. Every turn
here is a RIGHT turn, and `CourseBuilder.cornerRun` leaves a right turn through the measured
**`SideNegativeX` socket at -18.6361**, not `SidePositiveX` at +18.3634. The first build of this
course used the positive figure and put the second hairpin **0.11 studs past its own vertex**, which
the builder caught as a guide overrun. Corrected: one corner spends `18.6366 * 0.4 = 7.45464` along
its incoming run and `18.6361 * 0.4 = 7.45444` across the cross, leaving a **25.0909-stud slot**
between the two corners of a hairpin — which is what beat 03's seesaw plank fills exactly, so the
plank's scale (0.3345456) is derived from the slot rather than chosen.

### The builder's six StackedSwitchback invariants

All enforced against the built model:

1. an odd segment count of at least five, runs on the odd segments and one lane pitch on every even
   one;
2. `LanePitch` inside the declared 30-40 band (section 5.2);
3. runs alternate through 180 degrees and crosses alternate through 180, so run *k* and run *k+2*
   really do share a centreline, and every turn is a same-handed right angle;
4. every run's **measured** elevation change climbs — measured 12 / 12 / 12 / 18 / 12 = 66;
5. two runs sharing a centreline stay more than `MinStackClearanceStuds` (declared 18) apart
   vertically at every measured route step — **measured worst 24.000, run 3 against run 5 at
   Ledge02** — and that clearance must itself beat the measured 11.5-stud step-up;
6. no measured pair of route steps on different runs that would save at least 30 studs of route is
   inside the ordinary jump reach for its own rise unless a declared guard wall stands across the
   line between them — **measured worst margin +2.004 studs (Tread08 to Tread10), with 10 further
   pairs closed by a guard wall.**

### Why the pitch alone already holds

HANDOFF 3.2's measured flat jump is 22 studs (22.25 fails). The widest deck column A carries is the
17.399-stud entry/chicane tread and the widest column B carries is the 14.909-stud switchback
landing, so the tightest edge-to-edge gap any cross-run hop could ever face is
`40 - 8.700 - 7.455 = 23.846` studs — 1.85 studs past the measured jump, at zero rise. Every stacked
pair is 24 studs or more apart vertically, which no jump reaches at all (a +11 rise is already
unreachable: the ordinary jump apex is 10). Spacing is not the proof, though — section 5.2 says so
explicitly — so the builder measures every pair and the guard walls add the enclosure the layout
kind requires.

### Guard walls

`wall_001` ("tall inflatable wall/endcap", 18.8965 x 22.9403 x 7.7135) at uniform scale 0.615:
11.621 studs long, 4.744 thick, and **measured 14.108 studs above the run it stands on** — section
5.2's measured 14. One per run, on that run's own deck at the edge facing the other column. Tumble
Tunnels' lesson ("never stack stock slabs to make a wall") is about stacking slabs vertically to
fake height; these are single pieces at one height, create no intermediate standable top, and at
14.108 studs are unjumpable against a 10-stud jump height.

Run 5's wall stands on the finish lane rather than on the piston ledge: the heads sweep that ledge
edge to edge, so a wall on its inner rim would be struck on every punch.

## Rising liquid

Section 7.6's seed is baseY -30, `StartDelaySeconds` 20, `RiseStudsPerSecond` 0.4, `MaxHeight` 60,
no pauses, which stops the flood at world-local Y +30.

**That seed strands two checkpoints and is lowered to `MaxHeight = 38`** — one derived decision, not
eleven tuning passes. The route places six checkpoints at the beat entrances, at Y 12, 24, 30, 36, 48
and 60. A racer who respawns on a pad that is under the flood line splashes, respawns on the same
drowned pad and never leaves, which is exactly the strand section 7.6 says to tune out ("if flooding
strands credit, lower MaxHeight in 2-stud increments until the flood regression passes"). At
`MaxHeight` 60 the flood finishes at +30 and drowns the Y 12 and Y 24 pads. 60 down to 38 in 2-stud
steps stops the flood at **+8**, and the builder measures the result: **flood top +8.0, lowest
checkpoint pad +12.0, clearance 4.0** against the declared 4-stud minimum, with the build failing if
it drops below.

The flood still does its job: it starts at 20 s, reaches the start plaza's Y 0 at 95 s, and finishes
rising at 115 s against the 180-second cap. Beat 01 climbs out of it. A racer who has not yet earned
checkpoint 01 when the plaza floods respawns into water and is eliminated by the cap — that is the
mode's existing behaviour for a rising-liquid course, it is not a checkpoint strand, and it is
recorded here rather than patched away.

## Beats

Scaled section 7.6 targets from `03-overrides.md`: 154 / 143 / 99 / 121 / 121 / 176 / 66 = 880.

| Beat | Family / mechanic | Target; measured; ratio | Elevation | Primary encounters |
|---|---|---|---|---|
| 01_ZigzagZip | Climb/Descend / slope counterbelts | 154; 157.959; 1.0257 | +12 | 3 conveyors at -13 / -15.6 / -18.2; 1 forced cube+wedge chicane on the first switchback landing |
| 02_LogClimb | Timing / rolling ramps | 143; 130.000; 0.9091 | +12 | 2 barrel log-rolls, opposite spin, 7.34 and 5.20 stud diameters, at the head of consecutive ramp flights |
| 03_TeeterTurn | Ride / seesaw turn | 99; 97.962; 0.9895 | +6 | 1 `obstacle_11` seesaw spanning the switchback slot, max tilt 20 |
| 04_PinballPass | Precision / forced chicane on a slope | 121; 127.048; 1.0500 | +6 | 3 alternating bumpers varying shape and height (one chicane); 1 foam gutter |
| 05_Updraft | Launch / stacked pad ascent | 121; 122.979; 1.0164 | +12 | 2 pads at 48 / 52 up the stack; 1 forced bumper at the upper landing |
| 06_PunchPeak | Timing / piston cascade | 176; 160.038; 0.9093 | +12 | 3 pistons, phases 0 / 1.05 / 2.1, alternating lateral punch directions across the highest ledge |
| 07_PeakSprint | Climb/Descend / short final ramp | 66; 60.014; 0.9093 | +6 | arch finish; no timing trap |

Measured beat sum 856.000, plus the 24-stud start-plaza exit the builder counts before beat 01,
gives a **880.000-stud route** (reported 880.0000114). Beats run 0.9091-1.0500 of their scaled
targets, inside 0.85-1.15. Elevation is +12 / +12 / +6 / +6 / +12 / +12 / +6, matching section 7.6
exactly; StartY 0, finishY 66. **162 BaseParts, 6 ordered checkpoints, 30 start pads, 24 boundary
walls.**

**Encounters, scored per section 7's counting rule:** RotorBump 5 (33.3%: 2 log-rolls, 3 pistons),
Conveyor 3, Bumper 3 (three chicane groups, each one encounter), JumpPad 2, Seesaw 1, FoamPit 1 =
**15 encounters, six types, five families** (Climb/Descend, Timing, Ride, Precision, Launch). No
same-type run exceeds three, every consecutive same-type pair differs (belts -13/-15.6/-18.2; rollers
+530/-745 deg/s at 7.34 and 5.20 stud diameters; pads 48/52; pistons 0/1.05/2.1 alternating sides).
Climax is 06, second to last; 07 is a short readable finish. Per-instance counts (9 bumper slabs, 3
piston assemblies, 2 roller assemblies, 5 guard walls) are reported in `qa.json` and never scored.

**Headline.** Declared `"Piston"` — a PRESET, not a scoring type. Override 2 calls it a headline
mechanic and section 7.6's is "zigzag climb with punches"; a piston scores as RotorBump beside every
pendulum in the set, and RotorBump is nobody's headline. `auditCrossCourse` now scores a declared
headline at whichever granularity it names, which compares pistons only against pistons and leaves
the five type-named courses scored exactly as before.

### Piece table

Every scale is derived from the measured `AssetManifest` sockets.

| Beat | Piece | Kind | Source @ scale | Travel | Width | Notes |
|---|---|---|---|---|---|---|
| 01 | Tread01 | Chain Platform | `water_platform_001` @ 0.4668 | 17.272 | 17.399 | the funnel off a 52.9-stud plaza |
| 01 | GuardWall01 | Mount Prop | `wall_001` @ 0.615 | — | 4.744 thick | measured top +14.108 |
| 01 | Belt01/02/03 | Chain Conveyor | `obstacle_9_001` @ 0.32 | 17.891 each | 8.946 | -13 / -15.6 / -18.2 |
| 01 | Climb01/02 | Chain Ramp | `box_011` @ 0.210526 reversed | 29.053 each | 12.689 | +6 each |
| 01 | ChicaneCube / ChicaneWedge | Mount Bumper | `obstacle_18_001` / `obstacle_19_001` @ 0.5 | — | 7.174 / 9.936 | one `EncounterGroup` |
| 01 | TurnA1 | Corner Right | `water_platform_001` @ 0.40 | 14.909 | 14.909 | after a 14-stud approach deck |
| 02 | TurnB1 | Corner Right | `water_platform_001` @ 0.40 | 40.000 | 14.909 | fills the 25.091-stud cross slot with two decks |
| 02 | Tread02/03/04 | Chain Platform | `water_platform_001` @ 0.28734 | 10.632 each | 10.710 | |
| 02 | GuardWall02 | Mount Prop | `wall_001` @ 0.615 | — | — | measured top +14.108 |
| 02 | Climb03/04 | Chain Ramp | `box_011` @ 0.210526 reversed | 29.053 each | 12.689 | +6 each |
| 02 | Roll01 / Roll02 | Mount LogRoll | `obstacle_10_001` @ 1.20 / 0.85 | — | 16.77 / 11.88 long | +530 / -745 deg/s, laid on their sides |
| 03 | TurnA2 | Corner Right | `water_platform_001` @ 0.40 | 28.909 | 14.909 | 14-stud approach deck then the turn |
| 03 | Seesaw01 | Chain Seesaw | `obstacle_11_001` @ 0.3345456 | 25.091 | 11.604 | fills the cross slot exactly; max tilt 20 |
| 03 | TurnB2 | Corner Right | `water_platform_001` @ 0.40 | 14.909 | 14.909 | no fill: the plank closed the slot |
| 03 | Climb05 | Chain Ramp | `box_011` @ 0.210526 reversed | 29.053 | 12.689 | +6 |
| 04 | Tread05-08 | Chain Platform | `water_platform_001` @ 0.4668 | 17.272 each | 17.399 | |
| 04 | Climb06 | Chain Ramp | `box_011` @ 0.210526 reversed | 29.053 | 12.689 | +6, the slope |
| 04 | Bump01/02/03 | Mount Bumper | `obstacle_18_001` @ 0.5, `obstacle_19_001` @ 0.6, `obstacle_18_001` @ 0.42 | — | 7.174 / 11.923 / 6.026 | one `EncounterGroup`, heights 6.70 / 7.70 / 5.63 |
| 04 | Foam01 | Mount FoamPit | authored volume 17 x 6 x 17 | — | 17 | forced lane, not a penalty detour |
| 04 | GuardWall03 | Mount Prop | `wall_001` @ 0.615 | — | — | on Tread08, past the foam |
| 04 | TurnA3 | Corner Right | `water_platform_001` @ 0.40 | 28.909 | 14.909 | |
| 05 | TurnB3 | Corner Right | `water_platform_001` @ 0.40 | 40.000 | 14.909 | |
| 05 | Tread10/11/12 | Chain Platform | `water_platform_001` @ 0.3917 | 14.493 each | 14.600 | |
| 05 | Pad01 / Pad02 | Mount JumpPad | `trampoline_2_001` @ 0.5 | — | 6.192 | LaunchSpeed 48 / 52, Float 0.2, centred on the deck edge |
| 05 | Hop01 / Hop02 | Advance | — | 19.000 / 20.500 | — | +6 each |
| 05 | LandingBumper | Mount Bumper | `obstacle_18_001` @ 0.5 | — | 7.174 | forced at the upper landing |
| 05 | GuardWall04 | Mount Prop | `wall_001` @ 0.615 | — | — | back of Tread10, clear of Pad01 |
| 06 | Climb07 | Chain Ramp | `box_011` @ 0.210526 reversed | 29.053 | 12.689 | +6, run 4's tail |
| 06 | TurnA4 / TurnB4 | Corner Right | `water_platform_001` @ 0.40 | 28.909 / 40.000 | 14.909 | |
| 06 | Climb08 | Chain Ramp | `box_011` @ 0.210526 reversed | 29.053 | 12.689 | +6, onto the peak |
| 06 | Ledge01/02/03 | Chain Platform | `platform_002` @ 0.1250895 | 11.008 each | 8.765 | the highest ledge |
| 06 | Piston01/02/03 | Mount Piston | `obstacle_22_001` @ 0.5 | — | 5.445 along the route | phases 0 / 1.05 / 2.1, sides +19.5 / -19.5 / +19.5 |
| 07 | Climb09 | Chain Ramp | `box_011` @ 0.210526 reversed | 29.053 | 12.689 | +6 |
| 07 | Lane01/02 | Chain Platform | `platform_002` @ 0.1759182 | 15.481 each | 12.327 | |
| 07 | GuardWall05 | Mount Prop | `wall_001` @ 0.615 | — | — | measured top +14.108 |
| 07 | FinishArch | Mount Prop | `arch_005` @ 0.35 | — | 15.12 bore | threshold dropped to deck level |

## Measured hazard geometry

Everything below is read off the BUILT model, not off the spec.

### Pistons reach lane height, and the mount distance is what makes the ledge a puzzle

`obstacle_22_001`'s Support socket is at local y -10.16; its head `obstacle_22_003` sits at measured
local (0.054, -0.109, -26.319) and is 10.890 x 9.318 x 15.429. Mounted with its Support on the deck
at scale 0.5 the head's centre lands 5.03 studs above the deck. **Measured on the built model: the
head spans Y 62.70 to 67.36 over a ledge whose top is Y 60.00 — 2.70 to 7.36 studs above the deck**,
squarely across a runner whose root sits 3.5 studs up. This is the opposite of the suspended
hammers, whose heads hang 16-17 studs *beneath* their axle housings.

The arm is long: 13.159 studs from the mount to the head's centre at scale 0.5, with a 3.857-stud
half-length and a 6-stud punch, so the head's inner face sits at `side - 17.019` at rest and
`side - 23.019` fully extended. **The mount distance decides whether the ledge is a timed squeeze or
a wall, and the first build got it wrong.** At side 17 every head reached 0.02 studs past the ledge
centreline at rest; because the three alternate sides, their rest poses between them covered the
whole corridor, the sampled graph found no standable cell across the ledge, and the ordered-route
audit failed the last two legs.

At **side 19.5** (measured on the built model):

| | +side piston head, world Z | -side piston head, world Z |
|---|---|---|
| ledge | -24.38 to -15.62 | -24.38 to -15.62 |
| head at rest | -17.52 to -9.80 | -30.20 to -22.48 |
| corridor left open | -24.38 to -17.52 | -22.48 to -15.62 |

The corridor open past **all three** pistons is Z -22.48 to -17.52, **4.96 studs wide**, running the
full length of the ledge and comfortably past the 3.06-stud precision minimum. The same head sweeps
6 studs further when it fires, which seals that corridor edge to edge for the 0.6-second hold of a
3.2-second period. The spring (side +9.49 to +20.45, 3.92 to 6.89 studs above the deck) stands
between the ledge and the base, so the base is never a quiet walk-around: a jump out to it passes
through the spring, and the spring is itself a Shove owner.

### Log-rolls: the frame was a ladder, so the frame had to go

The new **LogRoll** preset turns a barrel about its own measured long axis with `RotorCarries` and
`Shove` — section 6's "spin along long axis + Shove + Carries on actual ride surface; not an
unanchored physics barrel". Section 6 allows either of the kit's rolling shapes, and **which one
matters enormously on a stacked course.**

The first build used `obstacle_2_001`, the framed spiked roller. Its cradle stands **32.284 studs
tall above its own mount**, and the cut-set audit measured the consequence exactly: standable cells
on the frame at Y 28 and Y 41 above a run-2 deck at Y 24, then a jump from the frame top straight
onto beat 06's ramp at Y 53 — **three beats skipped, and both the 05 and 06 gates bypassed by all 30
spawn cells.** A 32-stud structure standing on a lower storey of a tower is a ladder, not a hazard
frame. This is Tumble Tunnels' "stacked stock geometry becomes a staircase" lesson in a fourth form.

`obstacle_10_001` is the kit's other rolling shape and 01-asset-inventory.md already lists it as a
log-roll candidate: a **single mesh with no frame at all**, 6.1188 across and 13.9774 long in its own
local Y. It lies on its side with a quarter turn of pitch plus a quarter turn of yaw so its long axis
crosses the lane, and spins about its own local Y. Its Support socket is its **axle**, not an
underside — a roller lying on its side has no underside — so `OffsetUp` reads directly as "how far
the axle sits above the deck".

| Roller | Scale | Length across the lane | Diameter | Top above deck | Buried below deck | Deck thickness | Overhang each side of the 10.710 tread | Spin |
|---|---|---|---|---|---|---|---|---|
| Roll01 | 1.20 | 16.77 | 7.34 | +4.67 | 2.67 | 2.70 | 3.03 | +530 deg/s |
| Roll02 | 0.85 | 11.88 | 5.20 | +3.90 | 1.30 | 2.70 | 0.58 | -745 deg/s |

Measured on the built model: Roll01 spans Y 15.33-22.67 over a Y-18 tread and Z 11.61-28.39; Roll02
spans Y 22.70-27.90 over a Y-24 tread and Z 14.06-25.94. Both tops are past the roughly 2-stud
auto-step, so neither can be walked over; both are longer than the tread they cross, so neither can
be walked around; both stay inside their deck's own 2.70-stud thickness, so nothing hangs through the
floor; and **the tallest point of either roller is 4.67 studs above its deck**, far too low to climb
towards the storey above. Speeds are the section 6 formula
`ceil((33.8 * 180 / (pi * r)) / 5) * 5` at the measured crossing radius (3.0594 * scale), signed
opposite.

### Pad launches are necessary, not decorative

HANDOFF 3.2's constants give an ordinary jump `sqrt(2 * 120 * 10) = 48.99` studs/s and a measured
22-stud flat gap against this model's own 21.229 prediction, so the calibration is 0.7711 studs.
Over the +6 rise each pad climbs, an ordinary jump reaches **18.099** studs.

`trampoline_2_001` at 0.5 is 6.192 studs across. The kit launches wherever the runner steps on, so a
pad set back from the edge silently lengthens the crossing (Tiptoe Trials' lesson 4). Both pads are
mounted **centred on their deck's exit edge**, so the worst launch point is half a pad
(`3.096` studs) back and the worst-case flight is `gap + 3.096`:

| Launch | Pad | Gap | Rise | Ordinary jump | Worst-case flight | Pad reach | Margin over ordinary | Margin under reach |
|---|---|---|---|---|---|---|---|---|
| Hop01 | 48 / 0.2 | 19.000 | +6 | 18.099 | 22.096 | 22.963 | 0.901 | 0.867 |
| Hop02 | 52 / 0.2 | 20.500 | +6 | 18.099 | 23.596 | 25.524 | 2.401 | 1.928 |

A runner who walks around the pad and jumps from the bare deck edge faces 19.0 or 20.5 studs over a
+6 rise and cannot make either. Neither pad can overshoot into the next beat: the landings are
14.493 studs long and the longest overshoot is 5.0 studs.

## Loophole table

Section 11 step 1's five questions, per encounter. The first four must be NO. A timed jump *through*
the intended gate is legal; jumping past the beat is not. A safe-wait YES must have a measured cost.

| Encounter | Walk-around | Edge-hug | Bypass-jump | Launched-past | Safe-wait |
|---|---|---|---|---|---|
| Belt01 (-13) | NO — the 8.946-stud belt is the whole lane; either side is open liquid | NO — no strip beside it | NO — 17.891 studs of belt with no gap to clear | NO — no launch tool in beat 01 | YES, free: standing still on a counter-belt carries you backwards, so waiting costs ground |
| Belt02 (-15.6) | NO — same | NO | NO | NO | YES, costs ground |
| Belt03 (-18.2) | NO — same | NO | NO | NO | YES, costs ground |
| Switchback chicane (cube + wedge) | NO — the two slabs stagger across a 14.103-stud landing leaving 6.26 and 4.88-stud lines on opposite sides | NO — the wedge overhangs the deck's far edge | NO — 3.5 and 10.5 studs apart along the route, inside one stride | NO | NO — both slabs are static |
| Roll01 (+530) | NO — 16.77 studs of barrel across a 10.710-stud tread, 3.03 studs proud on each side | NO — the tread is the whole lane and the barrel outreaches it | NO — the 4.67-stud crest is past the auto-step | NO — no launch in beat 02 | YES, measured: the barrel never stops, so waiting costs the whole wait |
| Roll02 (-745) | NO — 11.88 studs of barrel, 0.58 proud on each side | NO | NO — 3.90-stud crest | NO | YES, same |
| Seesaw01 | NO — the plank is the only crossing of the 25.091-stud cross slot; both sides are open water | NO — 11.604 studs wide with no rim | NO — 25.091 studs is past the 22-stud flat jump, and the 14.909-wide corner decks either side leave no line past the plank | NO | YES, free: the board settles level in about two seconds, so waiting is the easy line and costs that time |
| Slope chicane (3 bumpers) | NO — three slabs stagger across a 17.399-stud tread at sides -4.5 / +4.0 / -4.0 | NO — each slab reaches past the deck edge on its own side | NO — 5 studs apart along the route | NO — no launch in beat 04 | NO — static |
| Foam01 | NO — the volume spans the tread's full 17 studs | NO | NO — 17 studs of foam inside one deck, no gap to jump | NO | NO — a forced lane, not a detour |
| Pad01 (48) | NO — the deck-edge alternative is a 19.0-stud gap over +6 against an 18.099-stud jump | NO | NO — see above | NO | YES, free: nothing moves, but the gap cannot be crossed without the pad |
| Pad02 (52) | NO — 20.500 studs over +6 | NO | NO | NO | YES, free |
| LandingBumper | NO — 7.174 studs on a 14.600-stud landing leaves 3.71 studs each side, and the runner arrives under launch rather than walking in | NO | NO | NO | NO — static |
| Piston01 (phase 0) | NO — the head seals the 8.765-stud ledge edge to edge on the punch and the base sits over open liquid behind its own spring | NO — the seal at full extension covers edge to edge | NO — the ledge is 11.008 studs of continuous deck | NO — no launch on this run | YES, measured: a 4.96-stud corridor at rest, closed for the 0.6 s hold of a 3.2 s period, so waiting costs up to 0.6 s per piston |
| Piston02 (phase 1.05) | NO — same, mirrored | NO | NO | NO | YES, same |
| Piston03 (phase 2.1) | NO — same | NO | NO | NO | YES, same |

Safe-wait is YES for the periodic hazards and free at the belts, which HANDOFF 8.2.9 allows only
because waiting delays the finish — on this course it also lets the flood catch up, since the liquid
is still rising until 115 s.

## Top-down schematic

Generated from the guide and the measured run profiles. `A` is the `Z = -20` column, `B` is `Z = +20`.

~~~text
                 X=-120      -64    -49      0       +55    +92
   Z=+20  B            . . . 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4        run 4  Y36->54
                       . 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 .            run 2  Y12->24
                             ^turn4        turn2^      ^turn1/3
   Z=-20  A   [START] 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1                run 1  Y0 ->12
                       . . 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3        run 3  Y24->36
                       . . . . 5 5 5 5 5 5 5 5 5 5 5 5 5 [FIN]      run 5  Y54->66

   side view (looking along +Z), column A:
        Y66  ---------------------------- run 5 finish lane + arch
        Y60  ------------- piston ledge (3 pistons, 4.96-stud corridor)
        Y54  -------------- run 4 top / turn 4 --------
        Y36  ------------------- run 3 ---
        Y24  ---------- run 2 top --------
        Y12  ---------------- run 1 top --
        Y 8  ~~~~~~ flood stops here ~~~~~
        Y 0  [start plaza]
        Y-30 ~~~~~~ flood starts here ~~~~
~~~

## Measured QA result

`CourseQA.check` over the built model, published to `evidence/courses/PistonPeak/qa.json`:
**zero errors and ZERO WARNINGS; 50 findings PASS, 11 NOT RUN with reasons, 0 FAIL.** Status is
BLOCKED, which is the only status this suite ever returns while the live-playtest items are
outstanding — it never reports PASS from an absence of data.

Measured counts: 162 BaseParts, 7 beats, 6 checkpoints, 30 start pads, 24 boundary walls, 15
encounters, 2 launch sources, **15,945 real surface cells sampled into a 13,886-node /
1,854,187-edge walkable graph**, and all twelve cross-course checks run over the six staged specs.
All seven beat gates are true cut sets (0 of 30 spawn cells bypass any of them) and every one of the
30 spawn cells reaches all six checkpoints and the finish in order.

Studio TestEZ (`places/arena/tests/Assets/SplashdownQA.spec.luau`): **20 passed, 0 failed, 0
skipped** — the 17 existing assertions plus three new ones this course added: the piston-head reach
test, the log-roll frame-height test, and the rising-liquid flood regression.

### Two defects this course found in the shared QA tools

Both were real bugs in code every course shares, not anything specific to Piston Peak:

1. **`CourseQA.sampleSurfaces` only ever sampled one storey per column.** A column was sampled once
   — which is what keeps the pass tractable — but over the vertical window of whichever *part*
   claimed the column first. On a flat course nothing is stacked, so it never mattered. On this tower
   the first run's slab claimed the column and the four storeys above it, including the climax ledge,
   were never sampled at all; the audit then reported the route unreachable because the cells did not
   exist. The window is now the whole model's vertical extent and the per-column stacked-surface
   budget went from 12 to 24. Surface cells went from 11,074 to 15,945 for this course, and every
   course's graph is more complete for it.
2. **`CourseGraph.edgeCutByGate` walked every edge at half-stud resolution for every gate.** With a
   five-storey graph at 1.85 million edges that exhausted Studio's execution budget outright. It now
   rejects on an axis-aligned bounding-box test first, which cannot change any verdict — an edge
   outside the box cannot have a sample inside it — and `reachingNodes` takes an optional cooperative
   yield that the engine caller supplies and the headless graph tests do not.

## QA links

Final spec hash **`e164c528`**, promoted to `ReplicatedStorage.Assets.Maps.Splashdown.PistonPeak`
(327 descendants).

- `docs/splashdown/evidence/courses/PistonPeak/qa.json`
- `docs/splashdown/evidence/courses/PistonPeak/top-down.png`
- `docs/splashdown/evidence/courses/PistonPeak/three-quarter.png`
- camera CFrames in `docs/splashdown/evidence/course-cameras.json`

## Manual checklist

Filled in from the real Studio session; anything not run stays NOT RUN.

- [x] Piston head height AND lateral sweep measured on the built model, not inferred
- [x] Log-roll barrel geometry measured on the built model, including its height above the deck
- [x] Rising-liquid schedule resolved through the real `RisingLiquid.resolve`
- [x] Flood clearance measured against the lowest checkpoint the route places
- [x] Deterministic rebuild: identical spec hash, part count and descendant count
- [x] Both fixed cameras captured and inspected against `bad-map-refs/1,9,10,11.png`
- [ ] Scripted expert/mid trials — NOT COMPLETED (standing user decision, 2026-09-16)
- [ ] Deliberate missed-timing contacts at every encounter — NOT RUN
- [ ] One interactive keyboard run — NOT RUN
- [ ] Checkpoint recovery run — NOT RUN
- [ ] Studio local multi-client session — NOT RUN
