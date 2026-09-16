# Ball Barrage — pilot course

Status: **BLOCKED**, not certified. The build and the static audit pass; the live-playtest
half of HANDOFF section 8 has not run. See "What is NOT RUN" before quoting anything here.

- Spec: `src/shared/Game/Splashdown/CourseSpecs/BallBarrage.luau`
- Measured build/route evidence: `docs/splashdown/evidence/courses/BallBarrage/build.json`
- Measured audit evidence: `docs/splashdown/evidence/courses/BallBarrage/qa.json`
- SpecHash `020c7854`, 158 BaseParts, built twice with identical hashes on place 121997450145716.

## Concept and headline

A counter-current opening hands straight into the course's exclusive mechanic: three Big Balls
strung over open liquid on a lane-change, with nothing walkable under them. The rest of the route
is timing pressure — opposing pistons, a guided launch, then asymmetric hammers as the climax —
before a short slide sprint to the finish. Big Balls appear in no other course.

Palette (HANDOFF section 7 override 1): base coral `#FF608E`, accent yellow `#FFD64A`. Walkable
tops keep the kit's blue. Pads are `trampoline_1`.

## Layout and guide

Kind **Serpentine**, on the HANDOFF 5.2 polyline in local X/Z:

~~~text
(-180,168) → (60,168) → (60,56) → (-180,56) → (-180,-56) → (60,-56) → (60,-168) → (-180,-168)
~~~

The route consumes the first five segments and stops partway along the third parallel run.
Adjacent parallel runs are 112 studs apart, which is the guide's own lane pitch, achieved exactly
rather than approximately: each `Corner` piece fills the remainder of its segment with uniformly
scaled tiles, then puts the corner slab's own measured Entry socket at the vertex. `CourseBuilder`
fails the build if any straight run exceeds its segment length, so the guide is an enforced
envelope, not a comment.

~~~text
        X=-180                                                    X=+60
          |                                                          |
 Z=+168   S=====B1==B2==/R1==F1==F2==F3=[b][b]==R2==================A+   segment 1  (240)
                                                                    |
                                                        BALL CHAIN  |   segment 2  (112)
                                                       (O) (O) (O)  |
 Z= +56   +B==\R4==F4==[P][P]==F5==F6==//R5==(^)(f)···(L)···=========+   segment 3  (240)
          |
          |  segment 4 (112)
          C+==\R6==F7
          |
 Z= -56   +D==/R7==F8==F9==[H][H]==F10==\\S1==RO1==RO2==(X) FINISH       segment 5  (240, 177 used)

 S start plaza   / ascending ramp   \ descending ramp   // +12 ramp   \\ slide
 [b] bumper      (O) Big Ball over liquid   [P] piston   (^) jump pad   (f) fan
 (L) launch landing   [H] hammer   ··· open air   A/B/C/D corner slabs   (X) finish deck
~~~

Generated from the spec's own piece list and the measured route trace in `build.json`; the letters
are the actual `PieceId`s.

## Beats, sources and measured numbers

Length is the measured socket arclength the builder reported, not a planned figure. "Lane" is the
measured walkable width of that beat's floor pieces (source footprint × uniform scale).

| Beat | Family / mechanic | Length (target, ratio) | ΔY | Lane | Sources and scales |
|---|---|---|---|---|---|
| 01_Countercurrent | Ride / counterbelts | 164.1 (150, 1.09) | +6 | 13.98 belts, 20.7 floor | `obstacle_9_001` ×2 @0.5 (ConveyorSpeed −13 / −18.2); `obstacle_2_001` @0.5 sweeper; `box_013` @0.2105 reversed; `platform_001` ×3 @0.3; `obstacle_18_001` + `obstacle_19_001` @0.5 |
| 02_RedRebound | Precision / Big Ball chain | 150.6 (140, 1.08) | +6 then −6 | 20.7, steps 10.35 | `box_013` @0.2105 reversed; corner `platform_002` @0.3; `obstacle_23_001` ×3 @1 mounted to the liquid, side 0 / +4 / −4, last two rocking; `platform_002` @0.15 step; `box_011` @0.2105 |
| 03_PunchPass | Timing / piston ledge | 132.0 (130, 1.02) | +6 | 20.7 | corner `platform_002` @0.3; `box_011` @0.2105 reversed; `platform_002` ×3 @0.3; `obstacle_22_001` ×2 @0.5, phases 0 / 1.6, facing ±90, side ∓7 |
| 04_SkyThread | Launch / guided launch | 160.5 (150, 1.07) | +12 then −6 | 25.4 ramp, 10.35 landing | `box_011` @0.4211 reversed; `trampoline_1_001` @0.6 LaunchSpeed 51 and 54; `propeller_trampoline_1_001` @0.5; `platform_002` @0.15; corner `platform_002` @0.3; `obstacle_18_001` @0.5; `box_011` @0.2105 |
| 05_HammerHour | Timing / asymmetric strikes — **climax** | 164.8 (150, 1.10) | +6 | 20.7 | `platform_002` @0.3; corner `platform_002` @0.3; `box_013` @0.2105 reversed; `platform_001` ×2 @0.3; `obstacle_3_001` and `obstacle_4_001` @0.6, amplitude 55, phases 0 / 0.7 |
| 06_SplashSprint | Climb/Descend / finish slide | 85.0 (80, 1.06) | −12 | 20.7 floor, 7.87 slide | `platform_003` @0.3; `slide_001` @0.2317; `platform_003` ×2 @0.3 run-out; `obstacle_19_001` @0.4 |

