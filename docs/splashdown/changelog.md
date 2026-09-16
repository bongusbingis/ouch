# Splashdown change log

## 2026-09-15 — Phase 0 / Gate 1

- Audited lifecycle, checkpoints, scoring, shared/attribute kits, Summit rise and authoring pipeline against current source and connected Match Place.
- Added findings, a complete 176-root / 222-part asset inventory, six-course/kit proposal, and reproducible discovery probes.
- Ran 960 headless tests (zero failures). Ran real Studio TestEZ course contracts: 0/16 as opened; 14/16 with temporary copies; CrossCurrent remains missing.
- Recorded 123 movement trials, including failed short-input diagnostics. Corrected 33-trial confirmation gives 22–22.25 stud flat-gap and 11.5–11.75 stud ledge brackets for the tested avatar.
- Captured 18 fixed-camera Studio evidence images, including all seven parked-course overheads and targeted asset identification.
- Corrected visual crosswalk: cyan cradles = obstacle24; square SwingPanel = obstacle8; obstacle25 is a plank used as a windmill; large striped balloon is not a beach ball.
- Removed only the temporary discovery bootstrap and its owned Play fixtures/copies. Existing courses, gameplay source, config values, registrations and arena name lists are unchanged.
- Gate 1 was subsequently approved. User explicitly rejected preserving deprecated courses; retirement will not create an archive.

## 2026-09-15 — Phase 1 / Gate 2

- Added BigBall, Conveyor, FallingTile and deterministic Seesaw kits; added asymmetric hammer/piston Rotor profiles and optional epoch-based spin acceleration.
- Fixed nested Rotor ownership/transforms and ancestor contact velocity; added opt-in full-XYZ server carry, disabling duplicate client carry only for marked course groups.
- Fixed ignored per-pad LaunchSpeed; extended attribute fans to directional launches/ball airflow; extended renamed multiple beach balls with server ownership and owned cleanup.
- Added optional actual-mesh shove contact, per-part cooldown/guard settings and client-only impact/shake ghosts. Existing arena values/name lists remain unchanged.
- Fixed cleanup dispatch for kits sharing the last Rotating group, detached ball removal, and stale mover followers after a ball leaves its assembly.
- Added strict door-row validation for 3–5-door layouts and reusable rising-liquid trajectories/pauses with legacy Summit parity. Round flow, spawning, checkpoints, falls, scoring and finish detection remain unchanged.
- Added attribute preflight, 25 passing Studio engine smoke tests, eighteen original-mesh/R15 physics trials (nine scenarios repeated), actual-Player contact checks and client presentation observations. Headless suite: 967 tests, zero failures.
- Added reproducible temporary fixture/probe scripts and raw JSON evidence; source kit fixture contains 16 existing-asset models / 37 parts, not a new course. The attempted new fixed-camera capture stalled; no new screenshot is claimed.
- Gate 2 awaits approval. No pilot/new course or Summit layout hardening has started. Baseline missing course-template failures are not represented as fixed.

## 2026-09-15 — Gate 2 approved / handoff revision

- Gate 2 approved by the user. `HANDOFF.md` revised in place with four blocker decisions
  (screen_capture repaired; no real 30-player session; arena base place/CD build withdrawn from
  scope; empty templates folder confirmed expected) and four design overrides (one layout kind and
  hue family per course; headline exclusivity/three-course mechanic cap/no shared beat recipes;
  variety scored on encounters not instances; 800-1,000 stud route length with the pilot fixing the
  set-wide target). Recorded verbatim in `03-overrides.md`.
- Added HANDOFF section 2.4 (context-budget rules: subagent delegation for mechanical work, large
  outputs to files, handoff refresh at every gate).
- Read-only health checks re-run at the recorded HEAD (`f866f7f`): 967 headless tests/0 failures,
  clean whitespace diff, connected Match Place (placeId 121997450145716) confirmed in Edit mode
  with MapOrigin, gravity, 97 LegacyCourses children, 0 Splashdown templates and ServerStorage.Tests
  all matching the recorded snapshot. No code changed by this entry.

