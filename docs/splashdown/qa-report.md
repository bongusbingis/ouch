# Splashdown course QA report

Per-course acceptance matrix for the Splashdown course rebuild (HANDOFF.md section 5's required
`docs/splashdown/qa-report.md`). Every cell is one of **PASS**, **FAIL**, **BLOCKED** or **NOT RUN**,
and every PASS traces to a checked-in evidence file named in the row. A blank or an absence of data
is never a pass.

Snapshot: 2026-09-16, branch `feature/splashdown-hazard-kits`, place 121997450145716, rebuilt across
all seven courses at the section 12.1 replacement transaction. Sources for every figure:
`evidence/courses/<Id>/qa.json`, `evidence/courses/<Id>/build.json`,
`evidence/courses/<Id>/routes.json`, `evidence/course-cameras.json`,
`evidence/retirement-transaction.md` and each course's document under `courses/`.

`CourseQA.check` never returns PASS while any live-playtest check is outstanding, so **BLOCKED with
zero errors is the best an automated run can report**, and that is deliberate —
`places/arena/tests/Assets/SplashdownQA.spec.luau` asserts it.

## Set status

| Course | Built | Independent audit | Certified |
|---|---|---|---|
| BallBarrage | **YES** | `CourseQA` BLOCKED, 0 errors, 0 warnings, hash `7a46da9c` | **Gate 3 APPROVED by the user (2026-09-15) after an interactive Studio playtest.** Not certified by the automated suite, which still reports BLOCKED on its own NOT RUN list. Its hammers and pistons changed after that approval (2026-09-16 hazard-reach pass), so beats 03 and 05 are worth one more interactive pass. |
| WhirlpoolWaltz | **YES** | `CourseQA` BLOCKED, 0 errors, 0 warnings, hash `78e562b8` | **NO — and its scripted trials FAILED 0 of 8.** Every run stalled on the first ride deck in `02_WedgeWake`, about 32 falls per 150 s run. Needs the interactive keyboard run before its difficulty can be judged. |
| DoorDash | **YES** | `CourseQA` BLOCKED, 0 errors, 0 warnings, hash `aae4c298` | **NO** — every static and graph check passes; **its scripted trials FAILED 0 of 8**, the best run reaching 2 of 5 checkpoints. Needs the interactive keyboard run. |
| TumbleTunnels | **YES** | `CourseQA` BLOCKED, 0 errors, 0 warnings, hash `d390ff50` | **NO** — every static and graph check passes and the beach balls are verified against the real kit; **its scripted trials did NOT COMPLETE** (the harness ran 3.5 h without writing a result against its own ~25-minute budget), so no trial numbers are claimed. |
| TiptoeTrials | **YES** | `CourseQA` BLOCKED, 0 errors, 0 warnings, hash `0f8e9510` | **NO** — every static and graph check passes; **scripted trials NOT COMPLETED** (standing 2026-09-16 decision). Needs the interactive keyboard run. |
| PistonPeak | **YES** | `CourseQA` BLOCKED, 0 errors, 0 warnings, hash `e164c528` | **NO** — every static and graph check passes and its rising liquid is measured against its own checkpoints; **scripted trials NOT COMPLETED**. |
| SummitSplash | **YES — hardened 2026-09-16** | `CourseQA` BLOCKED, 0 errors, **1 warning**, **1 FAIL**, hash `dcece9ec` | **NO** — all seven gate cut sets hold, all 13 gates seal both arc edges to 0.00; but **two of 7.7's own clauses are NOT met** on the preserved arc and are escalated under 7.7.10 rather than exempted. Accepted by the user (2026-09-16) as documented limitations, because narrowing the arc would violate "preserve the route". |

## Executed checks — all seven courses

