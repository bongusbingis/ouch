# Splashdown completion handoff

Snapshot: 2026-09-15. Repository: C:\Users\jackc\desktop\ouch.
Revised 2026-09-15 after user review. Appendix B lists every change from the original handoff; the changes are applied in place below.

## 0. Read this first: authority and next action

1. This file is an implementation specification for a successor. Writing this file did NOT execute Gate 3 or any later work.
2. Gate 1 is approved. Gate 2 is approved (user, 2026-09-15). **Gate 3 is APPROVED (user, 2026-09-15, after an interactive Studio playtest)**, with one tuning correction applied post-approval. Section 11 has built Whirlpool Waltz, Door Dash, Tumble Tunnels and Tiptoe Trials; the next work is PistonPeak and Summit hardening — read section 1.4 before touching Splashdown code.
3. Run the read-only health checks in section 2 first, same as always.
4. The original brief has Gates 1, 2 and 3. The work after Gate 3 is the remaining-course stage and final verification, not an already-approved extra gate.
5. Do not publish, deploy, push a branch, or open a PR without explicit user authorization. Local commits are part of the requested workflow.
6. The user explicitly rejected preserving deprecated courses. At the validated replacement swap, delete the six superseded parked course models and retire all seven old recipes/registrations. Do not make a Deprecated folder, model archive, or old-course source export. Keep Summit Splash.
7. Use this handoff together with the checked-in findings, inventory, kit contracts and evidence. Do not treat historical findings as current runtime behavior where 02-kits.md supersedes them.
8. Four design overrides and four blocker decisions from the user (2026-09-15) are applied in place (principally sections 1.2, 2.1, 3.2, 4, 5, 5.2, 6, 7, 8.4, 8.5, 9.8, 10, 11, 12, 13, 14 and 15) and listed in Appendix B. Copy Appendix B into `docs/splashdown/03-overrides.md` and `docs/splashdown/changelog.md` as your first commit. Where an older docs/splashdown file (gate-1-plan.md, 02-kits.md usage notes) conflicts with this revision, this revision wins.
9. Work under the context-budget rules in section 2.4: delegate mechanical work to subagents, keep large outputs in files, and refresh section 1 of this file at every gate and before context runs low.
10. A requested operation that cannot meet these instructions is a STOP, not permission to substitute an estimate, fake evidence, change round flow, or weaken a check.

## 1. State snapshot

### 1.1 Git

| Item | Recorded value |
|---|---|
| Branch | feature/splashdown-hazard-kits |
| HEAD before this handoff | f866f7fa8cda958792f588dbcdc605e6161ed3f2 |
| HEAD now | the hazard-reach fix pass of 2026-09-16: `c74a288` (Ball Barrage + the new regression), `2dcaa8a` (Door Dash) and `5115e68` (the four-course re-audit and this refresh), on top of `dc6051f`, the Piston Peak handoff note |
| Discovery/Gate 1 commit | 7209026 |
| Baseline before discovery | 059e509 |
| Worktree now | Clean except `src/shared/UI/Components/Onboarding/GestureHint.luau`, modified by a PARALLEL session — not part of this task, never staged, do not touch it. **A parallel agent also COMMITTED into this checkout mid-task on 2026-09-16**, authoring `c74a288` and `2dcaa8a` from this session's uncommitted working tree while it was still being edited. The content was correct, but assume the index and HEAD can move under you: re-run `git status` before every `git add`, and check `git log` before assuming your own work is uncommitted. |
| Remote delivery | No push or PR performed |
| New courses built | **ALL SIX.** Ball Barrage (Gate 3 APPROVED; **hammers and pistons remounted 2026-09-16, hash now `7a46da9c`**), Whirlpool Waltz (8.5 blocker intentionally SKIPPED per user decision), Door Dash (scripted trials FAILED 0 of 8; **large hammer rehung 2026-09-16, hash now `aae4c298`**), Tumble Tunnels, Tiptoe Trials and **Piston Peak**. All six are LIVE in `CourseOrder`, promoted, and re-audited under the corrected surface sampler. |
| Summit layout hardened | No -- **this is the next item, and section 12's replacement transaction is the one after it. Both need the user, not a successor's initiative.** |
| Deprecated courses removed | No |

Changes since the recorded HEAD (all real, evidenced commits, not just this file):

~~~text
5115e68   test(splashdown): re-audit four courses under the corrected surface sampler
2dcaa8a   fix(splashdown): hang Door Dash's inert hammer in reach
c74a288   fix(splashdown): mount Ball Barrage's hammers and pistons in reach
dc6051f   docs(splashdown): record the Piston Peak commit id in the handoff
f76b621   feat(splashdown): build Piston Peak
0dead56   docs(splashdown): record the Tiptoe Trials commit id in the handoff
3e62299   feat(splashdown): build Tiptoe Trials
159bedb   docs(splashdown): record the Tumble Tunnels commit id in the handoff
1ead82a   feat(splashdown): build Tumble Tunnels
1859788   feat(splashdown): build Door Dash
cea63ab   feat(splashdown): put Ball Barrage and Whirlpool Waltz into rotation
a916bbe   test(splashdown): record Whirlpool Waltz's failed scripted trials
2bc53e3   docs(splashdown): add the per-course QA acceptance matrix
3594537   docs(splashdown): correct the stale section 5 interface status
17ccec7   feat(splashdown): build Whirlpool Waltz
6fffdcc   docs(splashdown): record Gate 3 approval and the pilot tuning pass
4c040b6   fix(splashdown): lower Ball Barrage BigBall mount height
f0a3121   docs(splashdown): record the Gate 3 pilot commit ids in the handoff
0198708   feat(splashdown): build the Ball Barrage pilot course
81a8cbe   feat(splashdown): add guide-driven course builder and independent QA
0494b88   docs(splashdown): refresh handoff state after section 4 completion
cfe33e3   feat(splashdown): export and verify source-only kit/Summit/arena assets
04ced53   docs(splashdown): record Gate 2 approval and revised handoff overrides
~~~

`04ced53` copied Appendix B into `docs/splashdown/03-overrides.md` and the changelog (no code).
`cfe33e3` completed section 4. `81a8cbe`/`0198708` are the builder/QA infrastructure and the Ball
Barrage pilot; `4c040b6` is its post-approval BigBall tuning pass. `17ccec7` plus three follow-up
doc/test commits are Whirlpool Waltz. `cea63ab` puts both into the live `CourseOrder` and adds
their intro-camera entries. Do not reset any of them.

Gate 1 delivered:

- docs/splashdown/00-findings.md: lifecycle, actual movement, existing kits, baseline faults, Studio/tooling limits.
- docs/splashdown/01-asset-inventory.md: 176 source roots / 222 BaseParts, dimensions/pivots, screenshot crosswalk and course usage.
- docs/splashdown/gate-1-plan.md: approved headlines, replacement policy and compatibility decisions.
- Discovery JSON, actual Studio screenshots and reproducible probes listed in the exact-file appendix.
- No course layout, registration, arena name list, or shared tuning changes in discovery.

Gate 2 delivered:

- Nested attribute Rotor composition; opt-in server rider carry; asymmetric hammer and piston profiles.
- BigBall, Conveyor, FallingTile, Seesaw, authoritative multiple BeachBalls and directional fan/ball airflow.
- Per-pad LaunchSpeed fix; precise collision contact, per-part cooldown/guard overrides, client-only impact/shake ghosts.
- Door row validation; reusable rising-liquid trajectory preserving Summit's old schedule.
- Strict attribute preflight, duplicate-owner rejection, headless tests, engine TestEZ tests, real-mesh physics/contact/client probes.
- docs/splashdown/02-kits.md and changelog. No declarative course builder or course-wide QA module yet.

Local commits after discovery, newest first:

~~~text
f866f7f fix(splashdown): reject duplicate hazard motion and contact owners
6e66c97 docs(splashdown): record Gate 2 kit contracts and measured QA evidence
2db3642 test(splashdown): integrate kits and verify attribute clone contracts
34a4cf2 feat(splashdown): extract reusable rising liquid with Summit parity
9a6a5d9 fix(splashdown): validate unique contiguous Door Dash rows
fae4989 feat(splashdown): add precise rotor shoves and impact cues
30b214a feat(splashdown): add precise bumper contact and response overrides
4279369 fix(splashdown): honor per-pad launch and float settings
7967f3d feat(splashdown): add directional attribute fans and ball airflow
975057e fix(splashdown): support renamed server-owned beach balls and cleanup
c5586af feat(splashdown): add deterministic rider-weighted seesaws
052a6cf feat(splashdown): add server-owned falling tile countdowns and reset
ac1f263 feat(splashdown): add signed conveyors for runners and beach balls
1742fbd feat(splashdown): add Big Ball cap bounces and side roll-off
a67383f feat(splashdown): add client-only hazard shake and impact ghosts
facc358 feat(splashdown): compose nested rotors and authoritative course rides
~~~

### 1.2 Verified, with limits

| Evidence | Actual result | Do not infer |
|---|---|---|
| Headless runner at recorded HEAD | 984 tests, 0 failures (2026-09-16) | Full Studio or course acceptance |
| Changed Luau formatting/lint | StyLua pass; runtime-source Selene 0 errors/warnings/parse errors | Unchanged whole-repo files were all linted |
| Studio isolated kit TestEZ | 25 passed, 0 failed, 0 skipped | Existing course contract passed |
| Original-mesh R15 physics | 18 trials: nine scenarios twice | Multiplayer/latency/60 Hz certification |
| Slide carry | 878/878 and 820/820 supported frames; max drift .0108/.00256 studs | Every slope/character configuration |
| Spin carry | 915/915 and 776/776 supported frames; max drift .00056/.000596 | Networked 30-player stability |
| Seesaw | 10.67-degree tilt, retained support; .028 degrees after 2 empty seconds | 30-rider symmetry/clamp behavior |
| Conveyor commanded 15.6 | Idle runner 14.31–15.68 studs/s; ball about 8.18 | Commanded belt speed equals ball speed |
| BigBall | Cap launch 58; side displacement 3.26–5.62 studs in .6 s | Speed times hold equals guaranteed shove distance |
| Fan on ball | Axial peak 13.59–14.28 in .5 s before leaving column | Steady 32 studs/s was observed |
| Falling tile | Drop .653–.657 s; restore about 1.655 s with 1 s respawn | A never-respawn critical path is safe |
| Actual Player mesh contacts | Bumper 54; seven Rotor mesh responses about 48; holds created; Foam .45 then cleared | Traversal, edge reach or unavoidable contact |
| Client effects | Noncolliding/query/touch ghost; source Size/CFrame unchanged; visibility and ghost cleanup passed | Screenshot capture succeeded |
| Movement | 22-stud flat gap succeeds; 22.25 fails. 11.5-stud ledge succeeds; 11.75 fails | Universal avatar-envelope limit |

Physics was measured on one machine, server-owned R15, often approximately 400 Hz. Record that limitation unchanged. Source measurements are in evidence/movement*.json and evidence/kit-*.json.

Section 4 status (2026-09-15, commit cfe33e3): COMPLETE. `ServerStorage.SplashdownAuthoringSources`
(Kit/SummitSource/ArenaSources) staged live in the connected place; exported to
`assets/splashdown/{kit,summit,arena}-source*.rbxmx`; SHA256 hashes and counts in
`docs/splashdown/evidence/source-hashes.json`; round-trip reimport verified 222/222 BaseParts with
zero diffs (path/ClassName/Size/MeshId/CanCollide); actual fixed-camera screenshot saved to
`docs/splashdown/evidence/kit-source-capture.png`. `.gitattributes` marks `*.rbxmx` as `-text` so
CRLF normalization never invalidates the recorded hashes. Desktop UI automation needed a real
window, which this session lacked until a computer restart (see the changelog entry for the exact
diagnostic: BitBlt failures, `capture_studio.py` "window not found", zero-window Win32 EnumWindows).

Still NOT verified or implemented:

