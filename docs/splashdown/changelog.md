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