| Check (HANDOFF section) | BallBarrage | WhirlpoolWaltz | DoorDash | TumbleTunnels | TiptoeTrials | PistonPeak | SummitSplash |
|---|---|---|---|---|---|---|---|
| Deterministic double build, identical SpecHash and part count (5.1.12) | PASS `7a46da9c` | PASS `78e562b8` | PASS `aae4c298` | PASS `d390ff50` | PASS `0f8e9510` | PASS `e164c528` | PASS `dcece9ec` |
| Rebuild from the section 4 source exports after the swap (12.3) | PASS 143 parts | PASS 142 | PASS 221 | PASS 163 | PASS 160 | PASS 162 | PASS 199 |
| AttributeAudit errors (3.3, 8.1) | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 |
| Route errors (5.2) | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 |
| Bounds violations (5.1.10, 8.1) | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 |
| Part corners within 600 of Origin; centres within 380; route within BoundsRadius; envelope inside −30..90 (8.1, 5.1.10) | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Route arclength, 800–1,000 target 880 (3.2 override 4) | PASS 881.05 | PASS 884.78 | PASS 882.07 | PASS 880.45 | PASS 880.41 | PASS 880.00 | n/a — 1,662.33, the preserved arc |
| Every beat 0.85–1.15 of its length target (5.2) | PASS 1.015–1.099 | PASS 1.031–1.104 | PASS 0.935–1.112 | PASS 0.880–1.124 | PASS 0.929–1.106 | PASS 0.909–1.050 | PASS 0.999–1.002 |
| Route stays on its parametric guide (5.2) | n/a Serpentine | PASS worst 7.07 of 12 | n/a Chute; five invariants PASS, hairpin at 60.09% | n/a Loop; five invariants PASS, closes 69.55 studs through exactly −360° | n/a Archipelago; six invariants PASS | n/a StackedSwitchback; six invariants PASS | n/a SourcePatch; preserved centreline |
| Exactly 30 start pads (8.1) | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Ordered checkpoints, count matches the model attribute (8.1) | PASS 5 | PASS 5 | PASS 5 | PASS 6 | PASS 5 | PASS 6 | PASS 4 |
| Exactly one Finish.Trigger and one Finish.Deck (8.1) | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| 24-wall boundary ring at radius 390, worst error 0.00 (8.1) | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Sampled walkable surface graph — cells / nodes / edges (8.2.1–8.2.4) | PASS 18,548 / 14,977 / 2,392,356 | PASS 14,844 / 12,181 / 836,683 | PASS 40,121 / 29,918 / 3,366,017 | PASS 28,879 / 20,788 / 1,168,827 | PASS 16,299 / 14,774 / 1,314,869 | PASS 15,945 / 13,886 / 1,854,187 | PASS 108,149 / 103,720 / 6,603,327 |
| Ordered route proved from all 30 spawn cells (8.2.7) | PASS 0 failing legs | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 | PASS 0 |
| Every beat gate a true cut set (8.2.8) | PASS 6/6 | PASS 6/6 | PASS 6/6 | PASS 7/7 | PASS 6/6 | PASS 7/7 | PASS 7/7 |
| Launch envelopes measured from the real tools (8.2.5) | PASS 2 pads + 1 fan | PASS 2 pads | PASS 3 pads | PASS 1 fan, 1 excluded by name | PASS 2 pads + 1 fan | PASS 2 pads | PASS 1 pad, 1 fan excluded by name |
| Declared gaps inside 13.5–19.5 studs (8.3, 9.6) | 5 NOT RUN by design (launch/ball transfers) | PASS all 18 ordinary; 5 launch transfers NOT RUN by design | 3 launch transfers NOT RUN by design | 1 fan transfer NOT RUN by design | n/a — Archipelago launches, NOT RUN by design | 2 hops NOT RUN by design | n/a — preserved arc |
| No hazard-free 24 × 24 breather square (8.4) | PASS 21 × 21 | PASS 14 × 14 | PASS 16 × 16 | PASS 21 × 21 | PASS 23 × 23 | PASS 14 × 14 | **FAIL 42 × 42** — the preserved arc deck between gates |
| Encounter types ≥ 6 (8.4) | PASS 6 of 16 encounters | PASS 6 of 17 | PASS 6 of 19 | PASS 6 of 13 | PASS 6 of 16 | PASS 6 of 15 | PASS 6 of 16 |
| Dominant type ≤ 40% on encounters (8.4) | PASS 31.2% RotorBump | PASS 35.3% RotatingPlatforms | PASS 31.6% RotorBump | PASS 30.8% RotorBump | PASS 31.2% FallingTile | PASS 33.3% RotorBump | PASS 37.5% RotorBump |
| Families ≥ 4 (8.4) | PASS 5 | PASS 5 | PASS 5 | PASS 6 | PASS 4 | PASS 5 | PASS 5 |
| Longest same-type run ≤ 3 (8.4) | PASS 3 | PASS 3 | PASS 3 | PASS 2 | PASS 2 | PASS 3 | PASS 2 |
| Cross-course rules over every staged spec (8.4 override 2) | PASS 12/12 over 6 | PASS 12/12 over 6 | PASS 12/12 over 6 | PASS 12/12 over 6 | PASS 12/12 over 6 | PASS 12/12 over 6 | **PASS 12/12 over all 7** |
| Mesh seam / intersection pass (8.3) | NOT RUN — 50 oriented-box overlaps need visual inspection | NOT RUN — 22 | NOT RUN — 138 | NOT RUN — 126 | NOT RUN — 48 | NOT RUN — 64 | NOT RUN — 68 |
| Two fixed-camera images inspected (8.6) | PASS both, 2026-09-16 | PASS both, 2026-09-16 | PASS both | PASS both | PASS both, recaptured 2026-09-16 | PASS both | PASS both |
| Studio TestEZ course assertions (12.3) | PASS 24/24 | PASS 24/24 | PASS 24/24 | PASS 24/24 | PASS 24/24 | PASS 24/24 | PASS 24/24 |
| Stands and resolves in a live match through the admin seams (12.3) | PASS — boots and resolves | PASS — boots and resolves | PASS — raced round 2, 221 live parts | PASS — boots and resolves | PASS — boots and resolves | PASS — raced round 3, 162 live parts | PASS — raced round 1, 199 live parts |
| Scripted expert trials (8.5) | PASS 3 of 3, clean 38.35 s | **FAIL** 0 of 3 | **FAIL** 0 of 3 | **NOT COMPLETED** | NOT RUN | NOT RUN | NOT RUN |
| Scripted mid trials (8.5) | PASS 5 of 5, median 63.66 s | **FAIL** 0 of 5 | **FAIL** 0 of 5 | **NOT COMPLETED** | NOT RUN | NOT RUN | NOT RUN |
| Pace: mid median 60–90 s (8.5) | PASS 63.66 s | **FAIL** no completed run | **FAIL** no completed run | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| Pace: clean expert ≤ 0.6 × mid median (8.5) | **FAIL by 0.004** — ratio 0.6024 | **FAIL** | **FAIL** | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| Every hazard contacted by a normal runner (8.5) | **FAIL** — 16 of 17 pieces; `01_Countercurrent/Bumper01` never contacted | **FAIL** — 5 of 17 | **FAIL** — 15 pieces; pads, maces, hammer and finishing cross never reached | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| Interactive keyboard run (8.5) | PASS — Gate 3, 2026-09-15, on the pre-hazard-reach geometry | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| Deliberate missed-timing contacts and checkpoint-recovery run (8.5) | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| Manual five-question loophole table written (7, 10) | PASS — `courses/ball-barrage.md` | PASS — `courses/whirlpool-waltz.md` | PASS — `courses/door-dash.md` | PASS — `courses/tumble-tunnels.md` | PASS — `courses/tiptoe-trials.md` | PASS — `courses/piston-peak.md` | PASS — `courses/summit-splash.md` |