## 2026-09-15 — Gate 3 prerequisites (section 4)

- Built a source-only export group in Studio (`ServerStorage.SplashdownAuthoringSources`): `Kit`
  (clone of `Workspace.battle_stadium`, 176 roots / 222 BaseParts, exact match to the inventory),
  `SummitSource` (clone of `Workspace.LegacyCourses.SummitSplash`, 258 BaseParts), and
  `ArenaSources` with `LiquidMesh` (the ElimZones water MeshPart) and one `BoundaryWall` (chosen by
  a deterministic name+position sort since all 26 boundary parts share the name "Part"). No other
  `LegacyCourses` child was touched; the original source gallery is unmodified.
- Native "Save to File..." UI export was initially blocked: this session had no interactive desktop
  window (`mcp__desktop__screenshot` BitBlt failure, `capture_studio.py` "window not found", and a
  raw Win32 `EnumWindows` call returning zero visible windows system-wide). After a computer
  restart gave the session a real window, exported all three groups as Roblox XML models:
  `assets/splashdown/kit-source.rbxmx` (2,300,045 bytes), `assets/splashdown/summit-source.rbxmx`
  (1,444,428 bytes), `assets/splashdown/arena-sources.rbxmx` (24,535 bytes). SHA256 hashes and
  hierarchy/counts recorded in `docs/splashdown/evidence/source-hashes.json`.
- Verified round-trip fidelity: re-imported `kit-source.rbxmx` into a disposable `Workspace.Kit`
  via File > Import Roblox Model and compared every BasePart against the live source
  (`Workspace.battle_stadium`) on relative path, ClassName, Size, MeshId and CanCollide — 222/222
  parts matched with zero diffs. The disposable import and its temporary container were destroyed
  immediately after.
- Captured an actual fixed-camera screenshot of the source kit (camera at (-537.767, 500.777, 46)
  looking at (-537.767, 460.777, -54.314), FOV 70) and saved it to
  `docs/splashdown/evidence/kit-source-capture.png`; the Edit-mode camera was restored to
  `Enum.CameraType.Custom` afterward. `screen_capture`'s own return is transient image data with no
  file, so the real file came from a real-window OS-level capture once one was available.
- Section 4 (Gate 2 closure and Gate 3 prerequisites) is complete: exports, hashes, reimport
  verification and screenshot are all real, checked-in evidence. No course, spec or QA module has
  been built yet; that is section 5 onward.

## 2026-09-16 — Section 11: pace target fixed, Whirlpool Waltz built

- **Committed the pilot's post-approval tuning pass** (`4c040b6`): `Ball01`/`02`/`03` in
  `CourseSpecs/BallBarrage.luau` each gained `OffsetUp = -6`, submerging the mounting pole six studs
  deeper so contact lands in the `CapDegrees` top cone instead of glancing off as `RollOff`. The
  temporary local-test `CourseOrder` override was reverted first; it was making the headless suite
  fail, because `SplashdownIntroModel` iterates `CourseOrder` and requires a matching entry in
  `src/config/Interface/SplashdownIntro.luau`. **Every new course ID will need one of those entries
  at the section 12 swap.**
- **Executed `run-course-routes.server.luau` for the first time** and fixed three bugs it exposed,
  each of which had been silently producing wrong results rather than no results: jumping was gated
  behind the policy decision interval (so a mid runner had a quarter-second reflex floor and stalled
  at every gap); contacts could never fire, because `CoursePresets` builds pieces with
  `CanTouch = false` and a `Touched` connection on the rig is therefore dead; and
  `Workspace.Baseplate` sits at Y 0 under an isolated course, so falls landed on it and eight runs
  recorded zero falls. The harness now resolves jumping, falling and contact every frame inside the
  policy interval, samples contacts by overlap query against the `Scriptables` tree, and lifts the
  isolated clone to Y 20000 first.
