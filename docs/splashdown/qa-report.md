# Splashdown course QA report

Per-course acceptance matrix for the Splashdown course rebuild (HANDOFF.md section 5's required
`docs/splashdown/qa-report.md`). Every cell is one of **PASS**, **FAIL**, **BLOCKED** or **NOT RUN**,
and every PASS traces to a checked-in evidence file named in the row. A blank or an absence of data
is never a pass.

Snapshot: 2026-09-16, branch `feature/splashdown-hazard-kits`, place 121997450145716.

**Ball Barrage's and Whirlpool Waltz's spec hashes changed on 2026-09-16** (from `943e493c` and
`2fbc899c`) when two `CoursePresets` bugs the Door Dash build exposed were fixed: door slabs now sit
as immediate children of `Scriptables/Doors` where the door kit can actually see them, and a nested
assembly is no longer cloned twice. Both courses were re-staged and re-promoted; their part counts
fell from 156 to 143 and from 151 to 142. Every other figure in their columns is unchanged.

## Set status

| Course | Built | Independent audit | Certified |
|---|---|---|---|---|
| BallBarrage | **YES** | `CourseQA` BLOCKED, zero errors | **Gate 3 APPROVED by the user (2026-09-15) after an interactive Studio playtest.** Not certified by the automated suite, which still reports BLOCKED on its own NOT RUN list. |
| WhirlpoolWaltz | **YES** | `CourseQA` BLOCKED, zero errors | **NO — and its scripted trials FAILED 0 of 8.** Every run stalls on the first ride deck in `02_WedgeWake`, about 32 falls per 150 s run. Needs the interactive keyboard run before its difficulty can be judged. |
| DoorDash | **YES** | `CourseQA` BLOCKED, zero errors, zero warnings | **NO** — every static and graph check passes and both fixed-camera captures are done; **its scripted trials FAILED 0 of 8**, the best run reaching 2 of 5 checkpoints. Needs the interactive keyboard run before its difficulty can be judged. |
| TumbleTunnels | **YES** | `CourseQA` BLOCKED, zero errors, zero warnings | **NO** — every static and graph check passes, both fixed-camera captures are done, and the beach balls are verified against the real kit; **its scripted trials did NOT COMPLETE** — the harness ran for 3.5 hours without writing a result, against its own 8-trial / 150-second-per-trial budget, so no trial numbers are claimed. Needs the interactive keyboard run before its difficulty can be judged. |
| TiptoeTrials | NOT BUILT | NOT RUN | NO |
| PistonPeak | NOT BUILT | NOT RUN | NO |
| SummitSplash | NOT HARDENED | NOT RUN | NO |

`CourseQA.check` never returns PASS while any live-playtest check is outstanding, so **BLOCKED with
zero errors is the best an automated run can currently report**, and that is deliberate
(`places/arena/tests/Assets/SplashdownQA.spec.luau` asserts it).

## Executed checks

Sources: `evidence/courses/<Id>/build.json`, `evidence/courses/<Id>/qa.json`,
`evidence/courses/<Id>/routes.json`.

