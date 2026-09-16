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
- **Whirlpool Waltz is NOT certified.** Its scripted trials, fixed-camera captures, interactive
  keyboard run, deliberate missed-timing contacts and checkpoint-recovery checks are all NOT RUN,
  and its `CourseQA` status is BLOCKED by design while they are. A measured note for whoever runs
  them: a rider standing still on `Pizza01` is carried into one of the plate's real missing wedges
  and falls in about one second, which is the headline mechanic working, but it also means a
  straight-line `Humanoid:MoveTo` proxy cannot reliably cross a ride deck.
