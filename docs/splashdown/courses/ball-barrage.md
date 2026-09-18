# Ball Barrage — pilot course

Status: **GATE 3 APPROVED** by the user (2026-09-15), after playing the course interactively in
Studio via a local test override (`Splashdown.CourseOrder` swapped to `BallBarrage`/`WhirlPool`/
`KnockKnock`; reverted once testing is done — see the config file for the exact note). One
correction came out of that playtest and is applied below. The exhaustive HANDOFF section 8
sub-checks still marked NOT RUN in this doc (scripted route trials, the 30-rider load test, the
multi-client session, fixed-camera captures vs. `bad-map-refs`, and the launch-edge graph) were
superseded by the user's direct approval rather than individually completed; they remain listed
for anyone auditing the record, not as open blockers.

- Spec: `src/shared/Game/Splashdown/CourseSpecs/BallBarrage.luau`
- Measured build/route evidence: `docs/splashdown/evidence/courses/BallBarrage/build.json`
  (pre-tuning build; neither tuning pass below was re-exported to this file)
- Measured audit evidence: `docs/splashdown/evidence/courses/BallBarrage/qa.json` — **current, and
  re-run 2026-09-16 after tuning pass 2 under the corrected surface sampler.**
- Pre-tuning SpecHash `020c7854`, 158 BaseParts, built twice with identical hashes on place
  121997450145716. **Current SpecHash `7a46da9c`, 143 BaseParts, 881.053 measured studs of route,
  promoted 2026-09-16.** The part count fell from 158 because a `CoursePresets` fix stopped every
  piston cloning a second copy of its own spring; the hash also moved through `ca5e95b4` (that fix)
  and `943e493c` before it.

## Tuning pass 1 (2026-09-15, post-approval)

Live playtest finding: the three BigBall caps sat too high to land on reliably — contact was
mostly lateral (triggering `RollOff`) instead of landing within the `CapDegrees` top cone
(`BounceSpeed`). Fix: `Ball01`/`02`/`03` in `CourseSpecs/BallBarrage.luau` each gained
`OffsetUp = -6`, submerging the mounting pole 6 studs deeper below the liquid surface
(`MountTo = "Liquid"`) without touching the ball/pole mesh, scale, or any attribute. Rebuilt and
promoted through the real `CourseAuthoring.stage`/`promote` pipeline; the three sphere world
positions measured Y 19.20 post-fix (were ~25.2). Not yet re-exported to `build.json`/`qa.json` —
those still reflect the pre-tuning geometry.

## Tuning pass 2 (2026-09-16) — the pistons and hammers now reach the lane

Both of this course's timing beats shipped with hazards that moved correctly and never touched a
runner. Measured on the promoted `ca5e95b4` template, not inferred:

| Hazard | Before | After |
|---|---|---|
| `Piston01` head | side +16.30..+24.02 across a lane whose half-width is 10.51 — 5.79 to 13.51 studs PAST the edge, over open water | side **+2.484..+10.198** at rest, **−3.516..+10.198** swept, crossing the centreline by 3.52 studs on the punch |
| `Piston02` head | mirrored, side −24.02..−16.30 | side **−10.197..−2.483** at rest, **−10.197..+3.517** swept |
| `HammerLarge` head | Y 5.694..24.456 under a deck at Y 24.000 — only the top **0.46 studs** ever reached deck level | Y **26.122..44.883** at rest, **24.600..46.406** swept: deck **+0.600..+22.406** |
| `HammerSmall` head | Y 5.804..25.356 — top 1.36 studs | Y 25.431..44.984 at rest, **24.600..45.815** swept: deck **+0.600..+21.815** |

**The pistons were a mounting-sign bug.** `obstacle_22`'s head lies along the piece's own forward
axis at a measured 13.160 studs from the base at scale 0.5, with a 3.857-stud half-length and a
6-stud punch. A base placed INSIDE the lane facing outward therefore throws the head away from the
runner. The bases now stand OUTSIDE at `OffsetSide` ±19.5 with the heads reaching IN, which is how
Piston Peak mounts its three. A 21.02-stud lane cannot be sealed by a 7.71-stud head on a 6-stud
punch without the REST pose already covering the centreline (the failure Piston Peak measured at
side 17), so this is a pass to time rather than a wall: 12.99 studs of corridor down the far side at
rest, and 3.52 studs past the centreline for the 0.6-second hold. Both also moved 6 studs further
along (`OffsetAlong` −24 and −8, keeping their 16-stud spacing) so they stand over Floor04's flat
deck instead of hanging off its end over Ramp04's slope. The base (side 14.420..24.581) is clear of
the deck; the spring (side 9.495..20.445 at deck +3.99..+6.82) overhangs the lane edge by 1.02 studs,
so the outside is not a quiet walk-around.

**The hammers were a mount-height bug.** `obstacle_3_001` and `obstacle_4_001` are axle housings
with their heads suspended a measured 8.925 and 8.420 studs BENEATH them at scale 0.6, so the
pilot's `OffsetUp`-0 mounting swept both heads under the floor. HANDOFF 8.3 exempts a suspended
pendulum from the support rule and Tiptoe Trials already hangs both of these on that basis. The
height here is derived from the SWING, not from the rest pose: `CoursePresets` clears every display
pivot, so the head rocks about its OWN centre through ±55° about the route axis and its vertical
half-extent is `halfY·cos θ + halfX·sin θ`, whose maximum over the amplitude is `hypot(halfX, halfY)`
— 10.903 and 10.607 studs, reached at 30.7° and 22.8°, both inside 55°. Hanging the head so that
maximum clears the deck by 0.6 studs is what stops it ploughing through the floor at mid-swing, and
it leaves the resting head bottom 2.12 and 1.43 studs up, inside a runner's body band.
`OffsetUp` is therefore 20.428 and 19.627, written in the spec as that measured expression.

