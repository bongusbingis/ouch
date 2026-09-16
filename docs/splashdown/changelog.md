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

## 2026-09-16 — Tumble Tunnels (HANDOFF section 11, course three of five)

- Added `Layout.Kind = "Loop"` to `CourseBuilder`, the fourth layout kind, with five enforced
  invariants: a five-segment run/cross/run/cross/stub guide, segments 1/3/5 parallel with 3 reversed,
  both crosses exactly `LanePitch`, four turns of one handedness summing to exactly +-360 degrees,
  and the finish landing inside a declared closure window of the start plaza. A Loop also declares
  its central spine — `SpineHalfWidth` plus the two tunnel piece ids — and the builder checks the
  outbound tunnel is placed on guide run 1 and the return tunnel on run 3, which is what "the route
  crosses the spine twice" means in geometry. `BuildReport` gained `LoopClosureStuds` and
  `LoopTotalTurnDegrees`.
- Added three `CoursePresets`: `BeachBall` (ball_001, the kit's only standalone ball), `Seesaw`
  (obstacle_25, built as a CHAINED surface because the board is the route's own floor for 46 studs,
  so the lane meets it flush instead of across an invented gap) and `Mallet` (obstacle_1's
  single-mesh hammer, rocking about the measured base of its post). `PieceSpec` gained
  `PitchDegrees`, which lays a mounted asset on its side: 02-kits requires "Rotate the fan so the
  visual grate faces the same direction", and a horizontal airflow column needs exactly that.
  `AssetManifest` is version 4 with five measured sources added (arch_004/005/006, ball_001,
  obstacle_25_001, obstacle_1_001) and a `TunnelBore*` socket group for arches.
- **Built Tumble Tunnels**: spec hash `d390ff50`, 163 BaseParts, 880.45 measured studs against the
  880 target, six ordered checkpoints, beat ratios 0.880-1.124, elevation 0/+6/-6/+12/-6/+12/+6/-12
  matching section 7.4 exactly, identical hashes across a double build. `CourseQA.check` returns
  **zero errors and zero warnings**: 43 findings PASS, all seven gate cut sets hold (0 of 30 spawn
  cells bypass any gate) over a 20,739-node / 789,860-edge graph from 28,807 surface cells, all
  twelve cross-course checks pass over four staged specs, and the largest flat square is 21 x 21.
  Studio TestEZ: 16 passed, 0 failed.
- **The cut-set audit caught a real bypass twice before the enclosure was right.** Section 5.2 wants
  the finish "separated by enclosure so the finish is unreachable from the start plaza". A stack of
  six coincident platform slabs left a standable bevelled rim proud of each slab above it, and the
  graph found a 21-stud hop from the start plaza onto the third rim and a second hop from there onto
  the finish deck — 30 of 30 spawn cells bypassing all seven gates. Two thinner door panels failed
  identically. The shipped enclosure is ONE door panel at uniform scale 1.2 with no intermediate top
  at all. Third time stacked stock geometry has become a staircase in this project.
- **Beach balls are verified at the kit, not in a preview.** A new regression in
  `places/arena/tests/Assets/SplashdownQA.spec.luau` drives the real `BeachBalls` kit over the built
  model and asserts the balls are authored anchored with no motion owner, sit under
  `Rotating/<group>/Assembly` at the depth the kit scans, and after one `tickWorld` are unanchored,
  colliding, server-owned and reparented into `Scriptables/BeachBalls`. The door-slab defect that
  cost the Door Dash build a rebuild was invisible to both the build and the audit, and a beach ball
  has exactly the same failure mode.
- **Foam penalty measured rather than assumed.** At the kit's 0.45 multiplier every stud of foam
  costs 1/11.7 - 1/26 = 0.04696 s, so section 7.4's 112-stud centreline is +5.26 s against the direct
  path. Both channels are built at 111.99 studs, sit six studs under the LOWEST point of the lane
  beside them so neither is ever level with the route, and rejoin it with a six-stud step inside the
  measured 11.5-stud ledge.
- Sizing that the measurements forced, all recorded in the course document: the return tunnel is
  scaled by what lives inside it (a 0.5 paddle wheel is 29.91 studs across its axle) and the wheel is
  hung 8 studs below its deck so its cradles sweep through rider height instead of needing a
  near-full-size arch; the opposing fan stands at the outbound tunnel's far mouth because a
  17.69-stud cage on its side does not fit under a 12.93-stud ceiling, with its column axis 2.4 studs
  up so the balls are inside their own fan's 6.19-stud column.
- Added `src/config/Gameplay/Splashdown.luau`'s `Courses.TumbleTunnels` entry and
  `src/config/Interface/SplashdownIntro.luau`'s `Intro.Courses.TumbleTunnels` entry in the same
  change that put `TumbleTunnels` into `CourseOrder`; the template is promoted and
  `ReplicatedStorage.Assets.Maps.Splashdown` again matches `CourseOrder` exactly. Headless suite:
  984 tests, zero failures.

## 2026-09-16 — Section 11 / Tiptoe Trials

- Built `TiptoeTrials` from `src/shared/Game/Splashdown/CourseSpecs/TiptoeTrials.luau`, documented in
  `docs/splashdown/courses/tiptoe-trials.md`, evidenced in
  `docs/splashdown/evidence/courses/TiptoeTrials/{build,qa}.json` and two fixed-camera captures.
  **Spec hash `0f8e9510`, 160 BaseParts, 880.406 measured studs of route** against the 880 set-wide
  target, five ordered checkpoints, beats 0.929-1.106 of their scaled section 7.5 targets, elevation
  +12/-6/+6/+12/0/-6 matching section 7.5 exactly, zero attribute errors, zero route errors, zero
  bounds violations, identical hashes and part counts across a double build.
- `CourseQA.check` returns **zero errors and ZERO WARNINGS** (Status BLOCKED only because ten
  live-playtest items are outstanding): 45 findings PASS, 10 NOT RUN with reasons. All six gate cut
  sets hold (0 of 30 spawn cells bypass any gate) over a 14,680-node / 1,309,689-edge graph from
  16,171 sampled surface cells, all twelve cross-course checks pass over the five staged specs, and
  the largest flat square is 23 x 23. Studio TestEZ: **17 passed, 0 failed, 0 skipped.**
- New in the builder: **`Layout.Kind = "Archipelago"`**, the first layout with no guide polyline at
  all. An archipelago's guide IS its island list: each island declares a polar anchor the route must
  arrive at, and the builder enforces six invariants — at least five islands entered once each in
  order, strictly monotone anchor radii from perimeter to centre, every island after the first
  entered by a measured launch or tile-group crossing, every island beginning on a round landing
  deck, every heading change on such a deck within `MaxTurnDegrees`, and non-consecutive islands
  separated by more than the worst launch the course can produce. New `Island` piece kind; `Ride`
  extended to turn on a declared `TurnDegrees` outside a Spiral; `RouteStep` gained `Island` and a
  MEASURED `HalfWidth` (the oriented support width of every part the piece placed, projected onto the
  route's right vector), which is what the separation audit subtracts instead of a declared budget.
- **Reaches are derived, never declared.** The spec states HANDOFF 3.2's measured constants (gravity
  120, WalkSpeed 26, JumpHeight 10) and the builder solves the ballistic problem for each crossing's
  own rise, calibrated by the measured 22-stud flat gap against the model's own 21.23 prediction. A
  crossing an ordinary jump could make is rejected as a decorative launch; one past the tool's reach
  is rejected as unreachable. Measured: worst launch reach 38.89 studs, worst non-consecutive island
  separation 53.02 studs.
- **`CourseQA.buildGraph` now models launch edges (HANDOFF 8.2.5), for every course.** It previously
  built only Walk and ordinary Jump edges, so this course's 26- and 27.5-stud pad launches did not
  exist in the graph and the first audit reported the Checkpoint05-to-Finish leg unreachable. The
  audit now reads each launch tool off the BUILT model — its own LaunchSpeed, FloatFactor and
  measured footprint — recomputes the reach for every candidate landing height, and adds Launch edges
  about the tool's own axis; a horizontal ball-pushing fan is excluded and reported by name.
  `ENCOUNTER_TYPES` also gained `FallingTile`, without which the variety audit scored this course at
  11 encounters and five types instead of the 16 and six section 7.5 specifies.
- **Falling tiles are verified at the kit, not in a preview.** A new regression in
  `places/arena/tests/Assets/SplashdownQA.spec.luau` drives the real `FallingTiles` kit over the
  built model: it asserts every tile is authored anchored and colliding with `CriticalRoute`, a
  positive `RespawnSeconds`, a numeric `DropDelaySeconds` and no competing motion owner, sitting
  under `Rotating/<group>/Assembly` at the depth `FeatureParts.collect` scans; then it registers the
  tiles, arms one through the kit's own downward support raycast, confirms the tile is still solid
  halfway through its countdown, loses collision/query/visibility when it expires, and comes back
  after `RespawnSeconds`. Third kit given this treatment after doors and beach balls.
- Measurement that the build forced, all in the course document: obstacle_11's plank clears its own
  fulcrum bar only within 4.253 * scale studs of the axle, so it stands on a single 1.69-stud-thick
  door panel instead of a platform plinth; both hammers are axle housings with their heads suspended
  beneath them, so mounting them on the deck the way the pilot does puts the head entirely below the
  lane, and they hang instead under HANDOFF 8.3's suspended-pendulum exemption; the beat 01 fan
  stands IN the water seven studs past the shore, because mounted on the deck its 6.19-stud column
  would fire the launch before the island's edge and the flight would need 26.69 studs of reach
  against the 22.96 it makes.
- `AssetManifest` is version 5 with three measured sources added: `color_box_001..008` (one mesh in
  eight colours, all three sampled variants returning identical extents), `trampoline_5_001` with its
  real `trampoline_6_001` inner child, and `obstacle_11_001` with measured fulcrum and plank roles.
  `CoursePresets` gained the `FallingTile` preset, generalised its `Seesaw` branch to the manifest's
  declared board sub-part so it drives both board forms, and now resolves a sub-part by its whole
  declared name before splitting on dots — obstacle_11's plank is literally called
  "obstacle_9_001.001" and the old split would have cloned the unrelated top-level conveyor in.
- **Its scripted trials were NOT COMPLETED**, per the user's standing 2026-09-16 decision that this
  category is reported plainly and not chased. No trial numbers are claimed. The two bounded guards
  HANDOFF 1.4 recommended were applied to `run-course-routes.server.luau` and are UNEXERCISED: the
  engine rig is now fetched once and cloned for later trials instead of one
  `CreateHumanoidModelFromDescription` web call per trial, and the pass has a 2,400-second wall clock
  of its own that stops it starting new trials and reports `abandonedTrials` rather than hanging.
  The interactive keyboard run, the deliberate missed-timing contacts and the checkpoint-recovery run
  are outstanding for this course exactly as they are for the other four.
- Added `src/config/Gameplay/Splashdown.luau`'s `Courses.TiptoeTrials` entry and
  `src/config/Interface/SplashdownIntro.luau`'s `Intro.Courses.TiptoeTrials` entry in the same change
  that put `TiptoeTrials` into `CourseOrder`; the template is promoted and
  `ReplicatedStorage.Assets.Maps.Splashdown` again matches `CourseOrder` exactly. Headless suite:
  984 tests, zero failures.

## 2026-09-16 — Piston Peak (HANDOFF section 7.6), the sixth and last new course

- **StackedSwitchback**, the sixth layout kind. Five short runs stacked over two centrelines 40 studs
  apart, joined by four switchback landings, climbing 66 studs. Its guide IS a polyline — unlike an
  Archipelago's island list — but one that deliberately retraces itself, because a switchback
  staircase in plan view is a rectangle walked in one rotational direction. Six enforced invariants:
  an odd segment count of at least five with runs on the odd segments and one lane pitch on every
  even one; `LanePitch` inside a declared 30-40 band; runs and crosses each alternating through 180
  degrees with every turn a same-handed right angle; every run's MEASURED elevation climbing; two
  runs sharing a centreline separated by more than a declared clearance that must itself beat the
  measured 11.5-stud step-up; and no measured pair of route steps on different runs saving at least
  `MinBypassStuds` of route inside the ordinary jump reach for its own rise unless a declared guard
  wall stands across the line between them.
- Spec hash **`e164c528`**, 162 BaseParts, **880.000 measured studs** of route, six ordered
  checkpoints, beats 0.909-1.050 of their scaled section 7.6 targets, elevation
  +12/+12/+6/+6/+12/+12/+6 matching section 7.6 exactly, StartY 0 and finishY 66. Identical hash and
  part count across a double build. `CourseQA.check`: zero errors, ZERO WARNINGS, 50 findings PASS,
  11 NOT RUN with reasons, 0 FAIL, over a 13,886-node / 1,854,187-edge graph from 15,945 real surface
  cells, with all twelve cross-course checks passing over the six staged specs. Studio TestEZ: 20
  passed, 0 failed.
- **The only new course with section 6's rising liquid.** Section 7.6's seed (baseY -30, delay 20,
  0.4 studs/s, MaxHeight 60) stops the flood at world-local +30 and drowns the checkpoints at Y 12
  and Y 24 — a racer respawning on a submerged pad splashes and respawns on it again. 7.6's own
  remedy is to lower MaxHeight in 2-stud steps; 60 down to 38 stops it at +8, four studs under the
  lowest pad. `CourseBuilder` now writes the schedule onto the course's own Hazards part from a new
  `Layout.Rise`, and measures the lowest checkpoint the route places against the finished flood line.
- **Ball Barrage's two pistons are inert, measured on the promoted template.** Piston01's head spans
  world Z 72.30-80.02 while its beat-03 lane spans Z 45.49-66.51: the head sweeps 5.8 to 9.7 studs
  beyond the lane edge over open water, and Piston02 is the same mirrored. The head lies along the
  piece's own forward, so a base placed inside the lane facing outward throws the head away from the
  runner. Its two hammers are effectively inert too — HammerLarge's head spans Y 5.70-24.46 under a
  lane whose top is Y 24.00. Neither was fixed: Gate 3 was approved with them and that is the user's
  call. The new generic `SplashdownQA.spec` assertion would fail against BallBarrage, which is the
  evidence.
- **Two real bugs found in shared QA code, both invisible until a course stacked itself.**
  `CourseQA.sampleSurfaces` sampled each X/Z column once but over the vertical window of whichever
  part claimed it first, so four of this tower's five storeys were never sampled and the audit
  reported the route unreachable; the window is now the whole model's extent and the per-column
  stacked budget went from 12 to 24 hits. That made the graph five times denser and
  `CourseGraph.edgeCutByGate`, which walked every edge at half-stud resolution once per gate,
  exhausted Studio's execution budget; it now rejects on an axis-aligned bounding box first (which
  cannot change a verdict) and `reachingNodes` takes an optional cooperative yield the engine caller
  supplies while the headless graph tests pass nothing.