The six built courses' `qa.json` cross-course rows were measured over the six NEW specs, because
Summit's spec did not exist when they ran. **Summit's own run is the one that scored all twelve
cross-course checks over all seven staged specs, and all twelve pass.** That is the set-wide result.

## Set-wide source and hazard coverage

Measured over the seven staged specs by `CourseQA.auditCrossCourse` in the Summit run.

| Non-glue mechanic | Courses using it | Cap |
|---|---|---|
| Conveyor | BallBarrage, DoorDash, PistonPeak | 3 |
| Fan | BallBarrage, TiptoeTrials, TumbleTunnels | 3 |
| Seesaw | PistonPeak, TiptoeTrials, TumbleTunnels | 3 |
| Door | DoorDash, WhirlpoolWaltz | 3 |
| PaddleWheel | DoorDash, TumbleTunnels | 3 |
| Piston | BallBarrage, PistonPeak | 3 |
| BeachBall | TumbleTunnels | 3 |
| BigBall | BallBarrage | 3 |
| FallingTile | TiptoeTrials | 3 |
| LogRoll | PistonPeak | 3 |
| RidePlatform | WhirlpoolWaltz | 3 |
| Sweeper | BallBarrage | 3 |

Every headline is exclusive and none clashes with another course's climax: BigBall (Ball Barrage),
RotatingPlatforms (Whirlpool Waltz), Door (Door Dash), BeachBall (Tumble Tunnels), FallingTile
(Tiptoe Trials), Piston (Piston Peak), Sweeper (Summit Splash). No headline dominates more than one
beat outside its own course, and **no beat recipe repeats across any pair of courses.**