| Check (HANDOFF section) | BallBarrage | WhirlpoolWaltz | DoorDash | TumbleTunnels |
|---|---|---|---|
| Deterministic double build, identical SpecHash (5.1.12) | PASS — `ca5e95b4` | PASS — `78e562b8` | PASS — `8c00a748` | PASS — `d390ff50` |
| AttributeAudit errors (3.3, 8.1) | PASS — 0 | PASS — 0 | PASS — 0 | PASS — 0 |
| Route errors (5.2) | PASS — 0 | PASS — 0 | PASS — 0 | PASS — 0 |
| Bounds violations (5.1.10, 8.1) | PASS — 0 | PASS — 0 | PASS — 0 | PASS — 0 |
| Part corners within 600 of Origin (8.1) | PASS — 494.78 | PASS — 494.78 | PASS — 494.78 | PASS — 494.78 |
| Geometry centres within 380 (8.1) | PASS — 246.22 | PASS — 150.06 | PASS — 247.59 | PASS — 194.76 |
| Route radius within BoundsRadius 300 (5.1.10) | PASS — 211.24 | PASS — 151.70 | PASS — 245.43 | PASS — 192.45 |
| Static route envelope inside -30..90 (5.1.10) | PASS — -26.00..62.00 | PASS — -18.00..74.00 | PASS — -16.00..62.00 | PASS — -22.00..62.00 |
| Route arclength inside 800-1,000 (3.2 override 4) | PASS — 881.05 | PASS — 884.78 | PASS — 882.07 | PASS — 880.45 |
| Every beat 0.85-1.15 of its length target (5.2) | PASS — 1.015 to 1.099 | PASS — 1.031 to 1.104 | PASS — 0.935 to 1.112 | PASS — 0.880 to 1.124 |
| Route stays on its parametric guide (5.2) | n/a (Serpentine) | PASS — worst 7.07 of 12 | n/a (Chute); the five Chute invariants PASS, hairpin turns at 60.09% | n/a (Loop); the five Loop invariants PASS, circuit closes 69.55 studs from the start through exactly -360 degrees |
| Declared gaps inside 13.5-19.5 studs (8.3, 9.6) | NOT RUN as a sweep | PASS — all 23 | n/a — no ordinary jump gaps; the three launch transfers are NOT RUN by design | n/a — one declared gap, the 14-stud fan transfer in 05, NOT RUN by design |
| Exactly 30 start pads (8.1) | PASS | PASS | PASS | PASS |
| Ordered checkpoints, count matches the model (8.1) | PASS — 5 | PASS — 5 | PASS — 5 | PASS — 6 |
| Exactly one Finish.Trigger and Finish.Deck (8.1) | PASS | PASS | PASS | PASS |
| 24-wall boundary ring at radius 390 (8.1) | PASS | PASS | PASS | PASS |
| Sampled walkable surface graph (8.2.1-8.2.4) | PASS — 18,446 cells, 14,881 nodes, 340,357 edges | PASS — 14,844 cells, 12,181 nodes, 383,518 edges | PASS — 38,241 cells, 28,121 nodes, 1,272,671 edges | PASS — 28,807 cells, 20,739 nodes, 789,860 edges |
| Ordered route proved from all 30 spawn cells (8.2.7) | PASS | PASS | PASS | PASS |
| Every beat gate a true cut set (8.2.8) | PASS — all 6 | PASS — all 6 | PASS — all 6 | PASS — all 7, after the audit rejected two enclosure designs that bridged the start plaza to the finish |
| No hazard-free 24x24 breather square (8.4) | PASS | PASS | PASS — largest 16 x 16 | PASS — largest 21 x 21 |
| Encounter variety: >=6 types, <=40%, >=4 families, run <=3 (8.4) | PASS — 16 encounters, 6 types, 31.3% max | PASS — 17 encounters, 6 types, 35.3% max | PASS — 19 encounters, 6 types, 31.6% max | PASS — 13 encounters, 6 types, 6 families, 30.8% max, longest run 2 |
| Cross-course rules over every existing spec (8.4 override 2) | PASS — all 12 findings | PASS — all 12 findings | PASS — all 12 findings over three specs | PASS — all 12 findings over four specs |
| Scripted expert trials (8.5) | PASS — 3 of 3 cleared, clean 38.35 s | **FAIL** — 0 of 3 cleared, all hit the 150 s ceiling | **FAIL** — 0 of 3 cleared, each stuck in the door corridor at 15.9-18.9 s | **NOT COMPLETED** — harness never returned a result |
| Scripted mid trials (8.5) | PASS — 5 of 5 cleared, median 63.66 s | **FAIL** — 0 of 5 cleared, all hit the 150 s ceiling | **FAIL** — 0 of 5 cleared; best run earned 2 of 5 checkpoints over 150 s with 11 respawns | **NOT COMPLETED** — same run |
| Pace: mid median 60-90 s (8.5) | PASS — 63.66 s | **FAIL** — no completed run to take a median from | **FAIL** — no completed run to take a median from | NOT RUN |
| Pace: clean expert <= 0.6 * mid median (8.5) | **FAIL by 0.004** — ratio 0.6024 | **FAIL** — no completed run | **FAIL** — no completed run | NOT RUN |
| Every hazard contacted by a normal runner (8.5) | **FAIL** — `01_Countercurrent/Bumper01` contacted in none of 8 runs; other 16 pieces all contacted | **FAIL** — only 5 of 17 pieces ever contacted, because no run passed `02_WedgeWake` | **FAIL** — 15 pieces contacted (8 door slabs, both beat-02 hazards, all three belts, the paddle wheel, the foam pit); the pads, maces, hammer and finishing cross were never reached | NOT RUN |