- **A tall stock frame on a lower storey of a tower is a ladder.** The log-rolls were `obstacle_2_001`,
  whose cradle stands 32.284 studs above its own mount; the cut-set audit measured standable cells on
  the frame at Y 28 and Y 41 above a run-2 deck at Y 24 and then a jump onto beat 06's ramp at Y 53,
  skipping three beats. Replaced with `obstacle_10_001`, the kit's single-mesh barrel laid on its
  side, whose own crest is 4.67 studs above the deck. Tumble Tunnels' staircase lesson in a fourth
  form.
- Three pistons alternating sides at mount distance 17 each reached 0.02 studs past the ledge
  centreline at rest, and between them their rest poses sealed the corridor so no standable cell
  survived. At 19.5 each head leaves a measured 4.96-stud corridor at rest and still seals the ledge
  edge to edge when it fires.
- `CourseBuilder.cornerRun` leaves a RIGHT turn through `SideNegativeX`, not `SidePositiveX`; using
  the wrong socket put a hairpin 0.11 studs past its vertex. `auditBounds` now reports QA gate
  extents separately and holds them to the 600-corner rule only, on the same reasoning that already
  excluded the perimeter ring and the liquid plane from the -30..90 route band.
- New in `CoursePresets`: the `LogRoll` preset (drives a declared drum on a framed roller, or the
  root on a single-mesh barrel) and a `RotorAxis` piece field. `AssetManifest` is version 6 with
  `wall_001`, `wall_002`, `trampoline_2_001`, `obstacle_10_001` and a measured `ContactRadius` on
  `obstacle_2_001`. `auditCrossCourse` now scores a declared headline at preset granularity when it
  names a preset, which is what lets Piston Peak declare `"Piston"` without colliding with every
  pendulum in the set; the five type-named courses are scored exactly as before.
- **Its scripted trials were NOT COMPLETED**, per the user's standing 2026-09-16 decision. No trial
  numbers are claimed. The interactive keyboard run, the deliberate missed-timing contacts and the
  checkpoint-recovery run are outstanding for this course exactly as for the other five.
- Added `Courses.PistonPeak` (with its `LavaRise` record) and `Intro.Courses.PistonPeak` in the same
  change that put `PistonPeak` into `CourseOrder`; the template is promoted and
  `ReplicatedStorage.Assets.Maps.Splashdown` matches `CourseOrder` exactly at six models. Headless
  suite: 984 tests, zero failures.