Total measured route arclength **881.05 studs**, inside the 800–1,000 window (override 4). Elevation
runs 0 → 6 → 6 → 12 → 18 → 24 → 12, matching the section 7.1 column exactly. Five checkpoints, one
at each beat entrance after beat 1.

Ramps: the kit has no ascending ramp mesh, and `arc_004` was measured and rejected as a turn piece
(`course-sockets-ballbarrage.json`). Every climb is therefore a measured descending ramp entered
from its low end (`Reversed = true`), which swaps its Entry and Exit sockets and turns its forward
heading 180°. No mesh is mirrored, stretched or non-uniformly scaled.

### Encounters (16)

RotorBump 5 (31.2%: sweeper, 2 pistons, 2 hammers), BigBall 3, Bumper 3, Conveyor 2, JumpPad 2,
Fan 1 — the section 7.1 distribution exactly. Six types, five families, longest same-type run 3,
climax is the second-to-last beat.

Beat 01's "forced cube+triangle chicane" is two bumper slabs but one encounter, because the runner
solves them as a unit (section 7 override 3: "Bumper: each chicane, or each isolated forced
bumper"). The spec marks them with a shared `EncounterGroup`, so `auditVariety` scores them once.
Per-instance counts — 4 bumper slabs, 17 hazard instances in all — are in `qa.json` and are
reported, never scored.

## Measured bounds

| Rule | Limit | Measured |
|---|---|---|
| Part corner to Origin (8.1) | ≤600 | 494.8 |
| Geometry centre horizontal radius (8.1) | ≤380 | 246.2 |
| Route horizontal radius (5.1.10, new design) | ≤300 | 211.2 |
| Static route envelope Y (5.1.10) | −30..90 | −20.0 .. 62.0 |
| Boundary ring | 24 walls, r=390±1 | 24 walls, worst radius error 0.00 |

The perimeter ring's own corners reach Y 285.1 because it is the arena boundary wall cloned
unscaled, which is what HANDOFF 8.1 requires ("copied from the existing boundary contract", and
`author-splashdown-courses.luau` clones the same part unscaled). 5.1.10 scopes the −30..90 band to
the static route envelope and separately extends only the ≤600 rule to "every part corner, liquid
and boundary included"; the ring satisfies that at 494.8. It is reported separately as
`Bounds.MinY/MaxY` so the distinction is visible rather than buried.

## The five loophole questions

**These five questions are defined here, not cited.** HANDOFF and the Gate 1 plan refer to "five
loophole questions" repeatedly but never enumerate them; `00-findings.md`, `01-asset-inventory.md`,
`02-kits.md` and `gate-1-plan.md` were all searched and none contains a list. Rather than invent an
uncited standard, the five below are derived from the fairness language scattered through HANDOFF
3.2, 8.2, 8.4, 9 and 13. **If the user has a different five in mind, these answers must be redone
against them.**

1. **Bypass** — can the encounter be skipped by any route the walkable graph can find, including
   reachable roofs, rail tops and landings on another run?
2. **Waiting** — can a racer stand somewhere safe indefinitely and neutralise the encounter without
   paying time for it?
3. **Escape reach** — is the lane narrow enough that the hazard's measured shove cannot push a
   racer clear to a permanent safe edge, and wide enough that contact is not unavoidable?
4. **Readability** — is the encounter visible and legible at least 15 studs before commitment, and
   is the next beat visible from this beat's exit?
5. **Stranding** — if a racer fails here, do they fall into race liquid and respawn at an ordered
   checkpoint with a physically reachable path onward, rather than being stuck or one-way trapped?

| Encounter | 1 Bypass | 2 Waiting | 3 Escape reach | 4 Readability | 5 Stranding |
|---|---|---|---|---|---|
| Belt01/02 | PASS — gate `01_Countercurrent` is a proven cut set (0/30 spawns bypass) | NOT RUN | NOT RUN — needs measured shove travel | NOT RUN | PASS — belts sit over liquid, checkpoint 0 is the start plaza |
| Sweeper01 | PASS (same gate) | NOT RUN | NOT RUN | NOT RUN | PASS |
| Bumper01/02 | PASS (same gate) | NOT RUN | NOT RUN — chicane probes outstanding | NOT RUN | PASS |
| Ball01/02/03 | PASS — gate `02_RedRebound` is a cut set; the chain sits on `Advance` pieces with no slab beneath, and the poles mount to the liquid surface so no support makes a recovery walkway | NOT RUN | NOT RUN | NOT RUN | PASS — every miss hits liquid, respawn at checkpoint 1 |
| Piston01/02 | PASS — gate `03_PunchPass` is a cut set | NOT RUN | NOT RUN | NOT RUN | PASS |
| Pad01/Pad02/Fan01 | PASS — gate `04_SkyThread` is a cut set | NOT RUN | NOT RUN — launch reach window unmeasured | NOT RUN | PASS |
| Bumper03 | PASS (same gate) | NOT RUN | NOT RUN | NOT RUN | PASS |
| HammerLarge/Small | PASS — gate `05_HammerHour` is a cut set | NOT RUN | NOT RUN — blocked-fraction ≥.4 unmeasured | NOT RUN | PASS |
| Bumper04 | PASS — gate `06_SplashSprint` is a cut set | NOT RUN | NOT RUN | NOT RUN | PASS |

Question 1 is answered by a real measurement: 18,446 sampled surface cells, a 14,883-node /
336,488-edge walkable graph built from actual raycasts at 1-stud resolution, and a cut-set proof
per beat gate. Question 5 is answered structurally (liquid under every fall line, ordered
checkpoints, and the ordered-route proof from all 30 spawn cells). Questions 2, 3 and 4 need the
live playtest and are honestly NOT RUN.

Two loopholes were found and fixed by that audit rather than by inspection:

- **Finish drop-in.** At a 40-stud finish plaza the deck reached back under beat 06's upper floor,
  and all 30 spawn cells still reached Finish with gate `06_SplashSprint` removed — a racer could
  drop off the side and skip the slide. Fixed by tightening the plaza to 34 studs and adding a
  two-slab run-out after the slide, which puts the deck out of the measured 22-stud jump reach.
- **Breather slab.** Beat 01's floor was one `platform_001` at scale 0.92, a 64×83-stud flat pad
  that the coverage scan reported as a 49×49 hazard-free square against the 24×24 limit. Every
  route platform is now capped at scale 0.3 (20.7 studs wide), and the largest flat square on the
  route is 21×21.

## What is NOT RUN

Nine section 8 checks have not been executed and are listed verbatim in `qa.json`:

- 8.2.6 time-expanded dynamic-state graph
- 8.4 lane cross-section hazard coverage and blocked-fraction ≥.4 per pendulum/hammer crossing
- 8.4 measured shove travel from five real-player contacts per hazard and direction
- 8.4 bumper chicane centreline/edge/slalom probes
- 8.4 line-of-sight readability corroborated by screenshots
- 8.4 cross-course `auditVariety` over all six specs (only the pilot exists)
- 8.5 scripted expert/mid route trials and the interactive keyboard run
- 8.5 thirty-rider start load test and the Studio local multi-client session
- 8.6 fixed-camera captures and the `bad-map-refs` comparison

`CrossPieceBoundingOverlap` is also NOT RUN by design: 50 oriented-box overlaps exist between
socket-joined pieces, but 8.3 states plainly that "oriented bounding overlap alone is not a mesh
intersection test", so the seams need the visual pass before any verdict.

Because of these, `CourseQA.check` returns **BLOCKED**. It cannot return PASS while any check is
outstanding — that is enforced in code, not by convention.

## Manual checklist (all unchecked)

- [ ] Interactive keyboard run, full course, unteleported. Record operator and input method.
- [ ] Expected fall points per beat.
- [ ] Visible timing cues for pistons and hammers.
- [ ] Where waiting is safe but costs time.
- [ ] Respawn location correctness per checkpoint.
- [ ] Launch landing boundaries for Pad01/Pad02/Fan01.
- [ ] Any unfair, floating or unreadable geometry.
- [ ] Top-down and three-quarter fixed-camera captures compared against `bad-map-refs/1,2,9,10,11`.
- [ ] Measured pace, to fix the set-wide route-length target before the remaining five courses.