## Outstanding for every course

These are the nine items `CourseQA` reports NOT RUN, and they are why no course reports PASS:

1. 8.2.5 `Launch` edges from measured pad and fan trajectories are not in the graph, so loophole
   question 4 (launch-past) is unproven for every gate on every course.
2. 8.2.6 time-expanded dynamic-state graph.
3. 8.4 lane cross-section hazard coverage and blocked fraction >= 0.4 per pendulum/hammer crossing.
4. 8.4 measured shove travel from five real-player contacts per hazard and direction.
5. 8.4 bumper chicane centreline/edge/slalom avoidance probes.
6. 8.4 line-of-sight readability (>= 15 studs of approach) corroborated by screenshots.
7. 8.5 deliberate missed-timing real-player contact at every encounter, and the interactive
   keyboard run (Ball Barrage has the interactive run; no other course does).
8. 8.5 thirty-rider start load test and the Studio local multi-client session.
9. 8.6 fixed-camera captures and the `bad-map-refs` comparison (**done for DoorDash and TumbleTunnels**; still outstanding for Ball Barrage and Whirlpool Waltz).

Also outstanding and not on that list:

- The mesh-level seam pass. `auditGeometry` compares oriented extents, and HANDOFF 8.3 says outright
  that a box test cannot decide mesh penetration.
- Palette and dressing (section 7 override 1) are declared in every course document but the builder
  applies no recolouring or dressing; all four courses ship in the kit's own source colours.
- **Tumble Tunnels' scripted trials did not complete.** The harness published its build evidence and
  then ran for 3.5 hours without writing a result, against an 8-trial / 150-second-per-trial budget
  that should bound it at about 25 minutes; the rig was sampled repeatedly and was always alive and
  walking, so the cost is in the harness (most likely `buildRig`'s per-trial
  `CreateHumanoidModelFromDescription`, an async web call with no timeout) rather than in the course.
  No trial numbers are claimed for it.
- A user mid-skill calibration run, which 8.5 requires wherever proxy results and interactive
  experience disagree.

## Known limits of the evidence

- All physics and timing figures come from one machine, server-owned R15, in Studio Play. They are
  not 60 Hz, latency or 30-player measurements and are not labelled as such.
- The scripted policies are reproducible proxies, not human skill classifications. They walk straight
  lines: they cannot read a sweeping hole in a rotating plate, time a Big Ball cap, or choose a door
  channel on anything but the centre-out order the harness gives them.
- Graph sampling is finite-resolution. Surface cells are sampled at the calibration's step with a
  finer pass near edges and holes, and edges are tested against gate volumes every 0.5 studs. That
  is a measurement, not an analytic proof, and narrow or phase-dependent cases still need real
  traversal to corroborate.
- Three harness bugs and two audit defects were found by executing these checks rather than by
  reading them; any figure recorded before 2026-09-16 should be re-read against
  `docs/splashdown/03-overrides.md` and the changelog before it is quoted.