Each course independently clears at least six primary hazard types, four families, a dominant type
under 40% of its encounters and no same-type run longer than three. The set-wide worst figures are
37.5% (Summit), four families (Tiptoe Trials) and a run of three.

**The cap is scored over the six NEW courses only**, excluding the `SourcePatch` course. That is a
judgement about override 2's own wording ("at most three of the six new courses") rather than a
measurement, it was confirmed by the user on 2026-09-16, it is stated in every finding's own detail
text, and it is reversible in one line (`countsTowardCap` in `CourseQA.auditCrossCourse`).

## Summit Splash before and after

| | Authored source | Hardened |
|---|---|---|
| BaseParts | 258 | 199 |
| Route | preserved arc centreline | same centreline, 1,662.33 measured studs over 177 steps |
| Checkpoints | four, in order | **four, in the same order** |
| Rise schedule | 60 studs, 20 s delay, 140 s | **untouched**; config `LavaRise {60, 20, 140}`, Par 115 / Cap 210 / Close 45 all preserved |
| Beats | — | seven, all 0.999–1.002 of their preserved targets |
| Hazards | original sector props | named removal set applied, retained hazards re-tagged, seesaws + a sweeper + a foam lane added per 7.7.4 |
| Anti-skip | not measured | **13 gates, every one an edge gap of 0.00**, every swept gate closing its passage to within 0.50 studs; seven gate cut sets, 0 of 30 spawn cells bypassing any gate |
| Flood | original | reported, not tuned: tops out at world Y +10, submerging Checkpoint01 at 104.0 s, 02 at 127.3 s, 03 at 150.7 s against Par 115 / Cap 210. **Checkpoint04 never floods**, so a dry respawn pad always exists |

**Two of 7.7's clauses are not met and are reported as failing measurements, not exempted.**

1. **7.7.8, "each remaining shove must reach liquid", is not met on the arc and cannot be.** It holds
   on the narrowed inward bridge (16.25 studs wide, both edges lava, a 43.2-stud sweep). On the arc
   the preserved deck is 44 studs wide, and the narrowest continuous enclosure that does not cut the
   authored 30-pad start grid (r 165..196) or a 32-stud checkpoint pad is r 163/197 — still far wider
   than any measured shove.
2. **8.4's no-breather rule fails on the same geometry**: a measured 42 × 42 flat hazard-free square
   against a 24-stud limit, which is the preserved arc deck between gates.

Both were escalated under 7.7.10 and **accepted by the user on 2026-09-16 as documented limitations**,
because the only fix is to narrow the preserved arc, which would violate "preserve the route". The
options are written out in `courses/summit-splash.md`.

