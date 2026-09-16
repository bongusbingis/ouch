# Tiptoe Trials

Course document for HANDOFF.md section 7.5, written to the section 11 per-course loop. Every number
below that is labelled measured comes from `evidence/courses/TiptoeTrials/build.json` or `qa.json`,
both produced by the real builder and the real audit against a live Studio clone. Planned numbers are
labelled planned. Items that need a driven playtest are recorded NOT COMPLETED with the reason, never
as an implied pass.

## Concept and headline

Nine rock islands in open water, stepping inward from a perimeter start plaza to a finish island at
the map's centre. There is no continuous floor anywhere in the course: the only ways from one island
to the next are a fan launch, five bridges of three falling tiles, and two jump-pad launches. That is
the headline HANDOFF 7.5 asks for — "falling-tile islands, never a permanently destroyed checkpoint
route" — and falling tiles appear in no other course in the set.

Every tile ships `RespawnSeconds = 3` and `CriticalRoute = true`. `AttributeAudit` rejects a
never-respawning critical tile outright, and the engine test below drives the real `FallingTiles` kit
over the built model to prove the tiles arm, drop and come back rather than merely looking present.

The course is a tightrope, not a brawl. Its lanes are the narrowest in the set — a 4.50-stud tile, a
5.59-stud seesaw board, a 7.01-stud approach lane — and its one shove-heavy beat is the climax, where
a large and a small hammer hang between three tile bridges.

## Layout: Archipelago

HANDOFF 5.2: "Islands placed radially around the origin; start at the perimeter and finish at the
centre island (or the reverse if the measured launch envelopes fit better); consecutive islands are
linked only by the beat's launch or tile group; non-consecutive islands are separated by more than the
maximum measured launch reach."

This is the fifth layout kind in `CourseBuilder` (after Serpentine, Spiral, Chute and Loop) and the
first with no guide polyline at all. An archipelago's guide IS its island list: every island declares
its own polar anchor and the route has to arrive exactly there, which constrains the build far more
tightly than a length cap along a polyline would. The builder enforces six invariants:

1. at least five islands, entered once each in declared order;
2. anchor radii strictly monotone from the declared perimeter to the declared centre;
3. every island after the first is entered by a MEASURED crossing that is either a **launch** — longer
   than the ordinary jump for its own rise, no longer than what its own fan or pad reaches over that
   rise, and preceded by that tool on the island it leaves — or a **tile group**, a flush arrival at
   the far end of at least two chained falling tiles;