- Added door handling to the harness, as HANDOFF 8.5 prescribes: nothing calls `Doors.setPlan` in an
  isolated clone and `Doors.tickPlayer` selects Players, so a door row is otherwise impassable to a
  scripted rig. The harness now carries a seeded per-trial door plan, expert aims at the slab that
  gives, mid works the row centre-out and pays for wrong guesses, and slabs are restored between
  resets.
- **Fixed the set-wide route-length target at 880 measured studs** with the section 7 beat targets
  unchanged, recorded with its full derivation in `03-overrides.md`. With the baseplate fixed, the
  pilot re-measured at a mid-policy median of **63.66 s** (5 of 5 resets cleared) against a clean
  expert time of 38.35 s (3 of 3) -- inside section 8.5's 60-90 s window, with an expert/mid ratio
  of 0.6024 against a 0.60 bar. The earlier 40.18 s median was the baseplate artefact and is
  superseded. `01_Countercurrent/Bumper01` was contacted in none of the runs and is flagged.
- **Built Whirlpool Waltz** (`CourseSpecs/WhirlpoolWaltz.luau`, doc
  `courses/whirlpool-waltz.md`): a clockwise descending spiral, route 884.78 studs on an 896.04-stud
  guide with a worst deviation of 7.07 against a 12-stud tolerance, six beats all inside their
  length bands, elevation matching the section 7.2 Y column exactly, 17 encounters over six types
  with a 35.3% maximum, and all 23 spiral gaps inside the authorised 13.5-19.5 band.
- Extended the builder and the audit to make that possible: a parametric `Spiral` layout kind, new
  `Ride` and `Flank` piece kinds, new `Spinner` / `RidePlatform` / `RoundLanding` / `SwingPanel` /
  `Door` / `FoamPit` / `Prop` presets, 18 new measured `AssetManifest` sources (walkable ones
  raycast-measured into `evidence/course-sockets-whirlpoolwaltz.json`), a declared `Headline` field,
  and `CourseQA.auditCrossCourse` scoring override 2's three cross-course rules over every spec that
  exists. Two builder fixes with wider reach: guide travel is measured horizontally, so a course
  starting elevated no longer begins tens of studs along its own guide, and a beat whose pieces
  carry riders gets `ServerCarries = true` on its group Origin.
- **The cut-set audit had two real defects and the new course found both.**
  `GateCutSet:05_DiscDive` failed with all 30 spawn cells still reaching Finish; the traced bypass
  was a 22-stud jump that crossed the gate plane seven studs BELOW the beat entrance, because gates
  reached only two studs below it, and the fixed twelve-sample edge test was 2-stud resolution on a
  22-stud jump so even the 0.3 studs where it did clip the gate fell between samples. Gates now span
  22 below to 38 above, edges are sampled every 0.5 studs, and `CourseGraph.spec` carries a seeded
  corner-clip fixture the old test provably missed. **Ball Barrage was re-audited under the stricter
  gate and still passes all six of its own cut sets.** Whirlpool Waltz now returns zero errors and
  zero non-PASS findings over a 12,181-node / 383,518-edge graph from 14,844 sampled cells.
- Headless suite: 975 to 984 tests, 0 failures, with a new `CourseVariety.spec` proving each
  cross-course rule fires against a seeded violation.
- **Whirlpool Waltz is NOT certified and its scripted trials FAILED: 0 of 8 runs cleared.** Every
  run hit the 150 s ceiling with 31-32 falls and only checkpoint 1 earned, all of them dying on
  `Pizza01`, the first ride deck. The mechanism is measured: a rider standing still on that plate
  stands safely for 1.0 s and is then carried into one of its real missing wedges, and crossing the
  26.4-stud deck also takes about 1.0 s at WalkSpeed 26. That is the headline mechanic working, and
  it is also exactly what an unclearable beat would look like — a straight-line proxy cannot
  distinguish them. HANDOFF 8.5's resolution applies: the interactive keyboard run is the blocking
  evidence, and beat 02's difficulty is an open question until it happens. Its fixed-camera
  captures, deliberate missed-timing contacts and checkpoint-recovery checks are also NOT RUN, and
  `CourseQA` reports BLOCKED by design while they are.