The dodge is lateral and timed: `HammerLarge` spans side ±5.558 at rest and a measured ±10.872 at
full swing, so it seals the ±10.51 lane on the strike and leaves a 4.95-stud corridor on each side
between strikes; `HammerSmall` is ±4.117 and ±10.370.

Rebuilt, re-staged and re-promoted through the real `CourseAuthoring.stage`/`promote` pipeline. The
Edit-mode stage and the independent Play-mode build agreed on SpecHash `7a46da9c` and 143 BaseParts.
`CourseQA.check` afterwards: **zero errors, zero warnings, 48 findings PASS, 14 NOT RUN, 0 FAIL**,
all six gate cut sets holding (0 of 30 spawn cells bypass any gate) over a 14,977-node /
2,392,356-edge graph from 18,548 real surface cells, and all twelve cross-course checks passing over
the six staged specs. Studio TestEZ: **21 passed, 0 failed** — the 20 existing assertions, which now
include "mounts every piston head where it can actually strike a runner" (written generically by the
Piston Peak session and failing here until this pass), plus the new swept-reach regression.

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

**Corrected 2026-09-15, now with an exact citation.** The first draft of this section defined its
own five questions because none could be found in 00-findings.md, 01-asset-inventory.md,
02-kits.md or gate-1-plan.md. The user then supplied the actual five, and they are in fact written
down verbatim in **HANDOFF.md section 11, step 1** ("walk-around; edge-hug; bypass-jump;
launched-past; safe-wait" with the same asymmetric pass rule) — a section this course's own build
predates, so the search that missed it wasn't wrong, just incomplete. Any future course doc should
cite section 11 directly rather than rediscovering this.

1. **Walk-around** — can a racer walk around the encounter at the same level?
2. **Edge-hug** — can a racer hug an edge past the encounter?
3. **Jump-over** — can a racer jump over the encounter?
4. **Launch-past** — can a racer get launched past the encounter?
5. **Wait-out** — can a racer wait it out at zero risk while others pass?

The pass rule is asymmetric: **questions 1–4 must be NO** (the gap is sealed) for every encounter;
**question 5 may be YES**, but only if waiting costs the racer time relative to engaging the
encounter. A YES on 1–4, or a zero-cost YES on 5, is a fail.

Questions 1–3 are answered by the same evidence: 18,446 sampled surface cells, a 14,883-node /
336,488-edge walkable graph built from actual downward raycasts at 1-stud resolution (finer near
edges and holes per 8.2.1), and a cut-set proof per beat gate that removes every node/edge whose
traversed capsule intersects the gate volume and re-checks reachability from all 30 spawn cells.
The graph's edges are `Walk` (adjacent standable cells — this is what a same-level walk-around or
an edge-hugged path would have to use) and `Jump` (gaps within the measured 22-stud/11.5-step
ballistic envelope). Both kinds participate in every gate's cut-set proof, so a PASS on the proof is
a genuine PASS on 1, 2 **and** 3 together, not just the bypass question the first draft asked.

**Question 4 is a real, currently-unfilled gap, not a pass.** `CourseQA.buildGraph`
(`src/shared/Game/Splashdown/CourseQA.luau`) does not construct `Launch` edges from Pad01/Pad02/
Fan01's actual measured trajectories, so nothing has proven a racer can't use those tools (or
momentum carried from an earlier beat) to vault past a later gate. This was already flagged as
NOT RUN under section 8.2.5/8.3 in the previous draft; renaming the questions doesn't close it —
it needs the same measured reach-window work either way, most naturally alongside the scripted
route trials.

Question 5 is answered structurally, not yet by timing: liquid sits under every fall line, ordered
checkpoints exist, and the ordered-route proof holds from all 30 spawn cells, so nothing here reads
as a free stall. Whether any specific waiting spot is genuinely zero-risk, and whether it actually
costs time, needs the live playtest.

| Encounter | 1 Walk-around | 2 Edge-hug | 3 Jump-over | 4 Launch-past | 5 Wait-out |
|---|---|---|---|---|---|
| Belt01/02 | PASS — gate `01_Countercurrent` cut set | PASS (same proof) | PASS (same proof) | NOT RUN | Structurally no stall point identified; NOT RUN to confirm |
| Sweeper01 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| Bumper01/02 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| Ball01/02/03 | PASS — gate `02_RedRebound` cut set; `Advance` pieces carry no slab, poles mount to the liquid surface so no support makes a recovery walkway | PASS | PASS | NOT RUN | NOT RUN |
| Piston01/02 | PASS — gate `03_PunchPass` cut set | PASS | PASS | NOT RUN | NOT RUN |
| Pad01/Pad02/Fan01 | PASS — gate `04_SkyThread` cut set | PASS | PASS | NOT RUN — this beat's own launch tools are exactly what question 4 needs measured | NOT RUN |
| Bumper03 | PASS (same gate) | PASS | PASS | NOT RUN | NOT RUN |
| HammerLarge/Small | PASS — gate `05_HammerHour` cut set | PASS | PASS | NOT RUN | NOT RUN |
| Bumper04 | PASS — gate `06_SplashSprint` cut set | PASS | PASS | NOT RUN | NOT RUN |

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

Nine section 8 checks have not been executed and are listed verbatim in `qa.json`, plus one found
while correcting the loophole-question table above:

- 8.2.5 `Launch` edges from Pad01/Pad02/Fan01's actual measured trajectories are not in
  `CourseQA.buildGraph`'s graph, so loophole question 4 (launch-past) is unproven for every gate,
  not measured NOT RUN by omission but genuinely never attempted yet
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