## Multiplayer evidence

**NOT RUN, and honestly so.** The Studio local multi-client session (2–4 clients) and the 30-rig
start load test that Appendix B item 4 substituted for a real 30-player session have never been run,
for any course, at any point in this project. They are on `CourseQA`'s NOT RUN list for all seven
courses as "8.5 thirty-rider start load test and the Studio local multi-client session", and no
figure anywhere in this repository claims them.

What does exist is single-client: every physics, carry, contact and traversal measurement in this
project came from one machine, server-owned R15, in Studio Play, often at about 400 Hz. The
`places/arena/tests/Server/CarryMotion.spec` and `HazardKits.spec` suites prove the kit contracts
under an engine TestEZ run, not under network conditions.

The static evidence that bears on a 30-racer start is the one piece that IS measured: every course
exposes exactly 30 immediate `Start/Pads` BaseParts, and the ordered-route audit proves a legal route
to the finish **from all 30 spawn cells** on every course, with zero failing legs. That is a
reachability proof, not a load test, and it is not a substitute for one.

## Outstanding for every course

These are the eight items `CourseQA` reports NOT RUN, and they are why no course reports PASS:

1. 8.2.6 time-expanded dynamic-state graph (periodic sampling every 0.1 s across one common cycle).
2. 8.4 lane cross-section hazard coverage and blocked fraction ≥ 0.4 per pendulum/hammer crossing.
3. 8.4 measured shove travel from five real-player contacts per hazard and direction.
4. 8.4 bumper chicane centreline/edge/slalom avoidance probes.
5. 8.4 line-of-sight readability (≥ 15 studs of approach) corroborated by screenshots.
6. 8.5 scripted expert/mid policy route trials and the interactive keyboard run.
7. 8.5 thirty-rider start load test and the Studio local multi-client session.
8. 8.6 the `bad-map-refs` comparison, for the courses whose documents do not carry one.

Also outstanding and not on that list:

- **The mesh-level seam pass.** `auditGeometry` compares oriented extents, and HANDOFF 8.3 says
  outright that a box test cannot decide mesh penetration. Counts per course are in the matrix.
- **Palette and dressing (section 7 override 1) are still not applied by the builder.**
  `CoursePresets` clones sources without recolouring, so all six new courses ship in the kit's own
  source colours. It is declared in every course document. Summit is the one course with no palette
  to apply — 7.7 preserves its existing sector colours.
- **The whole scripted-trial and interactive-playtest category**, per the user's standing 2026-09-16
  decision. Ball Barrage has the only interactive run, and it predates the hazard-reach change to its
  hammers and pistons.
- A user mid-skill calibration run, which 8.5 requires wherever proxy results and interactive
  experience disagree.

## Known limits of the evidence

- All physics and timing figures come from one machine, server-owned R15, in Studio Play. They are
  not 60 Hz, latency or 30-player measurements and are not labelled as such.
- The scripted policies are reproducible proxies, not human skill classifications. They walk straight
  lines: they cannot read a sweeping hole in a rotating plate, time a Big Ball cap, or choose a door
  channel on anything but the centre-out order the harness gives them.
- Graph sampling is finite-resolution. Surface cells are sampled at the calibration's step with a
  finer pass near edges and holes, and edges are tested against gate volumes every 0.5 studs. That is
  a measurement, not an analytic proof, and narrow or phase-dependent cases still need real traversal
  to corroborate.
- **Summit is audited in-engine at 2-stud sampling**, recorded in its own report, because 6.6 million
  edges exhaust a single TestEZ node's execution time. The full-resolution 1-stud audit is the one
  the probe published to its `qa.json`, and that is the run these figures come from.
- Three harness bugs and two audit defects were found by executing these checks rather than by
  reading them; any figure recorded before 2026-09-16 should be re-read against
  `docs/splashdown/03-overrides.md` and the changelog before it is quoted.