- Added `docs/splashdown/qa-report.md`, the per-course acceptance matrix HANDOFF section 5 requires
  and which did not exist.

## 2026-09-16 — Section 11: Door Dash built, and two builder bugs it exposed

- **Door Dash is built, staged, promoted and live in `CourseOrder`** alongside Ball Barrage and
  Whirlpool Waltz, with its `Splashdown.Courses.DoorDash` entry (including
  `Doors = { PerRow = 5, BreakablePerRow = 2 }`) and its `SplashdownIntro.Courses.DoorDash`
  camera entry added in the same change — the intro-camera prerequisite that was missed for the
  first two courses and is now a standing rule. Headless suite: **984 tests, 0 failures.**
  Spec hash `8c00a748`, 221 BaseParts, 882.07 measured studs of route against the 880 target,
  all six beats inside 0.85-1.15, zero attribute errors, zero route errors, zero bounds
  violations, identical hashes across three independent builds plus a fourth inside Play.
- **`Layout.Kind = "Chute"` is new** (HANDOFF 5.2): a three-segment run/cross/run polyline whose
  invariants the builder now enforces — exactly three segments, the second run doubling back on the
  first, the cross segment equal to `LanePitch`, both runs at least twice the pitch, and the
  hairpin turning inside a declared window of the finished route. Door Dash's hairpin enters at
  53.19% of the route, reverses at 60.09% and rejoins at 66.98%, which is 5.2's "roughly 55-60%"
  measured at the turn itself.
- New presets **`Mace`** (rock on the top link, which is both axle and shove owner, so the nine
  links and the ball shove as followers) and **`PaddleWheel`**. The paddle wheel needed more than
  attributes: its four cradles orbit a point 4.25 studs below the root mesh's own centre, and an
  attribute rotor turns about its part's pivot, so the measured axle is now set back as an explicit
  `PivotOffset` after scaling — 02-kits.md's "change pivots, never distort the mesh", applied for
  the first time. `AssetManifest` is version 3 with `obstacle_5_001`, `obstacle_24_001` and
  `trampoline_4_001` measured into `evidence/course-sockets-doordash.json`.
- **Two real builder bugs, found by building the first course with doors and the first with a
  nested assembly.**
  1. **Door slabs were invisible to the door kit.** `CoursePresets` parented each slab inside a
     holder Model, but `DoorRows.resolve` and `MapFeatureService` both walk the Doors folder's
     IMMEDIATE BasePart children, so every row resolved as zero rows and every slab would have
     stayed permanently solid — a wall across the corridor. Slabs are now parented straight into
     `Scriptables/Doors`, as foam volumes already were. This also silently affected Whirlpool
     Waltz's one door row.
  2. **Every nested assembly was built twice.** Cloning a root brings its whole source subtree, and
     the code then cloned each declared sub-part from the source on top of it: the pilot's pistons
     carried a duplicate spring and head, and a mace would have carried a duplicate ten-part chain.
     Sub-parts are now resolved inside the root clone first, and any descendant the manifest does
     not name is renamed out of its source name (several MapFeatures kits select by name prefix, so
     an unrenamed nested part could be driven twice).
  Both fixes change the other two courses' geometry, so all three were re-staged and re-promoted:
  Ball Barrage 156 to 143 BaseParts (`ca5e95b4`), Whirlpool Waltz 151 to 142 (`78e562b8`).
- `CourseAuthoring.stage` now parks the full `BuildReport` for every staged course in
  `ServerStorage.SplashdownStageReport` (and each route trace beside it), because the Command Bar is
  the only place `stage` can run and its Output cannot be read back reliably from an assistant
  session.