- The active template folder (ReplicatedStorage.Assets.Maps.Splashdown) was empty because the user moved the original course contents into Workspace.LegacyCourses. That is expected, not a baseline defect. Eight legacy IDs were registered; seven parked models exist in LegacyCourses; CrossCurrent has none. The old asset TestEZ suite was 0/16 as opened and 14/16 with temporary legacy copies; those numbers reflect the empty folder, not successful tests. You may copy the parked models into the templates folder whenever a working baseline is needed for lifecycle/regression tests.
- The repository has no Studio-authored places/arena/*.rbxl base, so the CD build script cannot complete. By user decision (2026-09-15) that base and the CD build are out of scope for this task; section 12.2 is withdrawn. Rojo code synchronization is still not an authored-model backup, which is why the section 4 source exports (now done) were required.
- Every section 5 interface now exists and has been executed at least once: AssetManifest, CoursePresets, CourseBuilder, CourseAuthoring, CourseGraph, CourseQA, the CourseSpecs for BallBarrage and WhirlpoolWaltz, `places/arena/tests/Assets/SplashdownQA.spec.luau`, `src/shared/Tests/CourseGraph.spec.luau` and `CourseVariety.spec.luau`, all three Play probes under `docs/splashdown/probes/`, and `src/scripts/studio/author-splashdown-v2.luau`. **`docs/splashdown/qa-report.md` is the one listed artefact that still does not exist.** Section 1.4 is the current state.

### 1.4 Section 11 progress — ALL SIX new courses are built; Summit hardening and section 12 are next, and both need the user

**Gate 3 remains approved** (user, 2026-09-15, interactive Studio playtest of Ball Barrage). Section
11 has now built **all five of its remaining courses**: **Whirlpool Waltz** (2026-09-15; its 8.5
blocker is intentionally SKIPPED per the user's 2026-09-16 decision), **Door Dash**, **Tumble
Tunnels**, **Tiptoe Trials** and **Piston Peak** (2026-09-16, the session this section describes).

**The next item in section 11's order is Summit Splash hardening, and the item after it is section
12's final replacement transaction. Neither was started.** They are a different kind of work from
building a new course — 7.7 patches an existing course the user asked to keep, and 12.1 is a real
production cutover that permanently deletes six parked models and retires seven recipes with no
archive — so this session stopped here deliberately rather than carrying on.

`src/config/Gameplay/Splashdown.luau`'s `CourseOrder` is `{"BallBarrage", "WhirlpoolWaltz",
"DoorDash", "TumbleTunnels", "TiptoeTrials", "PistonPeak"}` and
`ReplicatedStorage.Assets.Maps.Splashdown` holds exactly those six promoted templates. **Every course that enters `CourseOrder` needs its
`Intro.Courses` entry in `src/config/Interface/SplashdownIntro.luau` in the SAME change** —
`SplashdownIntroModel.spec.luau` asserts it and the headless suite fails otherwise. Piston Peak's
entry is in place. Headless is **984 tests, 0 failures**.

#### The 2026-09-16 hazard-reach pass — READ THIS BEFORE 1.4's older entries

The user chose this over carrying on building: fix Ball Barrage's inert hammers and pistons, then
re-audit the four courses whose cut sets were measured with the OLD surface sampler. Both halves are
done. **Nothing in Summit hardening (7.7) or section 12's transaction was started, and both still
need the user.**

**Ball Barrage's two pistons and two hammers now reach the lane, measured on the rebuilt template.**

| Hazard | Before (on `ca5e95b4`) | After (on `7a46da9c`) |
|---|---|---|
| `Piston01` head | side +16.30..+24.02 against a lane half-width of 10.51 — 5.79 to 13.51 studs past the edge, over open water | side **+2.484..+10.198** at rest, swept **−3.516..+10.198**: 3.52 studs past the centreline on the punch |
| `Piston02` head | mirrored, side −24.02..−16.30 | side **−10.197..−2.483** at rest, swept **−10.197..+3.517** |
| `HammerLarge` head | Y 5.694..24.456 under a deck at Y 24.000 — top **0.46 studs** at deck level | swept Y **24.600..46.406** = deck **+0.600..+22.406**, side ±5.558 at rest and **±10.872** swept |
| `HammerSmall` head | Y 5.804..25.356 — top 1.36 studs | swept Y **24.600..45.815**, side ±4.117 at rest and **±10.370** swept |

The pistons were a mounting sign: `obstacle_22`'s head lies along the piece's own forward at a
measured 13.160 studs from the base at scale 0.5, so a base INSIDE the lane facing outward throws the
head away. `OffsetSide` is now ±19.5 (base outside, head reaching in, as Piston Peak mounts its
three) and `OffsetAlong` moved from −30/−14 to −24/−8 so both stand over Floor04's flat deck rather
than off its end over Ramp04's slope. The hammers were a mount height: both sources hang their heads
a measured 8.925 and 8.420 studs BENEATH the housing at scale 0.6. `OffsetUp` is now
`hang + hypot(halfX, halfY) + 0.6` = 20.428 and 19.627 — derived from the SWING, because the head
rocks about its OWN centre (CoursePresets clears every display pivot), so its maximum vertical
half-extent is `hypot(halfX, halfY)` at 30.7°/22.8°, not `halfY`. Hanging to that maximum is what
keeps the head out of the floor at mid-swing; Tiptoe Trials' constants used the rest pose only and
let its heads dip 1.5 studs into the deck at mid-swing. Ball Barrage's `CourseQA.check` afterwards:
**zero errors, zero warnings, 48 PASS / 14 NOT RUN / 0 FAIL**, all six gate cut sets holding over a
14,977-node / 2,392,356-edge graph from 18,548 cells. Re-staged and re-promoted; the Edit stage and
an independent Play build agreed on `7a46da9c` / 143 BaseParts.

**Door Dash had the identical hammer defect and it is fixed the same way.** Its `HammerLarge` measured
Y 5.694..24.456 under a deck at Y 23.997 — the same 0.46 studs. `OffsetUp` is now the same 20.428
expression; the head sweeps deck **+0.600..+22.406** and side **±10.872** across a ±9.11 lane. Rebuilt,
re-staged, re-promoted: hash `8c00a748` → **`aae4c298`**, 221 BaseParts, route 882.067, zero errors,
zero warnings, all six gate cut sets holding.

**New regression, and the general form of both bugs.** `SplashdownQA.spec` gained **"sweeps every
shoving hazard through its own beat's lane"**. For every `Rotor` + `Shove` part it drives the REAL
`RotatingPlatforms` motion — `build` then `rotorPoseAt` over 240 samples across 12 seconds, so a
hammer's windup+strike, a piston's period and every spin all cycle — takes the rotor part AND its
followers (so a mace's reach is its ball's and a piston's is its head's), and requires the swept
volume to contain a lane point at the calibration's own measured `RootOffsetStuds` of 3.5 above the
deck. The lane comes from the BuildReport's route steps with their MEASURED `HalfWidth`, excluding
`Mount` and `Flank` steps whose half-extent is the hazard's reach rather than the deck's. Hazards
with `RotorCarries` (swing panels, log-rolls) are exempt and reported by name. It fails both original
bugs: the pistons laterally, the hammers vertically.

**Two test bugs the re-audit exposed, both fixed:**

1. `"mounts every piston head where it can actually strike a runner"` ended in `expect(heads > 0)`,
   which FAILS on the four courses that place no piston. It had only ever been run against Piston
   Peak. It now counts `Preset == "Piston"` pieces in the spec and asserts `heads == declared`.
2. `"clones each declared sub-part once"` keyed only on PieceId plus position, and a disc is a hub
   with a CONCENTRIC plate: Whirlpool Waltz's `obstacle_15` and `obstacle_26` rides put a 29.9-stud
   plate and a 6.5-stud hub on the same centre and were reported as doubled. The key now includes
   Size, because a real duplicate is the same geometry twice.

**The four-course re-audit under the corrected sampler — every result holds.** Zero errors, zero
warnings and every gate cut set still a true cut set (0 of 30 spawn cells bypass any gate) on all
four. The counts moved, and it is worth being precise about WHY: the old recorded runs also predate
the Tiptoe session's launch-edge pass, so the edge explosion is mostly launch edges, not the sampler.
The sampler shows up in the CELL and NODE counts, and only Door Dash — the one course with real
stacked geometry, its door-corridor roof — moved much.

| Course | Cells | Nodes | Edges | Gates |
|---|---|---|---|---|
| Ball Barrage (`943e493c` → `7a46da9c`, spec also changed) | 18,446 → 18,548 | 14,881 → 14,977 | 340,357 → 2,392,356 | 6/6 hold |
| Whirlpool Waltz (`2fbc899c` → `78e562b8`) | 14,844 → **14,844** | 12,181 → **12,181** | 383,518 → 836,683 | 6/6 hold |
| Door Dash (`8c00a748`, sampler only) | 38,241 → **40,121** | 28,121 → **29,921** | 1,272,671 → 3,359,436 | 6/6 hold |
| Door Dash (`aae4c298`, after the hammer fix) | 40,121 | 29,918 | 3,366,017 | 6/6 hold |
| Tumble Tunnels (`d390ff50`, unchanged) | 28,807 → 28,879 | 20,739 → 20,788 | 789,860 → 1,168,827 | 7/7 hold |
| Tiptoe Trials (`0f8e9510`, unchanged) | 16,171 → 16,299 | 14,680 → 14,774 | 1,309,689 → 1,314,869 | 6/6 hold |

Whirlpool Waltz's cell and node counts are IDENTICAL, which is the expected result for a course with
no stacked storeys and is the cleanest evidence that the sampler fix neither lost nor invented
geometry. Piston Peak was re-run as a control and reproduced its recorded 15,945 cells / 13,886 nodes
/ 1,854,187 edges **exactly**, which is what says the pipeline itself did not move underneath the
comparison.

Studio TestEZ over all six courses, across three Play sessions: **21 assertions each, 126 in total,
0 failures**, including the new swept-reach check and the two corrected checks above. Every course's
`docs/splashdown/evidence/courses/<Id>/qa.json` was republished through the evidence sink and is
current; they were all reformatted to 2-space indent with sorted keys, so from here their diffs are
content diffs rather than key-order churn.

**Still outstanding and unchanged:** the whole scripted-trial / interactive-playtest category (user's
standing 2026-09-16 decision), `docs/splashdown/qa-report.md`, the per-course palette, and
`Courses.DoorDash`'s Difficulty 3 against section 12.1's list of 2.

#### Piston Peak, as built

- Spec `src/shared/Game/Splashdown/CourseSpecs/PistonPeak.luau`; doc
  `docs/splashdown/courses/piston-peak.md`; evidence
  `docs/splashdown/evidence/courses/PistonPeak/qa.json`, its two fixed-camera captures and its entry
  in `evidence/course-cameras.json`.
- **Spec hash `e164c528`, 162 BaseParts, 880.000 measured studs of route** against the 880 target,
  six ordered checkpoints, beats 0.909-1.050 of their scaled section 7.6 targets, elevation
  +12/+12/+6/+6/+12/+12/+6 matching section 7.6 exactly, StartY 0 and finishY 66, zero attribute
  errors, zero route errors, zero bounds violations, identical hash AND part count across a double
  build. Promoted, 327 descendants.
- `CourseQA.check` returns **zero errors and ZERO WARNINGS**; 50 findings PASS, 11 NOT RUN with
  reasons, 0 FAIL. All seven gate cut sets hold (0 of 30 spawn cells bypass any gate) over a
  13,886-node / 1,854,187-edge graph from 15,945 real surface cells, and all twelve cross-course
  checks pass over the six staged specs. Studio TestEZ: **20 passed, 0 failed** (the 17 existing
  assertions plus three new ones: piston-head reach, log-roll frame height, rising-liquid flood
  regression).
- New in the builder: **`Layout.Kind = "StackedSwitchback"`**. Its guide IS a polyline, unlike an
  Archipelago's island list, but a polyline that deliberately retraces itself: a switchback staircase
  in plan view is a rectangle walked in one rotational direction, so runs 1/3/5 share one centreline
  and runs 2/4 share the other one lane pitch away. Six enforced invariants — an odd segment count of
  at least five with runs on the odd ones and one lane pitch on every even one, `LanePitch` inside a
  declared 30-40 band, runs and crosses each alternating through 180 degrees with every turn a
  same-handed right angle, every run's MEASURED elevation climbing, two runs sharing a centreline
  separated by more than a declared clearance that must itself beat the measured 11.5-stud step-up,
  and no measured pair of route steps on different runs saving at least `MinBypassStuds` of route
  inside the ordinary jump reach for its own rise unless a declared guard wall stands across the line
  between them. New `GuardWall` and `RotorAxis` piece fields; new `LogRoll` preset; new
  `Layout.Rise` for the section 6 rising liquid with a measured checkpoint-clearance assertion.
  `AssetManifest` is version 6 with `wall_001`, `wall_002`, `trampoline_2_001`, `obstacle_10_001` and
  a `ContactRadius` on `obstacle_2_001` measured in.
- **The rising liquid is real and tuned once, from a measurement.** Section 7.6's seed (baseY -30,
  delay 20, 0.4 studs/s, MaxHeight 60) stops the flood at world-local +30 and drowns the checkpoints
  at Y 12 and Y 24 — a racer respawning on a submerged pad splashes and respawns on it again. 7.6's
  own remedy is to lower MaxHeight in 2-stud steps; 60 down to **38** stops it at +8, four studs
  under the lowest pad, and `CourseBuilder` now measures that clearance and fails the build below it.
  The flood still reaches the start plaza at 95 s and finishes at 115 s against the 180-second cap.
  `Courses.PistonPeak.LavaRise` records the same schedule in Summit's Studs/DelaySeconds/Seconds form.
- **Its scripted trials were NOT COMPLETED**, per the standing 2026-09-16 decision. No trial numbers
  are claimed. The interactive keyboard run, the deliberate missed-timing contacts and the
  checkpoint-recovery run are outstanding for this course exactly as for the other five.

#### What Piston Peak exposed — carry these forward

1. **[FIXED 2026-09-16 — see the hazard-reach pass above. Door Dash had the same hammer defect and
   is fixed too.] Ball Barrage's two pistons are INERT, and its two hammers are effectively inert
   too. Measured, not inferred, on the promoted template.** Piston01's head sits at world Z 76.16 spanning
   72.30-80.02 while its beat-03 lane spans Z 45.49-66.51 — the head sweeps 5.8 to 9.7 studs BEYOND
   the lane edge over open water, and Piston02 is the same mirrored. The cause is the mounting sign:
   the head lies along the piece's own forward, so a base placed INSIDE the lane facing outward
   throws the head away from the runner. Piston Peak mounts them the other way (base outside, head
   reaching in) and the new `SplashdownQA.spec` assertion "mounts every piston head where it can
   actually strike a runner" is written generically, so **running it against BallBarrage will fail —
   that failure is the evidence.** The hammers: HammerLarge's head spans Y 5.70-24.46 under a lane
   whose top is Y 24.00, so only its top 0.46 studs ever reach deck level. Neither was fixed; Gate 3
   was approved with them and that is the user's call, not a successor's.
2. **[RE-AUDIT DONE 2026-09-16 — all five earlier courses re-measured under the fixed sampler; every
   cut set still holds. See the table in the hazard-reach pass above.] A per-part sampling window
   silently hid four fifths of a stacked course.**
   `CourseQA.sampleSurfaces` samples each X/Z column once — which is what keeps it tractable — but it
   used the vertical window of whichever PART claimed the column first. On a flat course nothing is
   stacked so it never mattered; on this tower the first run's slab claimed the column and the four
   storeys above it were never sampled, and the audit reported the route unreachable because the cells
   did not exist. The window is now the whole model's vertical extent and the per-column stacked
   budget went from 12 to 24 hits. Every course's graph is more complete for it, and any course whose
   cut sets were previously clean should be re-audited before section 12 signs them off.
3. **That made the graph five times denser, which broke the cut-set pass outright.**
   `CourseGraph.edgeCutByGate` walked every edge at half-stud resolution once per gate; at 1.85
   million edges Studio killed the script. It now rejects on an axis-aligned bounding-box test first
   (which cannot change a verdict) and `reachingNodes` takes an optional cooperative yield the engine
   caller supplies. The headless graph tests pass nothing and it stays a pure function.
4. **A tall stock frame standing on a lower storey of a tower is a ladder.** The log-rolls were
   `obstacle_2_001`, whose cradle is 32.284 studs tall above its own mount. The cut-set audit measured
   standable cells on the frame at Y 28 and Y 41 above a run-2 deck at Y 24, then a jump from the
   frame top onto beat 06's ramp at Y 53: three beats skipped and both the 05 and 06 gates bypassed by
   all 30 spawn cells. Replaced with `obstacle_10_001`, the kit's single-mesh barrel, laid on its side
   — no frame at all, and its own crest is 4.67 studs above the deck. This is Tumble Tunnels'
   staircase lesson in a fourth form: on a stacked layout, check the HEIGHT of every prop, not just
   its footprint.
5. **A hazard that reaches past the lane centreline at rest can seal the lane between siblings.**
   Three pistons alternating sides at mount distance 17 each reached 0.02 studs past the ledge
   centreline at rest; between them their rest poses covered the whole corridor, no standable cell
   survived the headroom filter, and the ordered-route audit failed. At 19.5 each head leaves a
   4.96-stud corridor at rest and still seals the ledge edge to edge when it fires. Check a periodic
   hazard's REST pose against its neighbours, not just its swept envelope.
6. **A right turn leaves through `SideNegativeX`, not `SidePositiveX`.** `CourseBuilder.cornerRun`
   picks the socket by direction, and `water_platform_001`'s two side sockets differ. Using the wrong
   one put a hairpin 0.11 studs past its vertex and failed the build. The spec now spells both numbers
   out and derives the seesaw plank's scale from the slot they leave.
7. **QA gate volumes are not route geometry.** A gate spans 22 studs below a beat entrance to 38
   above; on a course that climbs 66 studs that reaches Y 98 and broke HANDOFF 5.1.10's -30..90 band
   even though the real geometry tops out at 80.1. `auditBounds` now reports gate extents separately
   (`GateMinY`/`GateMaxY`) and holds them to the 600-corner rule only, on the same reasoning that
   already excluded the perimeter ring and the liquid plane from that band.

#### Tiptoe Trials, as built

- Spec `src/shared/Game/Splashdown/CourseSpecs/TiptoeTrials.luau`; doc
  `docs/splashdown/courses/tiptoe-trials.md`; evidence
  `docs/splashdown/evidence/courses/TiptoeTrials/{build,qa}.json` and its two fixed-camera captures.
- **Spec hash `0f8e9510`, 160 BaseParts, 880.406 measured studs of route** against the 880 target,
  five ordered checkpoints, beats 0.929-1.106 of their scaled section 7.5 targets, elevation
  +12/-6/+6/+12/0/-6 matching section 7.5 exactly, zero attribute errors, zero route errors, zero
  bounds violations, identical hashes AND part counts across a double build.
- `CourseQA.check` returns **zero errors and ZERO WARNINGS**; 45 findings PASS and 10 are NOT RUN with
  reasons. All six gate cut sets hold (0 of 30 spawn cells bypass any gate) over a 14,680-node /
  1,309,689-edge graph from 16,171 real surface cells, all twelve cross-course checks pass over the
  five staged specs, and the largest flat square is 23 x 23 (the tightest margin in the set — the
  Midhop landing rock, 31.68 studs across at scale 0.85). Studio TestEZ: **17 passed, 0 failed**
  (the 16 existing assertions plus the new falling-tile kit regression).
- New in the builder: **`Layout.Kind = "Archipelago"`**, the first layout with NO guide polyline. An
  archipelago's guide is its island list: each island declares a polar anchor the route must arrive
  at, which binds the build far harder than a length cap would, so an Archipelago does not cap segment
  travel at all. Six enforced invariants — at least five islands entered once each in order, strictly
  monotone anchor radii from perimeter to centre, every island after the first entered by a measured
  LAUNCH (longer than the ordinary jump for its own rise, inside its own tool's reach, preceded by
  that tool) or TILE GROUP (flush arrival past two or more chained tiles), every island beginning on a
  round landing deck, every heading change on such a deck within `MaxTurnDegrees`, and non-consecutive
  islands separated by more than the worst launch the course can produce. New `Island` piece kind;
  `Ride` extended to turn on a declared `TurnDegrees` outside a Spiral; `RouteStep` gained `Island`
  and a MEASURED `HalfWidth` (oriented support width projected onto the route's right vector), which
  the separation audit subtracts instead of a declared budget. `AssetManifest` is version 5 with
  `color_box_001..008`, `trampoline_5_001` and `obstacle_11_001` measured in.
- **Every reach in this layout is derived, not declared.** The spec states HANDOFF 3.2's measured
  constants and the builder solves the ballistic problem per crossing, calibrated by the measured
  22-stud flat gap against the model's own 21.23 prediction. Measured: worst launch reach 38.89 studs,
  worst non-consecutive island separation 53.02 studs, three launches at 20.5 / 26.0 / 27.5 studs each
  with 2.4-4.0 studs of margin over an ordinary jump and 2.5-3.9 under their own reach.
- **Its scripted trials were NOT COMPLETED**, per the standing 2026-09-16 decision. No trial numbers
  are claimed. The two bounded guards this section recommended WERE applied to
  `run-course-routes.server.luau` and are **unexercised**: the engine rig is fetched once and cloned
  for later trials instead of one `CreateHumanoidModelFromDescription` per trial, and the pass has a
  2,400-second wall clock that stops it starting new trials and reports `abandonedTrials`. The
  interactive keyboard run, the deliberate missed-timing contacts and the checkpoint-recovery run are
  outstanding for this course exactly as for the other four.

#### What Tiptoe Trials exposed — carry these forward

1. **`CourseQA.buildGraph` had no launch edges at all, for any course.** It built only Walk and
   ordinary Jump edges, so a 26-stud pad launch simply did not exist and the first audit of this
   course reported the Checkpoint05-to-Finish leg unreachable. HANDOFF 8.2.5 asks for exactly that
   pass. It now reads each launch tool off the BUILT model (its own LaunchSpeed, FloatFactor and
   measured footprint), recomputes the reach for each candidate landing height, and adds Launch edges
   about the tool's own axis; a horizontal ball-pushing fan is excluded and reported by name. Every
   course's gate cut sets are stronger for it. `ENCOUNTER_TYPES` also had no `FallingTile`, which
   scored this course at 11 encounters and five types instead of 16 and six.
2. **Verify a kit sees its own parts, at the kit — third time.** After doors and beach balls, the new
   falling-tile regression in `places/arena/tests/Assets/SplashdownQA.spec.luau` drives the real
   `FallingTiles` kit over the built model: registers the tiles, arms one through the kit's OWN
   downward support raycast from a probe root, and asserts it stays solid mid-countdown, loses
   collision/query/visibility on expiry, and returns after `RespawnSeconds`. Do this for every kit a
   course is the first to use.
3. **A suspended hazard mounted "on the deck" can be entirely below the lane.** obstacle_3_001 and
   obstacle_4_001 are axle housings with their heads hanging 16.85 and 16.35 studs BENEATH them, so
   the pilot's OffsetUp-0 mounting sweeps the head under the floor where it can never touch a runner.
   Both hammers here hang at the height that puts the head's resting bottom 0.6 studs clear of the
   deck, under HANDOFF 8.3's suspended-pendulum exemption that Door Dash's maces already use. **Ball
   Barrage's two hammers are still mounted the old way and are worth re-checking.**
4. **A fan launches on COLUMN ENTRY, not at the edge.** Mounted on the deck, the beat 01 fan's
   6.19-stud column would have fired the launch 6.19 studs before the island's edge, needing 26.69
   studs of reach against the 22.96 a 48/0.2 launch makes over a 6-stud rise. It stands in the water
   seven studs past the shore instead, so the column's near edge is 0.81 studs past the island and the
   crossing is exactly the measured 20.5. The same applies to pads: the launch happens wherever the
   runner jumps ON the pad, so a large pad set back from the edge silently lengthens the flight.
5. **An asset's own proportions can rule out the standard plinth.** obstacle_11's plank clears its own
   fulcrum bar only within 4.253 * scale studs of the axle, so the platform_002 plinth obstacle_25 uses
   would be struck on every tilt. It stands on a single door panel at scale 0.269 — 1.69 studs thick,
   20.24 wide — which is thinner than the clearance and the same width as the bar it carries.

#### Tumble Tunnels, as built

- Spec `src/shared/Game/Splashdown/CourseSpecs/TumbleTunnels.luau`; doc
  `docs/splashdown/courses/tumble-tunnels.md`; evidence
  `docs/splashdown/evidence/courses/TumbleTunnels/{build,qa}.json`, its two fixed-camera captures and
  its entry in `evidence/course-cameras.json`.
- **Spec hash `d390ff50`, 163 BaseParts, 880.45 measured studs of route** against the 880 target,
  six ordered checkpoints, beats 0.880-1.124 of their scaled section 7.4 targets, elevation
  0/+6/-6/+12/-6/+12/+6/-12 matching section 7.4 exactly, zero attribute errors, zero route errors,
  zero bounds violations, identical hashes across a double build.
- `CourseQA.check` returns **zero errors and ZERO WARNINGS**; 43 findings PASS and the rest are NOT
  RUN with reasons. All seven gate cut sets hold (0 of 30 spawn cells bypass any gate) over a
  20,739-node / 789,860-edge graph from 28,807 real surface cells, all twelve cross-course checks
  pass over the four staged specs, and the largest flat square is 21 x 21. Studio TestEZ: **16
  passed, 0 failed** (the 15 existing assertions plus the new beach-ball kit regression).
- New in the builder: **`Layout.Kind = "Loop"`**, with five enforced invariants — five segments
  (run/cross/run/cross/stub), segments 1/3/5 parallel with 3 reversed, both crosses exactly
  `LanePitch`, four same-handed turns summing to exactly +-360 degrees, and the finish landing inside
  a declared closure window of the start plaza. A Loop also declares its spine (`SpineHalfWidth` plus
  the two tunnel piece ids) and the builder checks the outbound tunnel is on guide run 1 and the
  return tunnel on run 3. Tumble Tunnels measures a 69.55-stud closure through exactly -360 degrees.
  New presets `BeachBall`, `Seesaw` (a CHAINED surface, not a mount) and `Mallet`; new `PieceSpec`
  field `PitchDegrees`; `AssetManifest` is version 4 with five measured sources added.
- **Its scripted trials did NOT COMPLETE.** The harness published its build evidence and then ran for
  3.5 hours without writing `ServerStorage.SplashdownCourseRouteResults`, against its own 8-trial /
  150-second-per-trial budget, which should bound the pass at about 25 minutes. The rig was sampled
  repeatedly throughout and was always alive and walking under `Humanoid:MoveTo` — on the outbound
  run, at the east cross and back at the start plaza across successive resets — so the cost is in the
  harness, most likely `buildRig`'s per-trial `CreateHumanoidModelFromDescription` (an async web call
  with no timeout), not in the course. **No trial numbers are claimed.** Per the user's standing
  2026-09-16 decision this category is reported plainly and not chased; the interactive keyboard run,
  the deliberate missed-timing contacts and a user mid-skill calibration run are outstanding for this
  course exactly as they are for the other two.

#### What Tumble Tunnels exposed — carry these forward

1. **Stacked stock geometry becomes a staircase, for the third time.** Section 5.2 wants the finish
   "separated by enclosure so the finish is unreachable from the start plaza". A stack of six
   coincident `platform_002` props left a standable bevelled rim proud of each slab above it, and the
   cut-set audit found a 21-stud hop from the start plaza onto the third rim and a second hop from
   there straight onto the finish deck — **30 of 30 spawn cells bypassing all seven gates**. Two
   thinner door panels failed identically. Only ONE piece with no intermediate top worked: a single
   `door_002` at uniform scale 1.2. **Never stack stock slabs to make a wall; find one tall piece.**
2. **Verify a kit sees its own parts, at the kit.** The new
   `places/arena/tests/Assets/SplashdownQA.spec.luau` test drives the real `BeachBalls` kit over the
   built model and asserts the balls are authored anchored with no motion owner, sit under
   `Rotating/<group>/Assembly` at the depth the kit scans, and after one `tickWorld` are unanchored,
   colliding, server-owned and reparented into `Scriptables/BeachBalls`. Do the same for every new
   kit a course is the first to use — the Door Dash door-slab defect was invisible to the build and
   to the audit and only a kit-level assertion catches that class of bug.
3. **Uniform scaling couples a hazard's size to its container's.** A 0.5 paddle wheel is 29.91 studs
   across its axle and 24.02 tall above its mount, and no arch small enough to fit the route's
   straight run clears that. It is hung 8 studs below its deck instead, so its cradles sweep through
   rider height and the arch only has to clear 16. Likewise the horizontal fan stands at the tunnel's
   far mouth, not inside it: a 17.69-stud cage on its side does not fit under a 12.93-stud ceiling.
4. **A fan's column is a cylinder about the fan's own axis, not a box in front of it.** At scale 0.5
   the measured radius is 6.19 studs; a beach ball's centre is 2.33 studs up. Mounted with its
   Support at the deck, the pitched fan's axis sat 8.85 studs up and the balls were outside their own
   fan's column. `OffsetUp` now puts the axis at ball height.

#### Where the earlier five stand

Their templates and hashes were unchanged by the Piston Peak session: Ball Barrage `ca5e95b4`,
Whirlpool Waltz `78e562b8`, Door Dash `8c00a748`, Tumble Tunnels `d390ff50`, Tiptoe Trials
`0f8e9510`, plus Piston Peak `e164c528`. **The 2026-09-16 hazard-reach pass then moved two of them:
Ball Barrage is now `7a46da9c` (143 BaseParts) and Door Dash is now `aae4c298` (221 BaseParts). The
four current hashes are Whirlpool Waltz `78e562b8` (142), Tumble Tunnels `d390ff50` (163), Tiptoe
Trials `0f8e9510` (160) and Piston Peak `e164c528` (162).** All six are staged and promoted, and all
six have now been audited under the FIXED surface sampler. Their outstanding 8.5 items are unchanged.

#### The set-wide route-length target is fixed (section 11's prerequisite)

Recorded in `docs/splashdown/03-overrides.md` with its full derivation: **880 measured studs of route
arclength per course, and the section 7 beat targets are unchanged.** Ball Barrage measures 881.05,
Whirlpool Waltz 884.78, Door Dash 882.07, Tumble Tunnels 880.45, Tiptoe Trials 880.41. Tumble Tunnels is the first course
to use the SCALED beat targets from the overrides table (165/132/121/121/99/154/88) as its
`LengthTarget` values rather than the raw section 7 numbers; that is the healthier convention,
because 0.85-1.15 of the scaled targets brackets 880 instead of requiring every beat to sit near its
ceiling.

#### Tooling notes that save a successor real time

- **The Assistant's `execute_luau` cannot `require()` synced modules**, in Edit OR in Play, for
  ReplicatedStorage AND ServerScriptService modules. Anything needing a require runs from the
  **Studio Command Bar** (Edit) or a Rojo-synced probe Script (Play). It CAN read and write instances
  freely, create parts, clone models, drive a rig and raycast, which is enough for most measurements.
- **Edit-mode's `require()` cache does not invalidate when Rojo syncs a changed module.** Clone the
  whole `ReplicatedStorage.Shared.Game.Splashdown` folder to a temp sibling, `require()` the CLONE's
  module, then set the clone's `Parent = nil`. Use `Parent = nil` rather than `Destroy()`: **any
  Command Bar text containing the literal word `Destroy` pops a blocking "Dangerous Command
  Detected" dialog** that silently swallows the command until a human clicks through it.
- **The Command Bar can reach the network.** `HttpService:PostAsync` works from it, so an Edit-mode
  QA report can be posted straight into the repository through the evidence sink instead of being
  read back instance by instance. That is far cheaper than pulling a 10 KB StringValue through
  `execute_luau`.
- The Command Bar is at image (700, 857) on a 1600x900 screenshot of a 1920x1080 desktop, so click
  (840, 1028) after the 1.2 scale; the Run button is at (1888, 1028). **Type, then Ctrl+Enter
  immediately** — if anything steals focus between the two, the text sits there unexecuted, and a
  plain Enter afterwards only adds a newline and turns the bar multiline. Ctrl+Enter failed silently
  about a third of the time this session; **clicking the Run button at (1888, 1031) always worked**,
  and re-clicking it simply runs the same text again, so verify the effect rather than the keystroke.
  A staged model was also silently lost once to what looked like an Edit-mode undo of the staging
  operation — re-check `ServerStorage.SplashdownStaging` before `promote`, not just after `stage`.
- `CourseAuthoring.stage` parks the full `BuildReport` for every staged course in
  `ServerStorage.SplashdownStageReport` (and each route trace beside it), because the Command Bar's
  Output cannot be read back reliably; read it with an ordinary instance read afterwards.
- **For fixed-camera captures, lift the PREVIEW, not the arena**, 9,000 studs. `screen_capture` poses
  its own camera and does NOT leave the viewport there, so a window grab taken after it shows the old
  pose: set `workspace.CurrentCamera.CFrame` yourself through `execute_luau` first, then grab the
  window (crop 0,142-1180,1006 on this layout). **Set `CurrentCamera.Focus` as well as `CFrame`** —
  Studio's Edit camera controller recomputes the view from Focus and the first capture of this
  session came back looking at the horizon with the CFrame reading correct. `tools/capture_studio.py`
  has the window-focus/mss code to copy; 1.2 s of settle after `SetForegroundWindow` was enough. `workspace.Assets.Arena.Map.Model`'s exact pivot is
  `CFrame.new(-537.766602, 519.175659, -54.3143196)` and it never needs to move.
- A probe in Play, and the Edit Command Bar, can POST evidence straight into the repository through a
  localhost sink on `http://127.0.0.1:34875/`; `{path, data}` lands under
  `docs/splashdown/evidence/`. The sink is a scratchpad script, not checked in; rewrite it in ten
  lines when you need it.
- **`run-course-routes.server.luau` has no wall-clock budget of its own.** Its 150-second ceiling
  bounds one trial, not the pass, and on Tumble Tunnels the pass never returned. If a successor needs
  scripted trials, add an overall deadline and a `buildRig` timeout before starting one.
- `StringValue.Value` caps at 200,000 characters; the route harness writes numbered chunks.

#### Exact next actions

1. **STOP and get the user's direction.** Section 11's remaining item is **Summit Splash hardening**
   (section 7.7) and the item after it is **section 12's final replacement transaction**. 7.7 patches
   a course the user explicitly asked to keep and 12.1 permanently deletes six parked LegacyCourses
   models and retires seven recipes with no archive, so neither should start on a successor's
   initiative. Section 7.7 step 10 and section 14.9 already treat a Summit conflict as a scope
   decision, and section 0.5 forbids deploying anything without explicit authorisation.
2. **DONE 2026-09-16.** All five earlier courses' cut sets were re-audited under the fixed
   `sampleSurfaces`; every one still holds, with the before/after counts in the hazard-reach pass
   above. `qa.json` is current for all six courses.
3. Section 12.1's difficulty list is `3, 3, 2, 3, 3, 4` plus Summit's 3. `Courses.DoorDash` currently
   carries **Difficulty 3, not the 2 that list wants** — carried over from when it was added. Fix it
   in the 12.1 change, not before, so it moves with the rest of the registry.
4. **DONE 2026-09-16**, on the user's explicit instruction. Ball Barrage's two pistons and two
   hammers, and Door Dash's large hammer (the same defect, found by the new regression), now measure
   into their own lanes. Ball Barrage is `7a46da9c` and Door Dash is `aae4c298`; both are re-staged,
   re-promoted and re-audited. **Ball Barrage's Gate 3 approval predates this change** — the geometry
   a human played is not quite the geometry that ships now, so the beat 03 and beat 05 timings are
   worth one interactive pass whenever the user next plays it.
5. The Whirlpool Waltz 8.5 blocker, and the scripted-trial category generally, are intentionally NOT
   being chased (user decision, 2026-09-16). The two guards in `run-course-routes.server.luau` are
   in place and still UNEXERCISED.
6. Delete any `places/arena/server/Scripts/Temp*Probe.server.luau` before any commit; they are
   Rojo-synced scratch copies of the checked-in probes and must never be committed. This session's
   was removed.
7. `docs/splashdown/qa-report.md` is still the one section 5 artefact that does not exist. All six
   courses now have complete `qa.json` evidence to build it from.
8. The palette in section 7 (one hue family per course) is still **not applied by the builder** for
   any of the six courses: `CoursePresets` clones sources without recolouring. It is a set-wide open
   item, recorded in each course doc, and belongs with the section 12 work rather than one course.

### 1.3 Studio

Last connected arena: place ID **121997450145716**, title Match Place, studio_id f2e79758-7afe-47ea-8efc-85035edf8307 (2026-09-16). Rediscover the ID before use — it changes every session.

**Rojo, 2026-09-16:** this repo's own `arena.project.json` (project name `ouch-proto`) was already
serving on **34872** and `lobby.project.json` on 34873, so `tests.project.json`'s declared port was
taken and the plugin's auto-connect prompt offered the ARENA project, which does NOT sync
`ServerStorage.Tests`. Serve the tests project on a free port instead —
`rojo serve tests.project.json --port 34876` — then edit the port in the Rojo plugin panel (the
field is at desktop (1860, 899), Connect at (1854, 944)), click **Allow** on the
"Allow plugin Rojo to access localhost:34876?" dialog and **Accept** on the sync-patch panel. Do not
kill the 34872 server; a parallel session may be using it.

Do NOT edit lobby place 130584867985467, previously studio_id 89fa3e46-0f1a-4be4-a47a-e97b7066a656.

Recorded Edit state:

- Workspace.battle_stadium: original source gallery; preserve it.
- Workspace.LegacyCourses: **97 immediate children: seven course Models plus ninety Keyframes**. The seven Models are the user's copies of the original courses (see 1.2).
- ReplicatedStorage.Assets.Maps.Splashdown: **exactly six models, `BallBarrage`, `WhirlpoolWaltz`, `DoorDash`, `TumbleTunnels`, `TiptoeTrials` and `PistonPeak`, all real promoted templates matching `CourseOrder`.** The `WhirlPool`/`KnockKnock` local-test fixtures have been destroyed; do not recreate them unless testing an isolated config again, and destroy them again afterward. This matches `Splashdown.CourseOrder` exactly as of the Piston Peak build — the folder is no longer expected to be empty.
- ServerStorage.SplashdownStaging holds `BallBarrage`, `WhirlpoolWaltz`, `DoorDash`, `TumbleTunnels`, `TiptoeTrials` and `PistonPeak`, all staged and promoted on 2026-09-16 with hashes **Ball Barrage `7a46da9c` (143 BaseParts), Whirlpool Waltz `78e562b8` (142), Door Dash `aae4c298` (221), Tumble Tunnels `d390ff50` (163), Tiptoe Trials `0f8e9510` (160), Piston Peak `e164c528` (162)**. Ball Barrage moved `943e493c` → `ca5e95b4` (the two CoursePresets fixes in 1.4, which also dropped its part count from 158 to 143 by ending the doubled piston spring) → `7a46da9c` (the hazard-reach pass); Whirlpool Waltz moved `2fbc899c` → `78e562b8` the same way; Door Dash moved `8c00a748` → `aae4c298` (the hazard-reach pass). Re-stage before relying on any of them if the specs change again; `CourseAuthoring.promote` asserts hash equality and refuses a stale one.
- `workspace.Assets.Arena.Map.Model` is at its correct original pivot (verified, see the tooling note above); do not need to re-check this unless something else reports it looks wrong.
- The evidence sink on `http://127.0.0.1:34875/` is a scratchpad script (not checked in); rewrite it in ten lines when needed. The Command Bar's Run button measured at desktop (1884, 1033) this session and the text field at (840, 1030); clicking Run while Play is RUNNING does nothing, so stop Play first. Temporary kit probes, observer and review gallery removed. A Rojo-synced probe under `places/arena/server/Scripts/` (Temp*Probe) may be present while section 11 work is in progress; delete it before any commit.
- The source gallery is unanchored and disappears from Workspace in Play. Export its source in Edit before testing.

## 2. Startup and repeatable command recipes

Run from PowerShell at the repo root. Commands below are instructions for the successor, not claims that their future output has already occurred.

### 2.1 Read-only health checks

~~~powershell
Set-Location -LiteralPath 'C:\Users\jackc\desktop\ouch'
git status --short
git branch --show-current
git rev-parse HEAD
git log -17 --oneline
Get-Command rojo,lune,stylua,selene
Get-NetTCPConnection -LocalPort 34872 -State Listen -ErrorAction SilentlyContinue
Get-Content -Encoding UTF8 AGENTS.md
Get-Content -Encoding UTF8 docs/splashdown/02-kits.md
Get-Content -Encoding UTF8 docs/splashdown/gate-1-plan.md
Select-String -Path docs/splashdown/00-findings.md,docs/splashdown/01-asset-inventory.md -Pattern '^#' -Encoding UTF8
~~~

Expected: recorded branch/HEAD unless new commits are explained; four executables resolve; one existing Rojo listener on 34872. There is no arena base place under places/arena; that is expected and out of scope (section 12.2 withdrawn). Read 02-kits.md and gate-1-plan.md in full; read 00-findings.md and 01-asset-inventory.md by heading and pull specific rows with Select-String as needed (section 2.4), rather than loading both files whole.

~~~powershell
lune run src/scripts/lune/run-tests.luau
if ($LASTEXITCODE -ne 0) { throw 'Headless tests failed' }
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Whitespace check failed' }
~~~

Expected at recorded HEAD: final runner summary 967 tests, 0 failures. After adding tests: at least 967, zero failures. Do not use a pipeline's success to hide a failing native command.

Use Roblox Studio tool discovery, then list_roblox_studios and get_studio_state. Select ONLY the place with game.PlaceId == 121997450145716. Confirm Edit mode and source folders using execute_luau with datamodel_type="Edit":

~~~lua
assert(game.PlaceId == 121997450145716, "Wrong place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
assert(workspace:FindFirstChild("battle_stadium"), "Missing source gallery")
local origin = workspace.Assets.Arena.MapOrigin
print("MapOrigin", origin.CFrame, "Gravity", workspace.Gravity)
local legacy = workspace:FindFirstChild("LegacyCourses")
print("Legacy children", legacy and #legacy:GetChildren())
print("Templates", #game.ReplicatedStorage.Assets.Maps.Splashdown:GetChildren())
print("Tests", game.ServerStorage:FindFirstChild("Tests"))
~~~

Expected initial output: original MapOrigin approximately (-537.767, 460.777, -54.314), gravity 120, legacy 97, templates 0 (expected; see 1.2), Tests present. Read the actual MapOrigin; never write the recorded coordinates into gameplay.

tests.project.json serves port 34872, allows arena and blocks lobby. Confirm its ServerStorage.Tests includes Assets and Server tests. Do not run a second Rojo on the same port. If no listener exists, start exactly:

~~~powershell
New-Item -ItemType Directory -Path .review/splashdown-handoff -Force | Out-Null
Start-Process -FilePath rojo -ArgumentList @('serve','tests.project.json') -WorkingDirectory 'C:\Users\jackc\desktop\ouch' -WindowStyle Hidden -RedirectStandardOutput '.review/splashdown-handoff/rojo-out.log' -RedirectStandardError '.review/splashdown-handoff/rojo-error.log'
~~~

Expected: port 34872 listening, Studio Rojo plugin connected to that project, latest modules and tests visible. If the plugin cannot be connected through available UI, ask the user to connect it; do not continue against stale code.

### 2.2 Actual Studio TestEZ recipe

Tool names can change prefix. Discover exact schemas instead of inventing a tool:

~~~javascript
text(ALL_TOOLS.filter(t => /Roblox_Studio/.test(t.name)
  && /studio|luau|play|capture|console|keyboard/i.test(t.description + t.name)));
~~~

Existing operations: list_roblox_studios, get_studio_state, execute_luau, multi_edit, start_stop_play, get_console_output, screen_capture. execute_luau accepts studio_id, datamodel_type ("Edit", "Server", "Client"), code.

1. In Edit, create an ordinary temporary Script with multi_edit:
   file_path="game.ServerScriptService.SplashdownKitProbe", className="Script", edits=[{old_string:"",new_string:<complete UTF-8 contents of docs/splashdown/probes/run-kits.server.luau>}].
2. Start Play with start_stop_play({studio_id,is_start:true}).
3. Poll at bounded intervals; inspect ServerStorage.SplashdownKitTestResults.Value in the Server datamodel. It begins "running", then becomes JSON.
4. Expected JSON: ok=true, result.passed=25, result.failed=0, result.skipped=0. Read console errors too.
5. Stop Play. Delete only the temporary Script that this procedure created. Verify it is gone in Edit.

For final course QA, implement the bootstrap named in section 5 using this same ordinary-Script pattern. Do not execute docs/splashdown/probes/run-contract.server.luau as final verification: it temporarily inserts deprecated courses for discovery.

MCP interactive execute_luau cannot require arbitrary modules or use privileged remotes in its sandbox. **Do not raise capabilities, bypass the sandbox, or pretend an inline assertion is TestEZ.** Normal temporary Scripts/LocalScripts in Play supply the supported engine context. Authoring that requires modules in Edit uses Studio's normal Command Bar through UI; if UI control is unavailable, ask the user to paste the exact Command Bar call.

### 2.3 Formatting and lint after changes

~~~powershell
$changedLuau = @(git diff --name-only --diff-filter=ACMR f866f7f -- '*.luau')
$untrackedLuau = @(git ls-files --others --exclude-standard -- '*.luau')
$taskLuau = @($changedLuau + $untrackedLuau | Sort-Object -Unique)
if ($taskLuau.Count -gt 0) {
    stylua --check $taskLuau
    if ($LASTEXITCODE -ne 0) { throw 'Format the listed files, then rerun --check' }
    selene $taskLuau
    if ($LASTEXITCODE -ne 0) { throw 'Fix or explicitly report lint failures' }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Whitespace errors' }
~~~

Expected exit 0. Existing TestEZ describe/it/expect globals can need the repository's existing test lint convention; copy a neighboring test's convention, never blanket-disable a file's checks. StyLua needed multiple formatting passes on some nested tables: rerun --check until it passes.

### 2.4 Context budget: subagents, large outputs and handoff refresh

Neither Claude Code nor Codex delegates on its own; spawn subagents explicitly. Reserve the main context for the work that needs judgment — design decisions, spec authoring, builder and QA code, tuning calls, gate packets — and hand everything mechanical to a subagent with a narrow scope and an explicit return format:

- Codebase exploration: "find every file that references X; return paths and one line each." Verify the returned list before editing, then ask once more for what touches the other side of the boundary (client/server, arena/course) that the first pass missed.
- Evidence reading: parse qa.json, routes.json, contacts.json and console logs; return the numbers and the failing rows, never the text.
- Test, lint and format loops: run the section 2.3 recipe and return pass/fail plus failing lines only.
- Capture polling, hash computation, inventory and manifest transcription, document formatting.

Rules:

- Never paste whole files or full tool outputs into the main context. Anything longer than a screen goes to .review/… or docs/splashdown/evidence/… and is read by line range or Select-String.
- On startup read only what the current stage needs (section 2.1); pull other sections of the findings, inventory and this file by heading.
- Refresh section 1 of this file (HEAD, commits, evidence paths, exact next action) at every gate, after every course commit, and whenever context usage is high or the harness warns. A fresh session resumes from this file, never from memory. Commit the refresh with the work it describes.
- Subagent results are inputs to verify, not evidence: any number a subagent reports must trace to a file it wrote under evidence/.
- AGENTS.md at the repo root applies; keep its repository map and these rules consistent.

## 3. Immutable contracts and resolved decisions

### 3.1 Do not change these systems

Do not modify round flow, spawn routing, checkpoint credit, elimination, finish detection, scoring, queue capacity, existing arena name lists, existing shared MapFeatures values, movement speed/jump/gravity, economy, purchases, UI or network protocol to make a course pass.

Specifically freeze the behavior of:

- places/arena/server/Modules/Splashdown/SplashdownService.luau
- places/arena/server/Modules/Splashdown/SplashdownCourses.luau and DoorRows.luau
- places/arena/server/Modules/VenueService.luau
- src/shared/Game/Splashdown/RaceRound.luau, CourseSequence.luau, DoorPlan.luau
- src/config/Gameplay/Queues.luau, GameModes.luau
- src/config/Gameplay/MapFeatures.luau existing values and EnabledNames/prefix lists
- src/shared/Network.luau and gameplay/client initialization already integrated at Gate 2
- places/lobby/**, shop/UI/economy sources, STYLE.md and SHOP_REDESIGN_PLAN.md.

A demonstrated kit bug gets a minimal separate fix, regression test and gate note. A change to frozen lifecycle behavior requires user approval first. Read AGENTS.md; UI changes are outside this task.

Permitted config change: replace Splashdown.CourseOrder/Courses entries at the FINAL atomic swap; add the six new course definitions. Keep all other Splashdown settings, including Summit's existing Par 115/Cap 210/Close 45 and rise 20-delay/60-height/140-duration. New courses use ParSeconds=75, CapSeconds=180, CloseWindowSeconds=60. These are configuration, not measured run-time claims.

### 3.2 Race facts that determine design

- Maximum 30; minimum 2; three distinct courses per match, points by placement; no top-N qualification.
- A fall causes checkpoint respawn after .8 seconds. Use race Hazards liquid, **not Scriptables.ElimZones**, which is match elimination.
- Ordered checkpoints are mandatory before finish. A flooded pad can send a racer physically forward without granting intervening checkpoint credit. Test that condition; do not patch it away or put critical checkpoints underwater during the accepted run.
- RootOffsetStuds=3.5. Enforce all part CORNERS within 600 of MapOrigin yourself; the existing 600 rule is a spawn filter, not course-wide validation.
- Beach-ball reset radius 420 is 3D relative to MapOrigin; lower reset threshold is MapOriginY−80.
- Actual WS 26, gravity 120, UseJumpPower=false, JumpHeight 10. Unused JumpPower 50 is NOT the actual trajectory. Measured normal max gap 22; step 11.5. Use these measurements, then repeat calibration with the final actual avatar.
- Initial ordinary jump gaps: 18 studs, accepted range 13.2–19.8. Precision landing width minimum 3.06. Anti-skip wall top minimum 14 above every adjacent takeoff surface, not above an arbitrary origin.
- At least 15 studs of readable approach before every hazard. Final hardest beat is second-to-last; final sprint is short and easier.
- Route length (override 4): 800–1,000 studs of beat arclength per course. The section 7 targets sum to about 800; the pilot builds at that length and its measured pace fixes the set-wide target before the remaining courses are built. Time should come mostly from traversal plus moderate friction, not from repeated falls.

### 3.3 Asset, naming and motion contracts

Use only the existing source kit. Clone, recolor and uniformly Model:ScaleTo. Never resize one dimension of a hazard. Invisible markers/test volumes are ordinary Parts as in the existing author; they are not new visual assets. Existing arena liquid/boundary sources are allowed. Never introduce invisible walkable floors or invisible shortcut-blocking lids to fake geometry acceptance.

Copy concrete patterns from:

- src/scripts/studio/author-splashdown-kit-lab.luau: whole-root clone, uniform scaling, anchoring, SourceAsset metadata and safe temporary ownership.
- src/scripts/studio/author-splashdown-courses.luau: piece(), placePart(), marker(), forward(), startPads(), checkpoint(), finishLine(), boundary(). Read it; **do not run Author.build()**, which destroys same-ID templates and regenerates the bad layouts.
- places/arena/tests/Server/HazardKits.spec.luau: engine fixture/assertion cleanup.
- places/arena/tests/Server/RotatingComposition.spec.luau and CarryMotion.spec.luau: nested motion and support assertions.
- docs/splashdown/probes/run-kits.server.luau: real TestEZ bootstrap/result JSON.
- places/arena/client/Modules/Presentation/HazardVisuals.luau: cosmetic noncolliding ghosts, no authoritative client collision/motion.

Every generated asset gets SourceAsset=<original source ID>, CourseId, BeatId, PieceId. Actual course instance names use sd_<ID>_<NN>_<role>_<index>; never original obstacle_/ball_001 names. Names do not select kits.

Use canonical motion path ONLY: Scriptables/Rotating/<NN_BeatName__group>/Origin + Assembly; Origin.RotationSpeed=0. Rotor attributes do all motion. Origin.ServerCarries=true for RotorCarries or Seesaw rides. RotorAccel is disabled in all new specs; omit it.

ScriptableRoot is a **CollectionService tag**, not an attribute. Build all immutable assembly descendants and attributes before tagging. Tag only live roots through the existing activation path. Templates and source exports remain untagged.

Keep top-level runtime folders unchanged:

~~~text
Courses/<CourseId>                         (documentation/authoring address)
  Origin                                  BasePart; Model pivot agrees
  Geometry/<NN_BeatName>/...               visible static pieces
  Beats/<NN_BeatName>/...                  ObjectValue indexes, not duplicate geometry
  Start/Pads/01 ... 30                     immediate BaseParts
  Checkpoints/01 ... NN/Trigger, Pad       Models, sorted zero-padded
  Finish/Trigger, Deck                    exactly one finish
  Hazards/<race liquid>                   immediate BasePart(s)
  Boundary/Wall01 ... Wall24              radius 390, existing collision contract
  Scriptables/Rotating/<NN_BeatName__group>/Origin, Assembly
  Scriptables/JumpPads/<renamed model>/Outer, Inner
  Scriptables/FoamPits/<renamed volume>
  Scriptables/Doors/<renamed direct slabs>
  QA/Gates/<NN_BeatName>                   invisible noncolliding/query/touch volumes
~~~

The actual templates root remains ReplicatedStorage.Assets.Maps.Splashdown, NOT a renamed Courses folder. Numbered beat ownership is retained through Geometry, group names and ObjectValue indexes because moving Doors or other kit entries into arbitrary beat folders breaks discovery.

Call AttributeAudit.check(model, metadataAllowlist) before staging acceptance. Implement a finite allowlist: CourseId, BeatId, PieceId, GateId, SupportId, BuildVersion, SpecHash, SourceHash, QAOnly. SourceAsset and CriticalRoute are already allowed. Do not allow arbitrary unknown attributes.

## 4. Gate 2 closure and prerequisites for Gate 3

Goal: Gate 2 is approved. Secure source data and validate the tool chain before building the pilot.

1. Run section 2 health checks and isolated kit tests. Expected 967+ headless, 25 kit tests, no regressions.
2. Record the measured evidence and the still-pending course QA honestly in the Gate 3 packet. Gate 2 approval is already recorded (2026-09-15); do not wait for it again.
3. In Edit create a source-only export group under ServerStorage.SplashdownAuthoringSources:
   - Kit: clone Workspace.battle_stadium, preserving source IDs, MeshIds, collision fidelity and relative multipart geometry.
   - SummitSource: clone ONLY Workspace.LegacyCourses.SummitSplash.
   - ArenaSources: clone the liquid mesh from Workspace.Assets.Arena.Scriptables.ElimZones["base_circle_water_001.001"] and ONE boundary wall from Workspace.Assets.Arena.Map.Boundary, sorted by name before selection.
   - No other LegacyCourses child belongs in this export. Do not delete or modify the original source gallery.
4. Save native Roblox XML model exports to:
   - assets/splashdown/kit-source.rbxmx
   - assets/splashdown/summit-source.rbxmx
   - assets/splashdown/arena-sources.rbxmx
   Use Studio Save Selection to File. These are new files, not exports of retiring courses. If native UI is needed, first read the available computer-use skill in full. If export/UI is unavailable, STOP and ask the user to save those exact selections/paths. Inventory JSON is not a substitute.
5. Compute hashes: Get-FileHash -Algorithm SHA256 assets/splashdown/*.rbxmx. Record them in docs/splashdown/evidence/source-hashes.json with placeId, date, source hierarchy and counts. Reimport into a disposable container; confirm 176 source roots / 222 BaseParts and identical MeshIds, sizes, collision fidelity and child paths. Destroy only that temporary import.
6. Capture one fixed-camera view of the source kit in Edit. screen_capture accepts studio_id, capture_id, camera_position=[x,y,z], look_at_position=[x,y,z]. The user repaired the capture tooling on 2026-09-15. Wait in bounded intervals and read the returned artifact. If it stalls, cancel once and retry once from clean Edit. A second failure is a STOP for this step; do not waive screenshots.
7. Commit only source exports, hashes and the minimal authoring/QA infrastructure once implemented. No legacy course archival and no production registry swap here.

Acceptance: Gate 2 approval recorded (2026-09-15); repeat tests pass; complete source-only exports can be reimported; actual screenshot file exists and is viewable; original gallery and ninety Keyframes unchanged.

## 5. Required implementation interfaces (NEW: none of these exist yet)

Create exactly these modules. Do not look for a finished builder/QA module in the current tree.

| New path | Required API |
|---|---|
| src/shared/Game/Splashdown/AssetManifest.luau | returns versioned source hash, per-source roles, mechanical pivots, measured entry/exit/support sockets and surface patches |
| src/shared/Game/Splashdown/CoursePresets.luau | buildPiece(context,pieceSpec); named presets from section 6 |
| src/shared/Game/Splashdown/CourseBuilder.luau | build(spec,sources): Model, BuildReport; no global registration mutation |
| src/shared/Game/Splashdown/CourseAuthoring.luau | stage(ids), preview(id), clearPreview(), promote(ids), retireLegacy(); Edit-only except build itself |
| src/shared/Game/Splashdown/CourseSpecs/<ID>.luau | one declarative table per new course; SummitSplash is source-plus-patch operations |
| src/shared/Game/Splashdown/CourseQA.luau | check(model,spec,calibration): Report; sampleSurfaces(), buildGraph(), checkCutSets(), auditGaps(), auditGeometry(), auditCoverage(), auditVariety() |
| src/shared/Game/Splashdown/CourseGraph.luau | pure graph search/cut-set helpers, separately headless tested |
| src/shared/Tests/CourseGraph.spec.luau | pure graph regression and seeded bypass mutations |
| places/arena/tests/Assets/SplashdownQA.spec.luau | actual Studio tests for all selected course models |
| docs/splashdown/probes/run-course-qa.server.luau | normal Script TestEZ bootstrap; JSON result |
| docs/splashdown/probes/run-course-routes.server.luau | real Humanoid scripted trials with timestamps/hits/falls/waypoint trace |
| src/scripts/studio/author-splashdown-v2.luau | documented Command Bar entry to CourseAuthoring; never old Author.build |
| docs/splashdown/qa-report.md | per-course acceptance matrix linked to raw evidence |

Keep reusable authoring functions dependency-injected. CourseBuilder.build receives source models; it must not require Workspace.battle_stadium globally or require live MapOrigin for local construction. Pure graph tests must not depend on Studio Instances.

Spec minimum schema; expand only with explicit typed fields, not arbitrary executable callbacks:

~~~lua
return {
    Version = 1, Id = "BallBarrage", DisplayName = "Ball Barrage",
    Difficulty = 3, ParSeconds = 75, CapSeconds = 180, CloseWindowSeconds = 60,
    Layout = { Kind = "Serpentine", LanePitch = 112, RunLength = 240, BoundsRadius = 300 },
    Start = { Rows = 5, Columns = 6, Spacing = 6, Heading = -90 },
    Beats = {
        {
            Id = "01_Countercurrent", Family = "Ride", Mechanic = "Counterbelt",
            Palette = "Coral", LaneWidth = 10, Rise = 0,
            Pieces = {
                { Id = "Belt01", Preset = "Conveyor", Source = "obstacle_9_001",
                  Scale = 1, AttachTo = "Entry", Gap = 0,
                  Attributes = { Conveyor = true, ConveyorSpeed = -15.6, ConveyorAxis = "Z" } },
            },
            Gate = { At = "Exit" },
            Checkpoint = true,
        },
    },
}
~~~

This snippet is a schema example, NOT a complete passing pilot. Populate the exact beat/encounter tables in section 7. Layout.Kind is one of "Serpentine", "Spiral", "Chute", "Loop", "Archipelago", "StackedSwitchback" (section 5.2); each Kind carries the typed fields its guide needs, and the builder rejects an unknown Kind.

### 5.1 Deterministic asset adapter and builder

1. Inventory source child paths before renaming. Match every role by exact source ID/path from inventory.json. A missing role is a failure, never a recursive fuzzy-name match.
2. Put each cloned MeshPart root and descendants in a holder Model. Anchor everything. Clear imported display PivotOffsets. Uniformly ScaleTo. Move the WHOLE holder with Model:PivotTo; BasePart:PivotTo does not move child BaseParts.
3. Measure local collision geometry in Studio. Raycast down on a .5-stud X/Z grid over each candidate walkable surface; retain real hit positions/normals and holes. Add .25-stud samples within 2 studs of boundaries/holes. Store the actual surface patches. Bounding boxes alone cannot describe arcs, pizza holes, arches or ramps.
4. Manifest sockets: Entry/Exit at the center of actual traversable edge patches; Support at the actual underside mounting contact; mechanical axle in the verified root-local frame. Record forward axis explicitly. Author socket origins on a .25-stud layout grid; surface-derived contact residuals remain measured decimals.
5. Place socket-mated pieces with targetCFrame * localSocket:Inverse(). Use .05-stud overlap at ordinary solid joins; do not leave a gap then hide it under an invisible floor. Ordinary intentional jump edges are exactly 18 studs initially, measured nearest traversable edge to edge, not pivot to pivot.
6. Use source platform slabs for supports, wall pieces for enclosure, tunnels/arches at transitions. Scale supports uniformly; tile multiple supports to fill required space. Never stretch a hazard to span a lane.
7. A support clearance over .1 studs fails. Compound source-asset internal intersections are whitelisted by exact original child pair/source hash; newly created intersections are not. Socket seams permit at most .1 studs penetration, not arbitrary deep overlap.
8. Generate all markers, 30 pads and one checkpoint at each NEW beat entrance after beat 1. Put the checkpoint Pad on stable static support BEFORE the beat's gate/hazard. Set CheckpointCount exactly. Summit keeps four existing checkpoints.
9. Start grid is six columns by five rows, 6-stud centers, 30 pads; clear supported footprint at least 36 by 30. Use the rectangular source slab uniformly scaled until that grid plus 3-stud margin fits. Start/finish are the only unrestricted plazas; no mid-course breather is used in these six specs.
10. Static route envelope: within 300 horizontal radius and Y between −30 and 90; every part corner, liquid and boundary included, must remain within 600. Ball travel and reset poses stay within 380 3D radius, leaving 40-stud reset margin. Do not constrain only pivots.
11. Build into ServerStorage.SplashdownStaging/<ID> with owned marker BuildVersion=1; do not tag it. Fail if replacing an unowned/foreign staging model.
12. stage(ids) returns/prints JSON {ok,ids,partCounts,buildSeconds,attributeErrors,specHashes}. Build twice with identical sources/specs: sorted class/name/attributes/mesh/scale/local-CFrame serialization hashes must match. Exclude elapsed build time from the deterministic hash.
13. preview(id) clears only its own previous preview and puts an UNREGISTERED cloned preview at live MapOrigin for Edit screenshots. It must not destroy/park user models without the existing safe preview ownership pattern. clearPreview() restores exactly what preview moved.
14. promote(ids) is reserved for final validated replacement. Verify all candidate hashes/tests before replacing any template. Fail before mutation if one is missing.

### 5.2 Layout algorithm, not freehand placement

One layout kind per course (override 1). Each course spec declares its guide in Layout — a polyline or a parametric curve in local X/Z with a Y profile — and the builder packs beats along it in order by measured socket arclength. Turns consume guide length and belong to the adjacent beat; they are never empty breather slabs. BoundsRadius 300 is mandatory. No piece may cross another beat's reserved lane envelope or launch envelope; adjacent runs and islands are separated so that no launch envelope reaches them, and the launch-envelope QA proves it — spacing alone is not proof. Beat Y offsets are cumulative and explicit in section 7; use ramps, arched ramps and slides for every change, never floating flat slabs. Use arc/mesh sockets for turns; do not rotate an entire long beat around an unmeasured bounding-box corner. If a required turn, rise or island spacing cannot be socketed with stock assets uniformly scaled within the assigned envelope, stop and report the measured dimensions; do not stretch a piece or bridge an arbitrary seam.

Guides:

- **BallBarrage — Serpentine.** Start at local (-180, startY, 168), facing +X. Guide polyline in X/Z: (-180,168) → (60,168) → (60,56) → (-180,56) → (-180,-56) → (60,-56) → (60,-168) → (-180,-168). Adjacent parallel runs are separated 112 studs. Use quarter-arc assets for the turns where the measured socket fits.
- **WhirlpoolWaltz — Spiral.** Clockwise descending guide: angle 180 → 660 degrees, radius 190 → 65 linearly, Y 36 → 0 linearly, then a radial finish to the hub. Divide the guide arclength by the section 7.2 length targets. Platforms follow measured sockets tangent to the guide; they do not create an uninterrupted same-height floor beneath the gaps.
- **DoorDash — Chute.** One wide straight run, one hairpin, a second wide straight run, descending overall. Width is the crowd pressure, not turns: the lane tapers from the 30-pad start through the door rows. The hairpin sits at roughly 55–60% of the route (between beats 03 and 04). Both runs, corners included, stay inside the 300 radius; the runs are separated so that no launch in 04 can reach the other run.
- **TumbleTunnels — Loop.** A closed circuit around a central tunnel spine (arch_004 outbound, arch_006 return) that the route crosses twice. Start and finish sit near each other on the outside of the loop but are separated by enclosure so the finish is unreachable from the start plaza. Ball paths stay inside the 380 radius.
- **TiptoeTrials — Archipelago.** Islands placed radially around the origin; start at the perimeter and finish at the centre island (or the reverse if the measured launch envelopes fit better). Consecutive islands are linked only by the beat's launch or tile group; non-consecutive islands are separated by more than the maximum measured launch reach.
- **PistonPeak — StackedSwitchback.** Short runs stacked above each other with a small horizontal pitch (30–40 studs between run centrelines) so the course reads as a climbing tower that the rising liquid follows. Each run rises per section 7.6. Guard walls between stacked runs are measured 14 above the lower run's takeoff surfaces.
- **SummitSplash** — the exported model's original arc centers, angles, heights, start, four checkpoints and finish centerline. No new route topology.

Beat target lengths in section 7 sum to about 800 studs per course (override 4). Fit each beat between 0.85 and 1.15 times its target using support repeats, legal gaps and the listed obstacle spacings. These lengths are design inputs, NOT measured timing evidence. After the pilot's measured pace, fix the set-wide total within 800–1,000 and scale the remaining courses' targets proportionally before they are built.

## 6. Fixed hazard presets and source crosswalk

Read exact bounding sizes, pivots and child paths from docs/splashdown/01-asset-inventory.md and evidence/inventory.json. These IDs eliminate prior identification mistakes:

| Preset / source | Binding and initial attributes |
|---|---|
| Conveyor / obstacle_9_001 | Conveyor=true; visible chevron axis; counter speed −15.6 after orientation. Alternates −13 and −18.2 where listed |
| BigBall / obstacle_23_001 with sphere obstacle_23_002 | Full scale 1; BigBall only on sphere; Cap 40, Bounce 58, Float .25, RollOff 38; no Shove selector |
| Sweeper / obstacle_2_001 frame + obstacle_2_002 drum | Scale .5; parent slide X across lane amplitude 4 period 3.2; child spin long X; Shove on spinning drum |
| Piston / obstacle_22_001 + spring 002/head 003 | Scale .5; fixed base; moving spring/head; slide piston profile, period 3.2, extent 6, hold .6 |
| Mace / obstacle_5_001 through 011 | Scale .7; top-link axle, rock Z amplitude 45 period 3.2; Shove owner includes moving chain/ball |
| Large/Small Hammer / obstacle_3_001/obstacle_4_001 | Scale .6; head 002 pivot at pillar axle; rock hammer profile, amplitude 55, windup 1.8, strike .3 |
| Single mallet / obstacle_1_001 | Scale .6; use only after measured mounting/axle manifest; hammer profile, not a floating Bumper |
| Dumbbell / obstacle_6_001 | ONE MeshPart, no 002 child; scale .5; Y-spin+Shove |
| Cross / obstacle_12_001; two-arm / obstacle_27_001 | Scale .5; Y-spin+Shove; each silhouette must appear |
| Disc / obstacle_14_001+002, 15_001+002, 26_001+002 | Carry plate; Y-spin. Uniform scales .5/.45/.6 respectively, creating three distinct diameters |
| Pizza / obstacle_16_001 hub + 002 plate | Scale .4; plate Y-spin+Carries; missing wedges remain real holes |
| Carousel / obstacle_13_001+002 | Scale .4; Y-spin+Carries; canopy stays proportional |
| SwingPanel / obstacle_8_001 axle + 002 panel | Scale .5; panel rock X amplitude 28 period 2.8, Carries+Shove, axle remains fixed |
| PaddleWheel / obstacle_24_001 assembly | Scale .5; X-spin+Shove; four cyan cradles. NOT the SwingPanel |
| Seesaw / obstacle_25_001 + 002 board | Scale .6; board Seesaw=true, axis X, MaxTilt 24, response 3; stationary Origin with server carry |
| Alternate seesaw / obstacle_11_001 assembly | Same Seesaw behavior after measured axle/board roles; used in Tiptoe and Piston Peak |
| Bumper cube/triangle / obstacle_18_001/obstacle_19_001 | Scale .5; Bumper=true; forced-contact alternating chicane; precise mesh contact |
| Fan / propeller_trampoline_1_001 base + propeller_trampoline_2_001 blade | Scale .5; Fan/FanBlade. Explicit local axis/direction; initial LaunchSpeed 48, Float .2, column 18 |
| JumpPad / trampoline_1_001 through 5_001 roots | Outer/Inner roles. Initial LaunchSpeed 51, Float .2. Source 5's inner is trampoline_6_001 |
| FallingTile / color_box_001 through 008 | Scale .25; DropDelay .65, Respawn 3, CriticalRoute=true; no never-respawn critical tile |
| BeachBall / ball_001 | Scale .5; BeachBall=true; server ownership runtime; two per Tumble course |
| FoamPit / existing volume pattern | FoamPit=true in FoamPits folder; .45 speed multiplier unchanged |
| Log-roll / spiked roller or uniformly scaled podium barrel | Spin along long axis+Shove+Carries on actual ride surface; not an unanchored physics barrel |

Initial Shove settings: ordinary 48/up 20/hold .24; hammer 58; mace 54; piston 44; Bumper 54/up 22/hold .26. All course shoves use ShoveContact="mesh", ImpactVisual=true, RetriggerCooldown=.8, GuardSeconds=1.0 unless the existing bounded kit demands a longer guard. These are starting attributes, not certified edge distances.

Additional fixed rules:

- Spin hazard speed in degrees/s = ceil((33.8 * 180 / (pi * measuredContactRadius))/5)*5. Alternate signs for consecutive variants. 33.8 is 1.3*26. Compute at the runner's actual crossing radius, not decorative tip.
- Ride-only discs/pizza/carousel use alternating ±45, ±60, ±75 degrees/s; their primary hazard is lost support/gaps, not a shove. Do not add Shove merely to increase a count.
- Hammer neighbors: phases 0, .7. Mace neighbors: 0, 1.07, 2.13 if a row uses three. Piston row: 0, 1.05, 2.1 with lateral punch directions alternating.
- The last two pilot balls bob using parent pole Rotor rock amplitude 5 then 8 degrees, period 3.4 then 2.8, phases .6 then 1.3. Measure whether cap tracking remains fair.
- Conveyor/Ball/FallingTile/Seesaw must not inherit another moving controller; AttributeAudit rejects that conflict. Nested Rotor-under-Rotor is supported.
- A Shove requires a Rotor owner. Bumper and BigBall must not also carry Shove. Do not double-count selectors.
- Three Door Dash rows use PerRow 5/BreakablePerRow 2 for the whole course. Quotas cannot differ per row with the existing config. Whirlpool Waltz uses 3/1; no other course has doors.
- Door slabs source door_002..007 at initial uniform scale .2; close their over-jump space with VISIBLE stock supported tunnel/roof geometry. Door row corridor has 5 individually framed channels, no edge bypass. If stock geometry cannot close the jump envelope, increase the uniform door/frame scale together; never make a thin invisible ceiling.
- Fans point along the visible grate normal. A horizontal ball fan requires a supported tunnel that keeps balls inside its column; open-air fan results do not establish sustained ball speed.
- Cooldown is shared per kit/player and one hit per continuous visit. A dense row can suppress later hits: test every encounter separately and in route order.
- Preserve the existing float cancellation rules; do not stack fan/pad/BigBall forces.
- No new checkpoint kit, no collectibles, no Battle Stadium branding, no extra bespoke course mechanic.
- Grey fence arcs that become shorter than 14 studs after scaling are not anti-jump walls. Use tall stock wall pieces and visible tunnel roofs.
- Rings/banana/unicorn are static dressing off-route, never counted as hazards.

## 7. Exact course blueprints

Write each course document BEFORE building that course. Files are:
ball-barrage.md, whirlpool-waltz.md, door-dash.md, tumble-tunnels.md, tiptoe-trials.md, piston-peak.md, summit-splash.md under docs/splashdown/courses/.

Document: concept, headline, layout kind and guide, table below expanded with actual source IDs/scales/socket placements, palette, numerical tuning, measured lane widths, five loophole answers per encounter, top-down SVG or ASCII generated from spec, measured QA links and manual checklist. Do not mark a planned number as measured.

**Palette (override 1).** Each course has its own base hue family, used for trims, supports, hazard recolours and dressing; walkable tops keep the kit's blue. Beat-index accents may vary within the family. Base/accent: Ball Barrage coral #FF608E / yellow #FFD64A; Whirlpool Waltz cyan #27C8E8 / cream #FFF0CA; Door Dash yellow #FFD64A / orange #FF9E43; Tumble Tunnels lime #9BDD51 / purple #8E63DE; Tiptoe Trials violet #9B70E8 / coral #FF608E; Piston Peak orange #FF9E43 / cyan #27C8E8; Summit Splash keeps its existing sector colours. Flags at start, pennants at finish, inflatables at turns. No random on-route dressing.

**Counting (override 3).** Score variety on encounters. An encounter is one thing the runner solves as a unit, counted once by its primary behavior: RotorBump (each pendulum, spinner, sweeper, log-roll, piston, paddlewheel or swing panel), RotatingPlatforms ride (each disc, pizza or carousel), BigBall (each ball), Conveyor (each belt segment), Bumper (each chicane, or each isolated forced bumper), Fan (each fan), JumpPad (each pad), Door (each row), FallingTile (each tile group between two stable landings), Seesaw (each board), BeachBall (each ball), FoamPit (each forced lane or catch basin). A Rotor+Shove is RotorBump, not two kits; carry support is not an extra kit. The ≤40% cap, the ≥6 types, the ≥4 families and the ≤3 same-type run all apply to encounters. Report per-instance counts (each door slab, each tile, each bumper) and motion/controller counts separately in qa.json and the course doc; they are never scored. Every listed encounter must matter on the route; do not add harmless duplicate objects.

**Cross-course rules (override 2),** checked by auditVariety across all staged specs:

- A course's headline mechanic is not the dominant mechanic of another course's climax (second-to-last) beat, and is dominant in at most one beat outside its own course.
- Each non-glue mechanic — conveyors, fans, seesaws, falling tiles, doors, pistons, sweepers/log-rolls, beach balls, ride platforms — appears in at most three of the six new courses. Glue (pendulum/spinner RotorBumps, bumpers, jump pads, foam pits, static ramps, slides and tunnels) may appear anywhere.
- No two beats in different courses share family + mechanic + encounter recipe; the same mechanic must be posed differently (asset variant, count, speeds, phases or geometric context).

The tables below satisfy all three; keep them satisfied when tuning.

### 7.1 BallBarrage / Ball Barrage — PILOT

Layout: Serpentine. Headline: three Big Balls over liquid; Big Balls appear nowhere else. Pads: trampoline_1.

| Beat | Dominant family / mechanic | Length target; elevation change | Primary encounters |
|---|---|---|---|
| 01_Countercurrent | Ride / counterbelts | 150; +6 | 2 conveyors at −13/−18.2; 1 sliding sweeper crossing the second belt; 1 forced cube+triangle chicane at the exit |
| 02_RedRebound | Precision / Big Ball chain | 140; +6 then −6 within beat | 3 BigBalls staggered left 0 / right 4 / left 4; the last two bob |
| 03_PunchPass | Timing / piston ledge | 130; +6 | 2 opposing pistons on a ledge over liquid, phases 0/1.6 |
| 04_SkyThread | Launch / guided launch | 150; +12 then −6 | 1 fan; 2 pads at 51/54; 1 forced bumper at the landing gate |
| 05_HammerHour | Timing / asymmetric strikes | 150; +6 | 2 hammers, large then small, phases 0/.7 |
| 06_SplashSprint | Climb/Descend / short slide | 80; −12 | stock slide over liquid into the finish; 1 forced bumper at the slide exit |

Total 16 encounters: RotorBump 5 (31.3%: sweeper, 2 pistons, 2 hammers), BigBall 3, Bumper 3, Conveyor 2, JumpPad 2, Fan 1. Six types; five families. Climax 05. StartY 0.

Ball gap positions use the measured launched trajectory, not the ordinary 18-stud rule. Label launch edges separately, measure cap-to-cap landing windows and prove no next-beat overshoot. All missed landings hit race liquid. No support slab below the balls. Mount poles on a submerged support made from existing slabs; supports cannot create a recovery walkway.

### 7.2 WhirlpoolWaltz / Whirlpool Waltz

Layout: Spiral. Headline: descending ride platforms with real gaps; no rising liquid. Pads: trampoline_3 (striped). Doors 3/1 — the one door beat allowed outside Door Dash.

| Beat | Dominant family / mechanic | Length target; Y guide | Primary encounters |
|---|---|---|---|
| 01_ArchDrop | Climb/Descend / arched descent | 120; 36→30 | 1 two-arm cross sweeping the enclosed landing mouth; 1 forced cube+triangle chicane; 1 foam side basin catching sideways knocks |
| 02_WedgeWake | Ride / missing-wedge platforms | 180; 30→24 | 2 pizzas, opposite rotation, distinct entry phases; 1 carousel |
| 03_DoorDock | Crowd / door choke | 90; 24→20 | 1 row of 3 doors, quota 1 |
| 04_SpinSpan | Timing / dumbbell bridges | 150; 20→14 | 2 dumbbells, opposite spin; 1 SwingPanel after a height-changing transition |
| 05_DiscDive | Precision / disc landing chain | 180; 14→4 | 3 discs, three diameters, alternating with 2 pads; 1 forced triangular bumper at the approach |
| 06_HubHurry | Timing / one readable sweep | 80; 4→0 | 1 cross spinner at the hub approach, easiest window; finish on the hub |

Total 17 encounters: RotatingPlatforms 6 (35.3%), RotorBump 5 (two-arm, 2 dumbbells, swing panel, cross), Bumper 2, JumpPad 2, Door 1, FoamPit 1. Six types; five families. Climax 05. Dome/roof clearance must preserve the view of the next landing.

### 7.3 DoorDash / Door Dash

Layout: Chute. Headline: three Door Dash rows, not fifteen identical straight-line gates. Pads: trampoline_4. Doors 5/2.

| Beat | Dominant family / mechanic | Length target; elevation change | Primary encounters |
|---|---|---|---|
| 01_DoorDrama | Crowd / door choice | 180; 0 | 3 rows of 5 doors, quota 2 per row; row yaw 0/+15/−15 relative to route, spacing 26/34 |
| 02_SlideSwipe | Climb/Descend / slide exit | 100; −12 | 1 cross spinner at the slide bottom; 1 forced bumper |
| 03_BeltBrawl | Ride / counterbelts | 150; +6 | 3 conveyors −13/−15.6/−18.2 on the flat; 1 PaddleWheel crossing the middle belt |
| 04_PadParade | Launch / successive short launches | 130; +12 | 3 pads 48/50/52 over a foam catch basin (missed landing = foam slog, ≥5 s); 1 forced landing bumper |
| 05_MaceMarch | Timing / pendulum gauntlet | 160; −6 then +6 | 2 maces phases 0/1.07 over a narrowing lane; 1 forced triangular bumper mid-lane; 1 large hammer at the exit |
| 06_CrossFinish | Timing / one readable sweep | 80; −6 | 1 two-arm cross, easiest timing window, finish |

Total 19 encounters: RotorBump 6 (31.6%: cross, paddlewheel, 2 maces, large hammer, two-arm), Door 3, Conveyor 3, JumpPad 3, Bumper 3, FoamPit 1. Six types; five families. StartY 18. Climax 05. The hairpin sits between 03 and 04.

### 7.4 TumbleTunnels / Tumble Tunnels

Layout: Loop. Headline: two physical beach balls pushed toward racers inside constrained tunnels. Use tunnels arch_004/005/006, not door_001 misidentified as a breakable slab.

| Beat | Dominant family / mechanic | Length target; elevation change | Primary encounters |
|---|---|---|---|
| 01_BallBore | Crowd / ball tunnel | 150; +6 | 2 beach balls; 1 horizontal opposing fan in arch_004 |
| 02_TiltMouth | Ride / seesaw exits | 120; −6 | 2 seesaws (obstacle_25), max tilt 18/24 |
| 03_ArchAscent | Climb/Descend / arched stairs | 110; +12 | static ribbed arch-ramp over liquid; 1 single mallet at the crest |
| 04_BumperBend | Precision / forced chicane | 110; −6 | 1 cube+triangle chicane at the bend; 1 foam penalty lane |
| 05_AirArch | Launch / fan gate | 90; +12 | 1 upward fan through arch_005; 1 dumbbell spinner guarding the landing |
| 06_TunnelTug | Timing / return tunnel | 140; +6 | 1 PaddleWheel and 1 SwingPanel inside arch_006 (the spine's second crossing); 1 foam penalty lane |
| 07_ExitSlide | Climb/Descend / short descent | 80; −12 | stock slide to the arch finish; no hazard |

Total 13 encounters: RotorBump 4 (30.8%: mallet, dumbbell, paddlewheel, swing panel), BeachBall 2, Fan 2, Seesaw 2, FoamPit 2, Bumper 1. Six types; six families. StartY 0. Climax 06. No fan in 06; do not spawn cosmetic extra balls to claim contact there.

Each foam detour has initial centerline 112 studs and rejoins BEFORE the same beat's cut gate. It is part of the same route family, not a skip. Measure additional time versus the direct path (≥5 s extra); length is not acceptance. Keep all ball paths within 380 radius.

### 7.5 TiptoeTrials / Tiptoe Trials

Layout: Archipelago. Headline: falling-tile islands, never a permanently destroyed checkpoint route. Pads: trampoline_5 with correct inner child trampoline_6. All tiles RespawnSeconds 3 and CriticalRoute=true, including the final groups.

| Beat | Dominant family / mechanic | Length target; elevation change | Primary encounters |
|---|---|---|---|
| 01_FloatFlight | Launch / float-assisted landing | 110; +12 | 1 fan onto the first island; 1 forced bumper at the landing |
| 02_BalanceBay | Ride / load balance | 120; −6 | 2 seesaws: obstacle_25 and opposing-board obstacle_11, both max tilt 22 |
| 03_IslandHop | Precision / tile stepping stones | 100; +6 | 2 tile groups of 3 across a gap chain; 1 two-arm cross between them |
| 04_StepSpire | Climb/Descend / stepped ascent | 120; +12 | 1 mace over stock steps/arched ramp |
| 05_FadeFooting | Precision / tile islands | 230; −6 then +6 | 3 tile groups of 3 (delays .75/.65/.55), each at a different height/offset with a stable landing between, separated by 2 hammers (large, small) and 1 SwingPanel |
| 06_LastDash | Launch / pad finish | 120; −6 | 2 pads at 51/54 onto a wide finish island; no hazard |

Total 16 encounters: RotorBump 5 (31.3%: two-arm, mace, 2 hammers, swing panel), FallingTile 5, Seesaw 2, JumpPad 2, Fan 1, Bumper 1. Six types; four families. StartY 0. Climax 05.

### 7.6 PistonPeak / Piston Peak

Layout: StackedSwitchback. Headline: zigzag climb with punches; **only this new course** has rising liquid. Pads: trampoline_2. Log-rolls: uniformly scaled barrel/drum stock or the spiked roller.

| Beat | Dominant family / mechanic | Length target; elevation change | Primary encounters |
|---|---|---|---|
| 01_ZigzagZip | Climb/Descend / slope counterbelts | 140; +12 | 3 slope conveyors −13/−15.6/−18.2; 1 forced cube+triangle chicane at the first switchback |
| 02_LogClimb | Timing / rolling ramps | 130; +12 | 2 log-rolls with opposite spin and different diameters on consecutive switchback ramps |
| 03_TeeterTurn | Ride / seesaw turn | 90; +6 | 1 long obstacle_11 seesaw as the turn platform, max tilt 20 |
| 04_PinballPass | Precision / forced chicane on a slope | 110; +6 | 3 alternating bumpers varying shape/height on the slope (one chicane); 1 foam gutter catching missed chicanes |
| 05_Updraft | Launch / stacked pad ascent | 110; +12 | 2 pads 48/52 up the stack; 1 forced bumper at the upper landing |
| 06_PunchPeak | Timing / piston cascade | 160; +12 | 3 pistons phases 0/1.05/2.1 with alternating lateral punch directions across the highest ledge over the rising liquid |
| 07_PeakSprint | Climb/Descend / short final ramp | 60; +6 | arch finish; no extra timing trap |

Total 15 encounters: RotorBump 5 (33.3%: 2 log-rolls, 3 pistons), Conveyor 3, Bumper 3, JumpPad 2, Seesaw 1, FoamPit 1. Six types; five families. StartY 0, finishY 66. Climax 06.

Initial liquid baseY −30, StartDelaySeconds 20, RiseStudsPerSecond=.4, MaxHeight 60, no pauses. Treat this as a tuning seed. At cap 180 liquid stops at +30 world-local Y. Every checkpoint required by a racer must remain earnable after a respawn; if flooding strands credit, lower MaxHeight in 2-stud increments until the flood regression passes. Do not modify the mode fallback.

### 7.7 SummitSplash / Summit Splash hardening

Keep original centerline, eight arc sectors, start, four checkpoints, finish and 20-second delay/+60 over 140-second liquid schedule. Preserve source export for comparison; it is not a deprecated course.

Execute this patch order:

1. Generate seven named beat indexes over the existing route: OpeningClimb, SweepTiming, BumperChicane, BalanceRise, AirGate, FinalFooting, SummitSprint. FinalFooting is the second-to-last, inward bridge section; SummitSprint is the last short approach to the existing arch.
2. Measure every old hazard's width, speed and shove travel. Remove old hazard instances that are redundant, floating or purely avoidable; preserve the course, not every ineffective prop.
3. Retain/relocate within their original route sections exactly 5 RotorBump encounters and 5 forced-contact Bumpers. No run of identical hazards exceeds 3. Alternate existing mace/windmill shapes and phases; do not relocate the arc path.
4. Introduce two previously unused asset families into thin areas: 2 seesaw boards across constrained portions of the arc corridor, and 1 sliding sweeper across the final inward bridge. Falling tiles are Tiptoe's headline and may not be added here (override 2). Add 1 existing-kit fan, 1 existing-kit jump pad and 1 foam penalty lane (an outer-ledge catch that rejoins before the same section's gate). Fans, pads and foam were already used by the old course set; they do not introduce further previously unused families.
5. Target primary encounters: RotorBump 6 (the 5 retained plus the sweeper), Bumper 5, Seesaw 2, Fan 1, JumpPad 1, FoamPit 1 = 16, six types, maximum 37.5%. Count actual meaningful encounters, never dormant markers.
6. Replace only the final inward road bridge's support pieces on the same centerline, narrowing it so the sweeper's measured shove reaches liquid on both sides; keep the original arc-sector support geometry.
7. The arc sections' outer/inner unused ledges must be enclosed. Guard walls are measured 14 studs above reachable support; do not leave an inside shortcut or an outer rail-top highway.
8. Retune only course attributes. Each remaining shove must reach liquid or a measured ≥5-second detour. Add no shared tuning changes.
9. Audit start capacity, all checkpoints, all launch paths and rising-liquid fallback with the full QA suite. Preserve original liquid timing even if the run-time target is difficult.
10. If the additions cannot fit without changing arc centerlines, original checkpoint order, or liquid schedule, STOP with failing measurements and a requested scope decision. Do not silently exempt Summit from variety, pace or enclosure checks.

Summit additions are part of the proposed hardening implementation, not completed work. Include this exact scope in the Gate 3 review packet before receiving approval to execute it.

## 8. Automated QA: required algorithms and acceptance

Do not implement a validator that just trusts spec annotations. Use independent sampled geometry and runtime observations; add deliberately faulty fixtures that each check rejects.

Every report includes courseId, gitCommit, specHash, sourceHash, placeId, calibration, test time, sample resolution, errors, warnings, counts and raw evidence paths. Status is PASS/FAIL/BLOCKED/NOT RUN, never implied pass from absence of data.

### 8.1 Bounds, spawns, attributes and lifecycle

- Enumerate all 8 transformed corners of every BasePart: distance to Origin ≤600. Geometry center horizontal radius ≤380 as the existing asset contract requires; new route design uses ≤300.
- Exactly 30 immediate Start/Pads; each plus RootOffset 3.5 produces non-overlapping character placement, solid support, no hazard overlap, adequate headroom and current spawn validity.
- At least 1 ordered checkpoint; exact CheckpointCount; stable safe pads and full-width triggers. Exactly 1 Finish.Trigger and 1 Finish.Deck.
- Boundary has 24 anchored colliding invisible wall parts, center radius 390±1, copied from the existing boundary contract.
- AttributeAudit returns zero errors. DoorRows.resolve passes; DoorRow/Index unique contiguous integers, exact row size. No forbidden name-selector match; no unanchored template asset; live BeachBall is the intentional runtime exception.
- Two independently cloned courses can coexist for testing without cross-owned balls/effects; destroy/reclone leaves no connections, constraints, detached balls or ghosts.
- Actual mode: ordered checkpoint credit, checkpoint respawn, finish-after-all, cleanup and three-course sequence still work. Flooded-respawn regression must leave a physically reachable legal path to every remaining checkpoint.

### 8.2 Walkable graph and cut sets

Implement CourseQA.sampleSurfaces using real Workspace raycasts on a disposable clone:

1. Raycast downward in 1-stud X/Z increments, retaining all accessible collision layers, not just the highest roof. Repeat with .25 spacing around gates, ledges, holes and any suspected bypass. Iteratively continue rays below each hit to collect stacked surfaces.
2. Keep standable normals consistent with the actual Humanoid slope limit; measure headroom and character width by capsule/block casts. Exclude liquid, decorative noncolliding meshes and vertical faces. Include reachable roofs/rail tops: they can be shortcuts.
3. Node = actual support surface cell plus beat ownership, height, time/state. Never connect through a visible mesh hole because its bounding box is solid.
4. Walking edges need swept body clearance and climbable measured slope/step. Jump edges need measured 22-gap/11.5-step envelope AND a collision-free sampled ballistic body trajectory, not just Euclidean distance.
5. Ordinary jumps use actual JumpHeight-mode velocity. Launch edges use individually measured fan/pad/ball trajectories and maximum reachable envelope. Include elevated cross-beat landings — and, for the Chute, Loop, Archipelago and StackedSwitchback layouts, landings on any other run, island or stacked run.
6. Dynamic states: sample every .1 seconds through one common cycle for periodic mechanisms, capped at 120 seconds; also evaluate exact extrema/hold boundaries. Falling-tile states include intact, armed, missing and restored; doors include every legal breakable quota pattern. If the exact joint state count exceeds the cap, use a conservative union graph for bypass detection and a time-expanded intended-route proof separately. A conservative false positive must be resolved by a reproducible trajectory test, not ignored.
7. Assert an intended feasible path from EACH of 30 spawn cells through all ordered checkpoints to Finish.
8. For every beat gate volume, remove all nodes/edges whose traversed capsule intersects that gate. No spawn-to-finish path may remain. Check time-expanded gate ordering too; conservative graph cut is not enough to prove dynamic traversal.
9. One safe waiting pocket before a periodic hazard is allowed only if waiting delays finish. A permanent bypass lane is not.
10. Mutation tests must detect: an added perimeter walkway, reachable roof/rail shortcut, a missing gate wall, excessive pad launch and a removed intended landing. A graph that cannot reject these fixtures is not acceptance.

Graph sampling is a finite-resolution test, not an analytic proof. Record resolution and corroborate narrow/phase-dependent cases with actual traversal. Do not advertise exhaustive proof.

### 8.3 Gap and geometry audit

- List every intended transition with source/target, measured nearest walkable edges, vertical difference, normal-gap fraction and launch classification.
- Supported flush joins are NOT jump gaps and are excluded from the 0.6–0.9 jump test.
- Normal jump gaps must be 13.2–19.8 for the 22-stud calibration. Any unintended reachable-looking gap 19.8–26.4 fails.
- Launches and moving-platform transfers use separate measured reach-window acceptance; do not falsely force them through the ordinary gap formula.
- Raycast from underside support contacts; unsupported gap >.1 fails unless the piece has an explicit, physically present pole/frame chain down to support. Suspended mace links are supported by their chain and axle, not required to touch a floor.
- Permit source-internal compound intersections by exact source child pairs only. New deep penetrations >.1 outside declared socket seams fail. Inspect collision surfaces and visible seams; oriented bounding overlap alone is not a mesh intersection test.
- Check at motion extrema too: hammer pillar, piston spring overlap, seesaw frame, carousel canopy and chain links.
- No z-fighting. Checkered strip is noncolliding and offset .05 above support. No half-stud seams, floaters or distorted hazards.

### 8.4 Coverage, density, difficulty and variety

- Sample lane cross-sections every 1 stud and time every .05 s for contact hazards. Across a cycle, every walkable lateral escape strip must be hazard-covered, blocked by visible enclosure, or a gap/liquid. Motion intermittency is timing; a permanent safe edge is a failure.
- Measure blocked fraction ≥.4 for each pendulum/hammer crossing. Use actual collision plus character width, not angular amplitude alone.
- Record rotor radius/speed/tip velocity at crossing: ≥33.8 for damaging sweepers/spinners. Ride-only platforms have separate transfer-window checks.
- Measure shove travel with five actual-player contacts per hazard/direction, holding neutral input, then five attempts with escape input. Use the minimum outward neutral displacement before recovery as the edge-reach bound. Half lane width at contact must not exceed it. Also demonstrate actual falls/delay; speed*hold is not proof.
- Bumper chicane: a walking runner cannot avoid all contacts without slowing or making the required precision maneuver. Run centerline, left/right edge and optimal slalom probes.
- Scan traversable route regions for hazard/gap/elevation-free 24-by-24 squares at 1-stud grid resolution. Start and finish are exempt. These specs have no mid-course breather.
- Variety is scored on encounters as defined in section 7: no same-type run >3, and every consecutive same-type encounter differs in phase/direction/speed/height/spacing; at least six primary hazard types; no type >40%; at least four families; distinct dominant mechanics; hardest beat second-to-last. Per-instance counts are reported alongside, never scored.
- Cross-course checks (override 2), run by auditVariety over every staged spec: headline exclusivity, the three-course cap per non-glue mechanic, and no shared beat recipe across the set. A violation in any course fails the set, not just that course.
- At least three real elevation changes; width narrows at hazards from a 30-person start. Every fall hits race liquid or a measured ≥5-second penalty detour.
- All hazards visible ≥15 studs away and next beat visible from current exit. Use line-of-sight ray checks plus screenshots; do not equate a successful ray with visual readability.
- Set coverage must include both cross/bar silhouettes, three disc sizes, pizza, carousel, BigBalls, roller, mace, large/small/single mallet, piston, both seesaw board forms, SwingPanel 8, PaddleWheel 24, fan, five usable pad variants, both bumpers, conveyors, tiles and beach balls.
- Report total BaseParts, each controller/kit instance count, source assets used, build and clone time. No part-budget target and no optimization that weakens geometry.

### 8.5 Scripted AND interactive playtests

Create run-course-routes.server.luau with these policies:

- Use the actual R15 rig/movement configuration. Require real Player trials for kits that select Players; NPC-only traversals cannot prove those contacts.
- Use Humanoid:Move/MoveTo and Jump; never CFrame/teleport along a measured route. Initial seating and the actual mode's checkpoint respawn are the only allowed relocations. Log every relocation reason.
- Route nodes are derived from sockets; player/controller must physically traverse. Detect stuck state after 8 seconds without progress; record FAIL, not a forced move.
- Expert policy: full WS 26, .05-second decision interval, uses measured hazard phase windows, jumps at recorded takeoff markers, no discretionary waits. Run 3 independent course resets; require at least one clean, zero-fall clear.
- Mid-policy: full WS 26, .25-second decision interval, observes only the next hazard/landing, .2-second response delay to a newly safe window, no advance knowledge of secret breakable doors. Try door indices in center-out order 3,2,4,1,5 for five; 2,1,3 for three. Run 5 independent resets with recorded seeds 101–105. No artificial sleep added to pad elapsed time.
- Door test seeds use existing DoorPlan.choose with seeded Random only in the test harness; production stays unchanged.
- Timer starts when race movement is released, ends when the real finish is credited. Include waiting, falls and checkpoint recovery; exclude intro/countdown/results.
- Record per-run total, beat splits, root trajectory, all splashes/fall coordinates, hazard contacts by PieceId, launch extrema, support loss, last earned checkpoint and DNF.
- Pass timing: median mid-policy completed time 60–90 seconds; clean expert time ≤.6*that median. Report all runs and completion rate, not just the best.
- A scripted policy is a reproducible proxy, not proof of human skill classification. Play each course interactively in Studio at least once using keyboard controls, record the complete unteleported run and fairness/readability notes. Record operator and input method.
- If proxy results and interactive experience disagree, obtain a user mid-skill calibration run before approval; do not rename the proxy to claim human performance.
- A hazard that never contacts any normal runner is flagged. Force a deliberate mistimed real-player challenge at that encounter and verify elimination/delay; if even that cannot connect, FAIL.
- Thirty-rider start/support/load tests: use 30 rigs for geometry/moment stress, clearly labeled simulated. A dummy rig load test is not a networked player test and must not be labeled as one.
- Multiplayer (user decision 2026-09-15): run a Studio local multi-client session (Test → Players, 2–4 clients) to check ownership, client/server carry, cooldown isolation, simultaneous tiles, ball replication and cleanup. Label the results as exactly that. No real 30-player network session is required, and none is claimed. If the local multi-client session cannot be started, STOP and ask.

Interactive checklist per course must state expected fall points, visible timing cues, where waiting is safe but costs time, respawn location, launch landing boundaries and any unfair/floating/readability issue. Leave unchecked items NOT RUN.

### 8.6 Fixed cameras and raw outputs

Per course, capture these Edit preview views relative to actual MapOrigin:
top-down position (0,520,1), lookAt (0,20,0);
three-quarter position (300,260,300), lookAt (0,20,0).
Use a documented fixed 70-degree FOV; if the tool cannot set FOV, set CurrentCamera through a supported Edit operation and record actual FOV. Record camera CFrames in evidence/course-cameras.json.

Paths:

~~~text
docs/splashdown/evidence/courses/<ID>/qa.json
docs/splashdown/evidence/courses/<ID>/routes.json
docs/splashdown/evidence/courses/<ID>/contacts.json
docs/splashdown/evidence/courses/<ID>/top-down.png
docs/splashdown/evidence/courses/<ID>/three-quarter.png
docs/splashdown/evidence/courses/<ID>/interactive.md
~~~

Use the actual returned image format/extension if JPEG instead of PNG; do not merely rename bytes. Open the image and inspect it. Compare explicitly against bad-map-refs/1.png, 9.png, 10.png, 11.png: no flat sprinkled field, repeated narrow swing-panel bypass, empty slabs, lone open spinner, avoidable/floating bumpers. Reference 2 is the Summit readability bar. If bad-map-refs is absent, stop and request those references; do not claim comparison from memory.

## 9. Mechanical tuning order

Initial values above are fixed seeds. Only the following measured iteration is authorized:

1. Fix invalid attributes, unsupported pieces, seams and unreachable intended sockets first. Do not tune difficulty around a geometry bug.
2. Close unintended graph edges using visible stock walls/arches, minimum 14 above adjacent support; test rail tops too.
3. If shove cannot reach an edge, reduce usable lane width by .5-stud steps down to 4.5, moving visible enclosure symmetrically. Do not raise Shove past existing bounds. If still ineffective, reposition the same encounter over liquid on its assigned route centerline. If it still fails, stop.
4. Increase spin to the formula's next 5-degree step; never reduce below 33.8 tip speed. For pendulum blocked fraction, first narrow lane in .5 steps to 4.5; then increase amplitude in 5-degree steps up to 65. If .4 coverage is still impossible with a clear timed opening, stop.
5. Reduce launch speed by 2-stud/s steps until no later-beat landing is reachable; keep intended landing reachable in five trials. Minimum LaunchSpeed 36. If both constraints cannot coexist, move the intended landing in 1-stud steps within the assigned beat and rerun all gap/support checks. Stop if its beat envelope must be exceeded.
6. Ordinary gaps remain 18 initially; reduce by .5 steps only down to 13.5 to fix measured reliability, increase only up to 19.5. Never create a 19.8–26.4 accidental gap.
7. Counterbelts stay between 13 and 18.2. Increase magnitude by 1 up to 18.2 only if measurable response requires it. Side-belt drift must be independently tested.
8. To meet pace without fake waits: adjust support-route arclength in 8-stud units using real same-beat ramp/turn geometry with hazards still meeting density; total per-beat change stays within ±15% of target, and the course total stays within 800–1,000. Do not add identical hazards or empty runways to pad time.
9. If expert/mid ratio still fails, change the climax's legal phase spacing by .1-second steps, preserving periodicity and coverage. Re-run both policies after every change. Do not slow the runner's WalkSpeed or add arbitrary idle delays.
10. At most three full tuning passes per course before escalating the failing measurements. Do not endlessly relax constraints.
11. Every changed seed is written back into the declarative spec and course doc. Manual Studio nudges that are absent from the spec are prohibited. Rebuild from scratch and rerun QA after tuning. Any change that would break a section 7 cross-course rule is escalated, not made.

## 10. Gate 3 — pilot delivery and STOP

Goal: prove the pipeline and quality bar on Ball Barrage only.

Gate 2 is approved (2026-09-15). Ordered execution:

1. Complete section 4 source/capture prerequisites.
2. Implement section 5 interfaces, BallBarrage spec and required tests. Write docs/splashdown/courses/ball-barrage.md first, from the section 7.1 table.
3. In Studio's normal Edit Command Bar run:
   require(game.ReplicatedStorage.Shared.Game.Splashdown.CourseAuthoring).stage({"BallBarrage"})
   Expected JSON: ok=true, ids=["BallBarrage"], attributeErrors=[], finite part/build counts.
4. Run stage a second time; expect identical deterministic hash. Original LegacyCourses and production CourseOrder are unchanged.
5. Preview:
   require(game.ReplicatedStorage.Shared.Game.Splashdown.CourseAuthoring).preview("BallBarrage")
   Expected one owned preview at MapOrigin; no source mutation. Capture/inspect both cameras, then clearPreview().
6. Install run-course-qa.server.luau as a normal temporary Script, with selectedIds={"BallBarrage"} and source=ServerStorage.SplashdownStaging. Run Play. Bootstrap clones the staged model into an isolated test Workspace container, invokes actual TestEZ and writes ServerStorage.SplashdownCourseQAResults JSON.
   Expected ok=true, failed=0, skipped=0, selected course list exactly BallBarrage and all section 8 checks represented.
7. Until final registry replacement, test the pilot using an isolated local test config with only BallBarrage plus the retained Summit source as needed for lifecycle fixtures. Do not change checked-in production CourseOrder to a one-course registry: the real mode draws three distinct courses. Any isolated config override stays in the temporary test datamodel and is removed on Stop. Copies of the parked LegacyCourses models may serve as lifecycle fixtures.
8. Run scripted routes, real-player deliberate contact challenges and one keyboard-controlled full pilot run. Measure, do not estimate. Save raw JSON plus observer notes. Report the measured pace against the 800-stud length so the set-wide length target can be fixed (section 5.2).
9. Run section 2 headless/format/lint checks. Update qa-report.md with only BallBarrage certified; other courses explicitly NOT BUILT/NOT RUN.
10. Local commits: builder/QA infrastructure separately, then feat(splashdown): build Ball Barrage pilot. Stage exact task paths; never git add -A across unknown changes.
11. Deliver pilot doc, screenshots, exact measured results, failures/limits, part count and commit IDs. Include the planned Summit hardening scope from 7.7 for visibility.
12. **STOP. Wait for explicit Gate 3 approval.** Rejected pilot feedback is applied to the pilot/spec/tests before advancing.

Gate 3 PASS requires all pilot requirements, actual evidence files, clean rebuild parity, actual tests and interactive run. A screenshot request that stalled, proxy-only timing, fake Player or skipped graph test makes the gate BLOCKED/FAIL.

## 11. After Gate 3 approval — remaining five and Summit

Build in this exact order: WhirlpoolWaltz, DoorDash, TumbleTunnels, TiptoeTrials, PistonPeak, SummitSplash hardening.

Before the first of them, fix the set-wide route-length target from the pilot's measured pace (section 5.2) and scale the section 7 length targets; record the scaled targets in 03-overrides.md.

For EACH:

1. Write its course doc from section 7, including planned per-encounter loophole table:
   walk-around; edge-hug; bypass-jump; launched-past; safe-wait.
   First four must be NO. A timed jump THROUGH the intended gate is legal; jumping past the beat is not. Safe-wait YES must have measured time cost.
2. Add only that course's declarative spec (Summit uses source-plus-patch).
3. stage({ID}); rebuild twice/hash compare; run AttributeAudit; no registration swap.
4. Run full section 8 QA on that course, the cross-course checks over all staged specs, and regression kit tests.
5. Capture both fixed views and inspect against the bad references.
6. Run 3 expert/5 mid-proxy trials, deliberate missed-timing contacts, one interactive run and checkpoint recovery checks.
7. Tune strictly in section 9 order, at most three full passes; update doc/spec together.
8. Rebuild fresh; repeat QA after the final change. Record exact final source/spec hashes.
9. Commit one course at a time:
   feat(splashdown): build Whirlpool Waltz
   feat(splashdown): build Door Dash
   feat(splashdown): build Tumble Tunnels
   feat(splashdown): build Tiptoe Trials
   feat(splashdown): build Piston Peak
   fix(splashdown): harden Summit Splash
10. Do not start the next course while the current course has an unreported failure. A genuine scope/tool blocker requires stopping and asking the user, not creating six half-tested courses.

Expected after this stage: seven staged final models; seven course docs; 14 actual camera images; complete automated/playtest records. Production old registry still unchanged until the replacement transaction below.

## 12. Final replacement and full verification

### 12.1 Transaction and retirement

Precondition: all seven staged models pass and hashes match their tested specs. Stop Play; clear owned previews/probes. Capture a read-only hierarchy/count report before mutation. Do not archive deprecated models.

1. Update ONLY CourseOrder/Courses in src/config/Gameplay/Splashdown.luau:
   ordered IDs BallBarrage, WhirlpoolWaltz, DoorDash, TumbleTunnels, TiptoeTrials, PistonPeak, SummitSplash.
   DisplayName uses uppercase versions of the names above. Difficulties 3,3,2,3,3,4, existing Summit 3.
   New timing 75/180/60. Doors: WhirlpoolWaltz 3/1, DoorDash 5/2. No Doors field on the other four. Preserve Summit's exact existing timing/rise fields.
2. CourseAuthoring.promote(all seven IDs) validates every candidate before touching templates, installs the seven exact models under ReplicatedStorage.Assets.Maps.Splashdown, and asserts exact set equality with final CourseOrder. No old IDs remain registered.
3. CourseAuthoring.retireLegacy() first resolves exact MODEL paths:
   Workspace.LegacyCourses.WhirlPool
   Workspace.LegacyCourses.DiscJockey
   Workspace.LegacyCourses.KnockKnock
   Workspace.LegacyCourses.BumperBay
   Workspace.LegacyCourses.TiltTrip
   Workspace.LegacyCourses.Downpour
   Destroy these six models only. CrossCurrent has no parked model; retire its code/config only. Retain Summit source and the 90 Keyframes. NEVER Destroy Workspace.LegacyCourses itself.
4. Remove all seven old imperative recipes from src/scripts/studio/author-splashdown-courses.luau by replacing its public entry with an explicit error directing authors to author-splashdown-v2. The new builder owns any copied helper implementations. Do not leave an executable path that recreates retired courses.
5. Remove old templates/owned previews for those exact IDs if they exist, including any legacy copies placed in the templates folder as fixtures; verify class/path before destruction. Preserve historical screenshots/JSON as evidence.
6. Report exactly which six models and seven recipes/registrations were removed. State that no Deprecated archive was created; recovery would require prior external place history/source control, not an in-project archive.
7. Commit the replacement integration separately from course construction.

### 12.2 Authored arena base — withdrawn

Withdrawn 2026-09-15 by user decision. places/arena/*.rbxl exists only for the CD workflow, which is out of scope for this task. Do not perform the Save-As export, the LFS move, or any build of the arena place. Do not create places/arena/arena.rbxl. The connected arena place is the verification target (12.3).

### 12.3 Full test commands

~~~powershell
lune run src/scripts/lune/run-tests.luau
if ($LASTEXITCODE -ne 0) { throw 'Headless failure' }
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Whitespace failure' }
~~~

Expected: 967+ headless/0 failures; no whitespace errors. Do NOT run build-place, release-places, test-and-deploy, publishing APIs or shell deployment scripts; the CD build is out of scope.

In the connected arena place, after the 12.1 transaction and with every temporary probe, fixture, preview and detached ball removed, run the actual final TestEZ bootstrap containing:

- Existing Server kit specs (25 expected unless deliberately extended).
- Existing Assets/SplashdownCourses.spec (now 14 contract assertions for seven courses).
- New Assets/SplashdownQA.spec (zero failures/skips, all seven IDs).
- Lifecycle/reset/clone tests and the explicit malformed-course mutation fixtures.

Do not change the old asset test to forgive missing templates. Its description says "five" but it iterates CourseOrder; that stale comment is not a reason to change runtime.

Run the real three-course match flow through existing admin seams, not new flow code:
places/arena/server/Cmdr/Commands/sb-match-restartServer.luau calls MatchService.restartForAdmin("Splashdown").
SplashdownService exposes stateForAdmin(), advanceForAdmin(), setNextCourseForAdmin(courseId). Use setNextCourseForAdmin to select upcoming test courses; never advance a racing phase to falsify a completed run. Read return values and assert success. After retirement all seven templates must boot without CrossCurrent/missing-template errors.

Final report must include:

- All seven courses' checks, counts, two camera views, timings, falls, hit coverage and manual checklist.
- Set-wide source/hazard coverage, at least six types/course, no type >40% (on encounters), and the cross-course rules from section 7 passing over the whole set.
- Studio local multi-client and 30-rig stress evidence with limitations clearly separated.
- Summit before/after comparison, original route/twist parity, final loophole results.
- Default arena regression: existing name-driven hazards, client carry path and shared values unchanged.
- Rebuild from source exports/specs produces matching hashes; no untracked Studio-only nudges.
- Source and spec hashes, branch/commits and test summaries.
- docs/splashdown/changelog.md updated throughout; final docs/QA commit separate.

## 13. Known gotchas and prohibited shortcuts

- The active template folder is empty because the user moved the originals into Workspace.LegacyCourses. Course boot errors in the connected place are therefore real until templates exist there; copy the parked models in as fixtures when a baseline is needed. Isolated kit success never fixed that.
- There is no obstacle_6_002. obstacle_24 is the paddlewheel; obstacle_8 is the flat SwingPanel. obstacle_20/21 are humps, not jump pads. air_balloon is a basket balloon, not a beach ball. trampoline_5's child is trampoline_6.
- Mesh imported PivotOffset can point "forward" along +Y. Measure mechanical axes. Clearing a display pivot does not identify an axle.
- Hollow/nonconvex mesh center can be empty. GetPartsInPart center probes can miss real contact; sample actual collision surfaces.
- Place whole root hierarchies before reparenting their parts. BasePart:PivotTo alone leaves child geometry behind.
- Runtime kits cache assembled descendants. Do not append a new child after ScriptableRoot registration and expect it to be discovered.
- Course Origin.RotationSpeed must be 0. A missing value can activate legacy whole-assembly rotation.
- Server carry requires Origin.ServerCarries=true and supported RotorCarries/Seesaw ownership. Do not enable old client carry as a second solver.
- Source gallery parts can fall/disappear in Play. Export in Edit first.
- Instance.new("Player") is forbidden even in an ordinary Script. Use actual Players for production contact tests. Opaque {} identities in unit tests are not physics/player proof.
- Wait for an existing Player OR PlayerAdded, not PlayerAdded alone:
  local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
- JumpPower 50 is inactive with UseJumpPower=false; never compute this project's jump from defaults.
- Shared per-kit cooldown can suppress neighboring hazards. A phase cascade needs route-order contacts, not isolated tests alone.
- No permanent critical falling tiles. A racer respawning at a checkpoint must still finish.
- Rising-liquid MaxHeight is a relative rise, not absolute world Y.
- Foam penalty is ≥5 EXTRA seconds relative to direct route. Five seconds total is not enough.
- A "safe jump" through a timed sweeping arm is allowed. A launch/jump that bypasses the beat gate is not.
- ParSeconds is not evidence. Old .review screenshot galleries contained estimates, not completed route timings.
- Screenshot capture stalled once at Gate 2 and the tooling was repaired on 2026-09-15. Still check the actual file; a tool invocation or camera pose is not a screenshot.
- Current isolated physics results are high-frame-rate/single-machine; do not relabel them 60 Hz, 30-player or latency tests.
- Console can contain unrelated ConfigService/mock-player warnings. Record exact pre-existing warnings; any new Splashdown error fails. Never blanket-ignore all warnings.
- Read files with Get-Content -Encoding UTF8; earlier mojibake was console decoding, not bad file bytes.
- Preserve user changes; no git reset --hard, checkout --, whole-workspace cleanup or git add -A.
- Native Windows background helpers use Start-Process -WindowStyle Hidden. Do not launch visible helper windows unless needed for user interaction.
- Do not edit files using shell redirection tricks; use apply_patch for text/code. Native Studio model/place serialization is the intentional asset-export exception.
- No new bitmap/mesh generation. The task is existing-kit geometry, not an image-generation task.
- Do not dump long logs, whole evidence files or whole source files into the main context; section 2.4 applies to every stage.

## 14. Explicit STOP conditions

Halt the current stage, report exact error/evidence and ask for the missing approval/input when any of these occurs:

1. Gate 3 approval absent before non-pilot work.
2. Wrong place/lobby selected; source hashes or source model counts unexpectedly differ; Rojo cannot be confirmed current.
3. Dirty changes overlap this task and cannot be preserved safely.
4. Source-only export, actual screenshot, engine TestEZ, actual-player contact, interactive playtest or the Studio local multi-client session cannot run.
5. A needed asset, child role, socket or mesh collision surface cannot be identified from the existing kit. Do not import a substitute.
6. Required authored geometry cannot fit with uniform scaling and measured sockets without changing the route plan; no hidden collision patch.
7. An intended path fails, a gate can be bypassed, an ordinary gap is outside bounds, a primary kit exceeds 40% of encounters, a section 7 cross-course rule fails, a required kit/asset is missing, or the route permanently strands a checkpoint runner.
8. Pace or difficulty still fails after the three deterministic tuning passes.
9. Summit compliance requires changing original arc centerlines/checkpoint order/liquid schedule; obtain a scope decision.
10. Fix requires lifecycle/queue/movement/shared arena tuning or new public protocol behavior. Present a minimal proposed fix; do not implement before approval.
11. User's newer direction conflicts with this handoff. New user direction wins; record changed scope/acceptance explicitly.
12. An operation would delete a folder containing the 90 Keyframes, overwrite a foreign model/base file, retain deprecated course archives, publish or deploy without authority.
13. Withdrawn 2026-09-15: no real 30-player network session is required. Kept for numbering.
14. promote cannot install all seven templates, or a retired ID remains registered after the 12.1 transaction.

A STOP is not task completion. Leave report rows BLOCKED/FAIL/NOT RUN and state the next exact action needed. Do not silently lower the bar.

## 15. Final completion checklist

All boxes must be true before declaring completion:

- [ ] Gate 2 (2026-09-15) and Gate 3 approvals recorded with date/message reference.
- [ ] Appendix B recorded in docs/splashdown/03-overrides.md and the changelog; the scaled route-length targets recorded after the pilot.
- [ ] Six new declarative courses plus hardened Summit; correct final seven registered IDs.
- [ ] Source-only kit/Summit/arena exports and measured socket manifest checked in and hash verified.
- [ ] Builder rebuilds deterministically from a fresh source import; no hand-placed-only changes.
- [ ] Seven docs written before their builds; palette, layout kind, beats, actual tuning, layouts and five-question loophole tables complete.
- [ ] Attributes/name/authority/cooldown/guard constraints pass; no existing arena name-list/default regressions.
- [ ] Every course passes bounds, 30 spawns, checkpoints/finish, independent graph/cut sets, gap, support/seam/intersection, full-width/density/variety checks.
- [ ] On encounters: at least six primary hazard types/course, maximum 40%, four families, three elevation changes, ≤3 same-type run; full set-wide source coverage; section 7 cross-course rules pass over the whole set.
- [ ] Second-to-last climax and short readable finish verified; no decorative avoidable bumpers.
- [ ] Measured 60–90-second mid-policy median; clean expert ≤60%; actual interactive run per course; proxy/human limits stated.
- [ ] Every hazard's effectiveness challenged; falling-tile recovery and flood/checkpoint regression pass.
- [ ] Fourteen real fixed-camera images inspected and compared with refs 1/9/10/11; no capture claim without file.
- [ ] Studio local multi-client plus 30-rig load evidence; no single-rig result misrepresented.
- [ ] Headless tests 967+ with zero failures; Studio kit tests and 14 legacy-contract assertions plus all new QA tests pass, zero skipped.
- [ ] Normal arena behavior and three-course mode flow regression pass in the connected arena place after the 12.1 transaction.
- [ ] Six retiring parked models and seven old recipes/configs removed; no Deprecated archive; 90 Keyframes and original kit preserved.
- [ ] Summit route/checkpoints/rise schedule preserved and documented.
- [ ] No temporary probes, ghosts, fixtures, live courses or detached balls left in the connected place.
- [ ] No publishing, deployment or CD build performed.
- [ ] One local commit per course/Summit, separate infrastructure/integration/docs-QA commits; no unrelated files staged.
- [ ] qa-report.md and changelog state actual evidence, limitations, counts, commands and final commit IDs; no unreported failure.
- [ ] Section 1 of this file refreshed at the final commit.
- [ ] Final git status contains only explicitly explained user changes.

## Appendix A — exact files changed in Gates 1–2

The inventory is git diff --name-status 059e509..f866f7f. A = added, M = modified. HANDOFF.md is a later documentation-only addition. No file outside this list is claimed as a Gate 1–2 change. Regenerate the list with that exact command rather than trusting a copy.

## Appendix B — 2026-09-15 revision log

User decisions applied in this revision, in place. New user direction still wins over anything here (section 14.11).

Gate and blocker decisions:

1. Gate 2 approved. Sections 0, 4, 10, 14.1 and 15 no longer wait for it.
2. Templates folder: the user moved the original course contents into Workspace.LegacyCourses. The empty ReplicatedStorage.Assets.Maps.Splashdown is expected, not a baseline failure; the parked models may be copied in as fixtures (sections 1.2, 1.3, 2.1, 10.7, 12.1.5, 13).
3. screen_capture repaired. Section 4.6 retries once then STOPs; section 13 updated.
4. Multiplayer: no real 30-player session. Certification is the 30-rig stress test plus a Studio local multi-client session (2–4 clients). Section 8.5 rewritten; 14.13 withdrawn; 14.4 and 15 updated.
5. Arena base place: out of scope (CD workflow). Section 12.2 withdrawn; 12.3 runs in the connected arena place without build-place; 14.14 and the 15 checklist LFS/build items replaced.

Design overrides:

1. One layout kind per course (Serpentine, Spiral, Chute, Loop, Archipelago, StackedSwitchback; Summit unchanged) and one hue family per course. Sections 5 (Layout.Kind), 5.2 and 7 palette rewritten.
2. Headline exclusivity, a three-course cap per non-glue mechanic, and no shared beat recipes across courses. Consequences applied in section 7: Door Dash's tile climax replaced by 05_MaceMarch; Tiptoe's door beat replaced by 03_IslandHop (Whirlpool keeps the one door row allowed outside Door Dash); the "1 fan, 2 pads at 51/54" launch exists only in Ball Barrage; fans limited to Ball Barrage, Tumble Tunnels and Tiptoe Trials; conveyors to Ball Barrage, Door Dash and Piston Peak; seesaws to Tumble Tunnels, Tiptoe Trials and Piston Peak; Summit's hardening adds seesaws, a sweeper and a foam lane instead of tiles. Section 8.4 gains the cross-course check.
3. Variety scored on encounters, not instances (definition in section 7). All section 7 totals recomputed; per-instance counts are reported only. Sections 8.4, 14.7 and 15 updated.
4. Route length 800–1,000 studs; section 7 targets sum to about 800 per course, the pilot's measured pace fixes the set-wide target, remaining courses scale before they are built (sections 3.2, 5.2, 9.8, 10.8, 11).

Context budget: new section 2.4 (subagent delegation, large outputs to files, handoff refresh at every gate and before context runs low); section 0.9, 2.1 and 13 reference it.

Unchanged: all frozen contracts (3.1), asset and naming contracts (3.3), the section 6 presets except the door-course note and the obstacle_11 usage note, the STOP-not-estimate policy, and the deletion policy for retired courses.