4. every island after the first begins on a round landing deck, because a round deck is what absorbs a
   heading change with no wedge seam (the same reason Whirlpool Waltz's spiral turns across ride decks);
5. every heading change happens on such a deck and is at most `MaxTurnDegrees`; and
6. the route on any two NON-consecutive islands stays further apart than the worst launch this course
   can produce, measured polyline to polyline and reduced by the measured lateral half-width of the
   pieces at that approach.

### Reaches are derived, not declared

Nothing in this spec states "this gap is jumpable". The spec declares HANDOFF 3.2's measured movement
constants — gravity 120, WalkSpeed 26, JumpHeight 10 with `UseJumpPower=false` — and the builder
solves the ballistic problem for each crossing's own rise:

    reach(v, g, rise) = WalkSpeed * (v + sqrt(v^2 - 2*g*rise)) / g + calibration

with `v = sqrt(2 * 120 * 10) = 48.99` for an ordinary jump and `g = 120 * (1 - FloatFactor)` for a
launch. The model predicts 21.23 studs for a flat ordinary jump against the measured 22, so the
0.7711-stud difference is the avatar's own body extent and is added back to every reach. A crossing
that a plain jump could make is rejected as a decorative launch; a crossing past the tool's own reach
is rejected as unreachable.

**Measured, from `build.json`:** the worst launch this course can produce is **38.89 studs** — a 54/0.20
pad over the largest drop between any two of its islands (24 studs). The worst measured separation
between two non-consecutive islands is **53.02 studs** (LastFade to Finish). Nothing can be launched
off the chain.

This is a computed envelope from measured constants, corroborated by the audit's own independent
launch-edge pass over the sampled surface graph. It is NOT a live-rig trial; see the outstanding items.

### Islands, as built

Anchors are the point the route arrives at, in polar coordinates about the course origin. Measured.

| # | Island | Angle | Radius | Y | Entered by | Measured crossing | Rise |
|---|---|---|---|---|---|---|---|
| 1 | Shore | 269.805 | 267.42 | 0 | start plaza | 0.011 | 0 |
| 2 | Balance | 250.254 | 261.87 | 12 | **fan launch** | **20.500** | +6 |
| 3 | Midhop | 204.605 | 219.91 | 12 | tile group A | 0.000 | 0 |
| 4 | Spire | 191.101 | 213.98 | 12 | tile group B | 0.000 | 0 |
| 5 | FirstFade | 131.490 | 185.49 | 18 | tile group C | 0.001 | 0 |
| 6 | SecondFade | 114.084 | 177.94 | 18 | tile group D | 0.000 | 0 |
| 7 | LastFade | 93.878 | 119.56 | 24 | tile group E | 0.000 | 0 |
| 8 | PadRock | 76.355 | 35.94 | 21 | **pad launch 51** | **26.000** | -3 |
| 9 | Finish | 280.633 | 17.96 | 18 | **pad launch 54** | **27.500** | -3 |

Radii fall 267.42 → 17.96 without one reversal. The tile links arrive flush to within a thousandth of
a stud, which is the builder's own tolerance for calling a tile group a bridge rather than a gap.

### The three launches, measured against their own envelopes

| Launch | Tool | Rise | Ordinary jump reaches | This launch reaches | Crossing | Margin over jump | Margin under reach |
|---|---|---|---|---|---|---|---|
| Shore → Balance | fan 48 / 0.20 | +6 | 18.10 | 22.96 | 20.50 | +2.40 | 2.46 |
| LastFade → PadRock | pad 51 / 0.20 | -3 | 23.49 | 29.85 | 26.00 | +2.51 | 3.85 |
| PadRock → Finish | pad 54 / 0.20 | -3 | 23.49 | 31.40 | 27.50 | +4.01 | 3.90 |

Every crossing is out of reach of an ordinary jump and inside its own launch's envelope, so each tool
is load-bearing rather than decorative. The landing deck beyond each anchor is 25.7 to 29.4 studs
long, so the numbers above are the MINIMUM reach; a longer flight simply lands further onto the rock.

**The fan stands in the water, seven studs past the shore's launch edge.** Section 6 fixes the fan at
scale 0.5, LaunchSpeed 48 and Float 0.2, and at that setting the measured column is a 6.19-stud-radius
cylinder about the fan's own axis. The kit launches a runner the instant they enter that column. Had
the fan been mounted back on the deck the way Ball Barrage mounts its own, the launch would fire 6.19
studs BEFORE the island's edge and the flight would need 26.69 studs of reach against the 22.96 it
makes over a 6-stud rise — it would fall short every time. Out in the water the column's near edge
sits 0.81 studs past the shore, so the runner has to leave the island before it fires and the crossing
it has to make is exactly the measured 20.50.

## Beats

Targets are the scaled section 7.5 targets recorded in `docs/splashdown/03-overrides.md`
(121 / 132 / 110 / 132 / 253 / 132, summing to the set-wide 880). Measured arclength and elevation are
from `build.json`.

| Beat | Family / mechanic | Target | Measured | Ratio | Elevation | Primary encounters |
|---|---|---|---|---|---|---|
| 01_FloatFlight | Launch / FloatLanding | 121 | 119.420 | 0.987 | +12 | 1 fan onto the first island, 1 forced bumper at the landing |
| 02_BalanceBay | Ride / LoadBalance | 132 | 132.329 | 1.002 | -6 | 2 seesaws, obstacle_25 and the opposing obstacle_11 plank, both max tilt 22 |
| 03_IslandHop | Precision / TileSteppingStones | 110 | 121.711 | 1.106 | +6 | 2 tile groups of 3 across a gap chain, 1 two-arm cross between them |
| 04_StepSpire | Climb/Descend / SteppedAscent | 132 | 138.597 | 1.050 | +12 | 1 mace over three stepped ramps |
| 05_FadeFooting | Precision / TileIslands | 253 | 235.129 | 0.929 | 0 (-6 then +6) | 3 tile groups of 3 at delays .75/.65/.55, separated by a large hammer, a small hammer and a swing panel |
| 06_LastDash | Launch / PadFinish | 132 | 133.220 | 1.009 | -6 | 2 pads at 51 and 54 onto a wide finish island, no hazard |

Total measured route: **880.406 studs** against the 880 set-wide target. Every ratio is inside the
0.85-1.15 window HANDOFF 5.2 allows. Elevation per beat matches section 7.5 exactly: +12, -6, +6, +12,
0 (as -6 then +6), -6, finishing at Y 18 from StartY 0.

Beat 05 is the climax and carries six encounters against beat 06's two, so the final sprint is short
and easier as HANDOFF 3.2 requires.

## Encounters

16 encounters, exactly the section 7.5 table. A tile group is one encounter ("each tile group between
two stable landings"), shared through an `EncounterGroup`; the fifteen individual tiles are reported
as instances and never scored.

| # | Beat | Encounter | Type | Source / scale | Tuning |
|---|---|---|---|---|---|
| 1 | 01 | Fan01 | Fan | propeller_trampoline_1_001 @ 0.5 | upward, LaunchSpeed 48, Float 0.2, standing in the liquid 7 studs off the shore |
| 2 | 01 | Bumper01 | Bumper | obstacle_18_001 @ 0.5 | shove 54 / up 22 / hold 0.26, 2.2 studs off the centre of a 7.01-stud lane |
| 3 | 02 | Seesaw01 | Seesaw | obstacle_25_001 @ 0.6 | axis X, MaxTilt 22, response 3, on a platform_002 plinth from the liquid |
| 4 | 02 | Seesaw02 | Seesaw | obstacle_11_001 @ 0.5 reversed | axis X, MaxTilt 22, response 3, on a single door_003 pier |
| 5 | 03 | TileA | FallingTile | color_box_001/002/003 @ 0.25 | drop 0.65, respawn 3, CriticalRoute |
| 6 | 03 | TwoArm01 | RotorBump | obstacle_27_001 @ 0.5 | Y-spin 135 deg/s at the measured 14.52-stud contact radius, shove 48 |
| 7 | 03 | TileB | FallingTile | color_box_004/005/006 @ 0.25 | drop 0.65, respawn 3, CriticalRoute |
| 8 | 04 | Mace01 | RotorBump | obstacle_5_001 @ 0.7 | rock Z, amplitude 45, period 3.2, hung 21 studs over the middle step |
| 9 | 05 | TileC | FallingTile | color_box_007/008/001 @ 0.25 | drop 0.75, respawn 3, CriticalRoute |
| 10 | 05 | HammerLarge | RotorBump | obstacle_3_001 @ 0.6 | hammer profile, amplitude 55, windup 1.8, strike 0.3, shove 58, axle 20.09 above the deck |
| 11 | 05 | TileD | FallingTile | color_box_002/003/004 @ 0.25 | drop 0.65, respawn 3, CriticalRoute |
| 12 | 05 | HammerSmall | RotorBump | obstacle_4_001 @ 0.6 | same profile, phase 0.7, axle 20.19 above the deck |
| 13 | 05 | TileE | FallingTile | color_box_005/006/007 @ 0.25 | drop 0.55, respawn 3, CriticalRoute |
| 14 | 05 | SwingPanel01 | RotorBump | obstacle_8_001 @ 0.5 | panel rock X, amplitude 28, period 2.8, phase 0.6, raised 5 on an open island deck |
| 15 | 06 | Pad01 | JumpPad | trampoline_5_001 @ 0.5 | LaunchSpeed 51, Float 0.2, inner child trampoline_6_001 |
| 16 | 06 | Pad02 | JumpPad | trampoline_5_001 @ 0.5 | LaunchSpeed 54, Float 0.2 |

**Measured by `auditVariety`:** 6 distinct encounter types (FallingTile, RotorBump, Seesaw, JumpPad,
Fan, Bumper); 4 distinct families (Launch, Ride, Precision, Climb/Descend); the dominant type is
FallingTile at 5 of 16 = 31.2 %, under the 40 % cap; the longest same-type run is 2, under the cap of
3. Per-instance counts, reported and never scored: 15 falling tiles, 2 seesaw boards, 2 jump pads,
1 fan, 1 bumper, 5 rotor hazards, 160 BaseParts in total.

### Cross-course rules (override 2)

All twelve cross-course checks pass over the five staged specs. Falling tiles are declared this
course's headline and occur in no other course. Of the capped non-glue mechanics, this course uses
seesaws (2 of the allowed 3 courses, with Tumble Tunnels), fans (3 of 3, with Ball Barrage and Tumble
Tunnels) and falling tiles (1 of 3). No beat shares a family + mechanic + recipe with another course:
the two mechanics that do recur are posed differently — the mace is a single pendulum over a stepped
ascent where Door Dash pairs two over a narrowing flat lane, and the swing panel rocks at phase 0.6 on
an open island deck where Tumble Tunnels' rocks at 1.4 inside a tunnel.

## Measured geometry the build depends on

All from real Studio raycast sweeps on disposable clones, recorded in `AssetManifest` version 5 and in
`evidence/course-sockets-tiptoetrials.json`.

| Source | Measurement | Consequence |
|---|---|---|
| color_box_001..008 | 18.6366 x 9.3183 x 27.9549; flat top at +4.6592 over \|x\| <= 8.50 and \|z\| <= 13.00; measured footprint \|x\| <= 9.00, \|z\| <= 13.75; 7,241 of 8,070 standable returns on the plateau. All eight are one mesh in eight colours: 002, 005 and 008 were swept independently and returned identical extents | at 0.25 a tile is 4.50 studs of walkable width and 6.875 of travel, so a group of three bridges 20.625 studs |
| trampoline_5_001 | 14.2431 x 2.9962 x 14.2430, lowest collision point -1.4980, inner child trampoline_6_001 at (0, 1.3956, 0) | the pad is 7.12 studs across at 0.5 on a 12.61-stud lane, so an avatar cannot pass beside it |
| obstacle_11_001 | root is a 38.73-stud bar long in X whose ridge returned 1.5566 to 2.3896 over \|z\| <= 1.50 — the fulcrum; child plank (a second, larger casting of the conveyor mesh, id ...982207, NOT obstacle_9_001) top 0.4199 to 0.9482 over \|x\| <= 17.00, \|z\| <= 37.50; assembly's lowest point -2.3896 | axle is local X like obstacle_25's; at 0.5 the plank is 17.34 wide over 37.5 of travel, and its underside clears the bar's base only within \|z\| <= 2.127 |
| water_platform_001 (already measured) | 37.2731 across, usable ride radius 18.36, top at +4.7031 | the island landing decks, at 0.40 to 0.85 |

### Why the obstacle_11 seesaw stands on a door panel

obstacle_25 sits on a broad platform_002 plinth because its board top is 16.22 studs above its
pedestal's base and the board only dips 5.17 studs at MaxTilt 22 — it never reaches the plinth.
obstacle_11 is the opposite shape: its plank's top is only 3.34 studs above the fulcrum bar's
underside, so at 22 degrees the plank clears the bar's base only within 2.127 studs of the axle. A
platform_002 plinth tall enough to reach the water is 40 studs long and the plank would hit it on
every tilt. A door panel is 6.2765 studs thick at scale 1, so at the 0.269 the 12.33-stud height needs
it is **1.69 studs thick and 20.24 wide** — narrower than the clearance and the same width as the bar
it carries. It is a `Prop` in Geometry with no Door attributes, invisible to `DoorRows.resolve` and to
`MapFeatureService`, exactly as Tumble Tunnels' enclosure panel is.

### Why both hammers hang

obstacle_3_001 and obstacle_4_001 are axle housings with their heads suspended 16.85 and 16.35 studs
BENEATH them. Mounted with their Support on the deck — the pilot's own mounting — the head sweeps
entirely below the lane and can never touch a runner, which HANDOFF 8.4 would flag as a hazard that
never contacts anybody. HANDOFF 8.3 explicitly exempts a suspended pendulum from the support rule
("suspended mace links are supported by their chain and axle, not required to touch a floor") and Door
Dash already hangs its maces at OffsetUp 21 on that basis. These two hang at the height that puts the
head's resting bottom 0.6 studs clear of the deck: at rest the head blocks the lane from deck level to
19 studs up, and past +-42 degrees of its 55-degree amplitude the whole head is above 8.9 studs, which
is the readable window.

## Loophole table

HANDOFF section 11 step 1's five questions, verbatim, per encounter. The first four must be NO; a
timed jump THROUGH the intended gate is legal, jumping past the beat is not; a YES on safe-wait must
have a measured time cost.

| Encounter | walk-around | edge-hug | bypass-jump | launched-past | safe-wait |
|---|---|---|---|---|---|
| Fan01 | NO — the fan's column is the only way off Shore; the island ends 0.81 studs before it and there is 20.50 studs of open water beyond | NO — the launch deck is 14.01 studs wide with liquid on both sides, and the column is 12.38 studs across it | NO — an ordinary jump reaches 18.10 studs over this beat's 6-stud rise, 2.40 short of the crossing | NO — this IS the launch, and the only earlier launch does not exist | YES — the fan has a 0.75-second retrigger cooldown, so re-entering the column costs seconds and does not avoid it |
| Bumper01 | NO — the bumper is 7.17 studs across a 7.01-stud lane, set 2.2 studs off centre; the free strip measures 2.12 studs, under the avatar's own width | NO — the 2.12-stud strip is bounded by the lane edge and open water | NO — a jump over it lands on the same 7.01-stud lane, still inside its footprint | NO — the beat's own fan launch lands 26 studs earlier, on the far side of the landing rock | NO — the bumper is static; there is no window to wait for |
| Seesaw01 | NO — the board is the only floor across its 27.6 studs | NO — the board is 5.59 studs wide with open water both sides | NO — 27.6 studs is past the measured 22-stud maximum jump | NO — no launch in this course reaches beat 02 | YES — waiting for the board to level costs time; it returns to level in about 2 seconds empty |
| Seesaw02 | NO — same, on the other board form | NO — the plank is 17.34 wide but both ends are over open water and it tilts underfoot | NO — 37.5 studs is far past the 22-stud maximum | NO — same | YES — same, on a plank three times as long |
| TileA | NO — the three tiles are the only floor across 20.625 studs of water | NO — a tile is 4.50 studs wide; there is no strip beside it | NO — 20.625 studs is inside the 22-stud jump ONLY when all three tiles are already gone, which is a legal skill line through the gate, not past it | NO — no launch reaches beat 03 | YES — each tile respawns 3 seconds after it drops, so waiting out a dropped bridge costs 3 seconds and cannot strand anyone |
| TwoArm01 | NO — the 29.04-stud bar sweeps a 31.68-stud rock; the exposed rim is 1.32 studs | NO — the rim is narrower than the avatar and ends in water | NO — the bar spins 3.09 studs above the deck, inside the jump envelope | NO — no launch reaches beat 03 | YES — 135 deg/s gives two windows per revolution, each costing about a second to wait for |
| TileB | NO, NO, NO — as TileA | | | NO | YES — as TileA |
| Mace01 | NO — the ball swings +-14.85 studs laterally across an 8.41-stud deck | NO — the deck is 8.41 studs wide with water on both sides | NO — the chain sweeps through the jump envelope rather than under it | NO — no launch reaches beat 04 | YES — the 3.2-second period gives a readable window that costs time to take |
| TileC / TileD / TileE | NO, NO, NO — as TileA, at drop delays 0.75, 0.65 and 0.55 | | | NO — beat 06's pads are 200+ studs further on | YES — 3-second respawn, as TileA |
| HammerLarge | NO — the head is 11.12 studs wide across a 12.61-stud lane and at rest reaches from 0.6 to 19.3 studs above it | NO — 0.74 studs of lane each side of the head, under the avatar's width | NO — the head sweeps vertically through the jump envelope | NO — no launch reaches beat 05 | YES — past +-42 degrees of its 55-degree amplitude the lane is clear below 8.9 studs; the 1.8-second windup is the cost |
| HammerSmall | NO — same, 8.23 studs of head across the same lane, phased 0.7 against the large one | NO — same | NO — same | NO — same | YES — same, half a cycle out of phase |
| SwingPanel01 | NO — the panel is 19.63 studs across a 20.50-stud rock | NO — 0.44 studs each side | NO — the panel rocks through the jump envelope at amplitude 28 | NO — the beat 06 pads are ahead of it, not behind | YES — the 2.8-second period gives a readable window |
| Pad01 | NO — the pad is 7.12 studs across a 12.61-stud lane; stepping past it leaves a 26-stud crossing an ordinary jump cannot make (23.49) | NO — the lane ends in water 6 studs past the pad | NO — 26.00 studs is 2.51 past the ordinary jump for this drop | NO — nothing launches into this beat from behind | YES — the pad has a 0.15-second retrigger cooldown; hesitating costs time and does not avoid it |
| Pad02 | NO — the landing rock is a dead end: the crossing beyond it is 27.50 studs against a 23.49 jump | NO — the rock is circular and every line off it crosses the same water | NO — 27.50 studs is 4.01 past the ordinary jump | NO — the only launch that reaches PadRock is Pad01, which lands ON it | YES — same cooldown |
| Island chain as a whole | n/a | n/a | n/a | **NO — the worst launch this course can produce reaches 38.89 studs and the closest two non-consecutive islands come within 53.02** | n/a |

## Automated QA — measured

`CourseQA.check` on a real Workspace clone, 1-stud sampling, refined to 0.25 at gates and ledges.
Full report in `evidence/courses/TiptoeTrials/qa.json`.

- **Status BLOCKED, 0 errors, 0 warnings.** BLOCKED rather than PASS because ten live-playtest items
  are outstanding; the audit never reports PASS while anything is NOT RUN.
- 45 findings PASS, 10 NOT RUN with reasons, 0 FAIL.
- 16,171 sampled surface cells; 14,680 graph nodes; 1,309,689 edges.
- **All six gate cut sets hold: 0 of 30 spawn cells bypass any gate.**
- Ordered route from every spawn: 30 spawn cells, 6 ordered waypoints, **0 failing legs**.
- 30 start pads, 5 ordered checkpoints, 1 finish, 24 boundary walls at radius 390.
- Largest flat hazard-free square on the route: **23 x 23 studs**, under the 24-stud limit. This is the
  tightest margin in the set and it is the Midhop landing rock, which at 0.85 is 31.68 studs across.
- Bounds: worst part corner 501.79 of 600; worst geometry centre radius 273.92 of 380; worst route
  radius 267.42 of the declared 300; static route envelope Y -22.00 to +62.00 inside the -30..90 band.
- Rebuild parity: two builds from identical spec and sources in one Edit session produced the same
  spec hash `0f8e9510` and the same 160 BaseParts.

### New in the audit, because this course needed it

`CourseQA.buildGraph` previously modelled only Walk and ordinary Jump edges, so a 26-stud pad launch
simply did not exist in the graph and the first audit of this course reported the Checkpoint05 →
Finish leg unreachable. HANDOFF 8.2.5 asks for exactly the missing pass — "Launch edges use
individually measured fan/pad/ball trajectories and maximum reachable envelope" — so the audit now
reads every launch tool off the BUILT model (its own LaunchSpeed, FloatFactor and measured footprint),
recomputes the reach for every candidate landing height, and adds Launch edges about the tool's own
axis. That is what makes the six gate cut sets above a statement about launches too, and it applies to
every course from now on, not only this one. A horizontal fan is excluded and reported by name,
because a ball-pushing corridor fan is not a ballistic launcher.

`ENCOUNTER_TYPES` also gained `FallingTile`; without it the variety audit scored this course at 11
encounters and five types instead of the 16 and six that section 7.5 specifies.

## Engine tests (Studio TestEZ)

`places/arena/tests/Assets/SplashdownQA.spec.luau`, run through `run-course-qa.server.luau` in a real
Play session. Results recorded in the section 1.4 handoff note.

New in this course's pass: **"hands its falling tiles to the kit as real armable, droppable,
respawning tiles."** The Door Dash door-slab defect and the Tumble Tunnels beach-ball check both taught
the same lesson — a kit that cannot see its own parts produces geometry that looks perfect in a preview
and in the audit while the mechanic is silently gone. This test asserts every tile is authored
anchored and colliding, carries `CriticalRoute` with a positive `RespawnSeconds` and a numeric
`DropDelaySeconds`, has no competing motion owner, and sits under `Rotating/<group>/Assembly` at the
depth `FeatureParts.collect` actually scans. It then drives the REAL `FallingTiles` kit: registers the
tiles, arms one through the kit's own downward support raycast from a probe root, confirms the tile is
still solid halfway through its countdown, confirms it loses collision, query and visibility when the
countdown expires, and confirms it comes back after `RespawnSeconds`.

## Fixed cameras, compared against the bad references

Both captures are real window grabs of the Edit viewport with the camera posed through
`workspace.CurrentCamera` at the section 8.6 poses relative to MapOrigin, at a recorded 70-degree FOV.
The preview was lifted 9,000 studs so the arena floor could not clip into the frame; the arena itself
was never moved.

- `top-down.png` — position MapOrigin + (0, 520, 1), lookAt MapOrigin + (0, 20, 0), FOV 70.
- `three-quarter.png` — position MapOrigin + (300, 260, 300), lookAt MapOrigin + (0, 20, 0), FOV 70.

Inspected against the four bad references:

- **1.png** is a vast flat pink field with decorative discs sprinkled over it and duplicated identical
  slab pairs. This course has no field: the top-down shows nine separate rocks with open water between
  every one of them, and the measured largest hazard-free flat square is 23 x 23.
- **9.png** repeats one swing-panel prop five times down a straight lane with a wide pink shoulder
  either side. Nothing here repeats: the longest same-type encounter run measures 2, and no lane has a
  shoulder — the widest walkable surface off the route centre line is 15.84 studs and it is a landing
  rock, not a bypass.
- **10.png** is broad empty decking with a few small props on it. Every island in this course carries
  either the encounter the beat is about or the landing a launch has to hit; the three-quarter capture
  shows no unused deck.
- **11.png** is an enormous empty plaza with one isolated bumper and arched walkways routing around
  everything. This course's one bumper sits in a 7.01-stud lane with a 2.12-stud free strip, and there
  is no walkway anywhere — the cut-set audit proves 0 of 30 spawn cells reach the finish around any
  gate.

Reference 2 is the Summit readability bar; the readability check itself is NOT RUN (see below).

## Outstanding — NOT RUN / NOT COMPLETED

Recorded plainly, never estimated.

| Item | State | Reason |
|---|---|---|
| 8.5 scripted expert/mid route trials | **NOT COMPLETED** | The route harness has no wall-clock budget of its own and did not return on the previous course after 3.5 hours. Per the user's standing 2026-09-16 decision this category is reported plainly and not chased. No trial numbers are claimed. |
| 8.5 interactive keyboard run | NOT RUN | Needs a human operator at the keyboard. |
| 8.5 deliberate missed-timing contacts | NOT RUN | Same; each needs a real Player, and `Instance.new("Player")` is forbidden. |
| 8.5 checkpoint recovery run | NOT RUN | Same. |
| 8.5 thirty-rider load and Studio local multi-client | NOT RUN | Same. |
| 8.4 blocked-fraction, shove travel, chicane probes | NOT RUN | All require driven real-player contacts. |
| 8.4 line-of-sight readability | NOT RUN | Needs the screenshot-corroborated approach check with a driven camera. |
| 8.2.6 time-expanded dynamic-state graph | NOT RUN | The audit uses the conservative union graph; the time-expanded proof is a separate pass. |
| 8.3 cross-piece mesh penetration | NOT RUN | A box test cannot decide mesh penetration, so the seams need a visual inspection pass. |
| 8.4 cross-course auditVariety over all SIX specs | NOT RUN as a full set | It runs over the five that exist and all twelve checks pass; Piston Peak is not built yet. |

## Manual checklist

- [ ] Interactive keyboard run start to finish, unteleported, with operator and input method recorded.
- [ ] Deliberate missed-timing contact at each of the five rotor hazards.
- [ ] Deliberate miss on each tile group; confirm the fall hits race liquid and the checkpoint respawn
      leaves a legal path to the finish with the tiles still dropped.
- [ ] Confirm the fan launch lands on Balance from a standing run-off and from a running jump.
- [ ] Confirm both pad launches land on their rocks from the pad's centre and from its back edge.
- [ ] Studio local multi-client session: two runners on the same tile group at once.