- **The door tops were climbable, and the scripted trials are what caught it.** The first build
  reasoned that a 14.65-stud slab cannot be climbed, because the movement evidence says an 11.5-stud
  ledge succeeds and 11.75 fails; the route rig then spent every run standing on top of row 1. A
  direct measurement on the built course settled it: a plain R15 rig walking into a solid slab and
  jumping rose **13.6 studs onto the door top in about 0.6 seconds**. Repeated jumps into a flat
  wall climb further than one jump onto a ledge, so `CourseQA`'s graph -- which caps a jump's rise
  at the 11.5-stud calibration -- did not model it either. **That is a limit of the graph, not a
  Door Dash quirk, and it should be carried into every later course.** Section 6's own remedy is now
  applied: the door section is roofed with four stepped bands of stock slabs (20 parts) whose
  undersides sit 0.01-1.01 studs above the door tops, leaving far less than the 5 studs of headroom
  a standable surface needs. The same climb test against the roofed build reaches **+6.64 studs** and
  ends back on the floor. Re-audited after the roof: still zero errors, zero warnings, 37 of 50
  findings PASS, largest flat square 19 x 19, all six gate cut sets and all twelve cross-course
  checks holding over a 29,481-node / 1,628,229-edge graph from 39,060 sampled cells.
- **Four harness fixes in `run-course-routes.server.luau`, all found by running the first course
  with real door rows.** None of them changed the course; all four made the earlier results wrong.
  1. A row the runner has already opened is now skipped by the targeting logic. Without it the aim
     stayed locked on the slab the runner had just broken -- the row is still inside the 36-stud
     approach radius -- so the runner walked back into its own doorway and the stall logic then sent
     it sideways along a row it had already passed.
  2. The runner no longer jumps at a door row. The stall-jump is a gap heuristic and a door slab is
     a wall; jumping into one repeatedly is exactly what climbed it.
  3. The door retry no longer rewinds the progress clock. It reset `lastProgress` every 1.5 s, which
     kept the elapsed-since-progress figure under 2.25 s forever, so a runner jammed at a row never
     recorded a stuck FAIL and burned the whole 150 s ceiling instead.
  4. Progress is measured against whatever the runner is walking at, not always the next waypoint. A
     door row is worked sideways, so the waypoint distance does not fall while the runner tries
     slabs: an expert trial broke row 1 at 5.66 s and row 2 at 9.22 s and was then failed at 19.2 s
     for "no progress". An aim change resets only the distance baseline, never the stuck clock --
     rewinding it let a runner sitting on the 36-stud door-approach boundary flicker between two
     aims and never record a stuck FAIL at all.
  5. After a slab gives, the runner walks eight studs THROUGH the hole it just made, and the row is
     only behind it once it is out the other side (measured by the sign of its position in the
     slab's own frame). Aiming at the next row immediately sent it diagonally into the solid slabs
     beside its own opening, where a proxy with no steering simply presses against a wall.
  6. A checkpoint respawn clears the "already crossed" flags. The holes stay open -- that is what
     the real kit does for the rest of the round -- but the rows are ahead of the runner again.
  7. The breakable-per-row quota is read from the same course config production uses. It was
     hand-set to 1 while Whirlpool Waltz (3/1) was the only course with doors, so Door Dash (5/2)
     was being measured against a quota the real round never deals.
- **The roof took three passes, and the cut-set audit caught each wrong one**: flush undersides left
  a 0-1 stud gap the rig jammed in; undersides just below the tallest top left the outer doors 0.46
  studs proud, which the audit traced as a staircase onto the roof and past five gates; and a roof
  25 studs wider than the corridor was itself a bridge to the second run, 18 studs across and 18
  down. The shipped roof sits below every door top and is exactly the corridor's width.
- **A second real course defect the trials found: the outermost door's opening led half over open
  water.** The doors had been scaled independently of the floor (24.05-stud slabs over 19.62-stud
  channels), so a row of five overhung the corridor by 11 studs a side, and a trial that walked
  through the outer door fell off the deck. Doors are now scaled so one slab is exactly one channel
  wide and the row spans the corridor exactly -- measured z 6.95 to 105.05 for both -- with each sill
  on its own channel at that channel's height.
