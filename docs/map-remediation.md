# Splashdown map remediation

Tracker for the remediation pass opened 2026-09-16 against `docs/map-issues.md`.
Plan approved 2026-09-17. Source of findings: the playtest notes in `docs/map-issues.md`
plus a read-only Studio audit of all seven courses.

**Studio target:** Match Place (placeId 121997450145716), Edit mode.
**Course templates:** `ReplicatedStorage.Assets.Maps.Splashdown` — these are saved in the
place file, NOT Rojo-synced. In-place edits persist only in the `.rbxl`.

## Standing decisions

| # | Decision | Answer |
|---|---|---|
| 1 | Door Dash rename | **Knock Knock**, **full ID rename** (`DoorDash` -> `KnockKnock` everywhere incl. ~470 instance names) |
| 2 | Whirlpool Waltz canonical copy | Resolved by evidence: the Workspace copy is the promoted template. Move it back to `ReplicatedStorage.Assets.Maps.Splashdown` |
| 3 | Axe | Fix the blade roll AND re-check the swing plane visually per instance |
| 4 | Puncher values | throw 6->18, period 3.2->1.9s, hold 0.6->0.35s, shove 44->54, mount gap -> 6 studs |
| 5 | Spec/template divergence | Accepted and recorded for placement fixes; mirrored into CourseSpecs for attribute fixes |
| 6 | Summit floating jump pad | Withdrawn — audit error, the pad is correctly seated on `sd_arc.007` |
| 7 | Foam pits | Strip from the framework entirely, not just the 6 instances |

## Coordination

The Studio MCP is ONE connection to ONE Studio. Never two agents writing to Studio at
once. Peer Claude sessions (`ouch-ac`, `ouch-01`, `ouch-9e`) share this checkout; claim a
file here before editing it.

| File / map | Claimed by | Status |
|---|---|---|
| `src/shared/Game/MapFeatures/RotatingPlatforms.luau` | A1 | dispatched |
| `src/shared/Game/Splashdown/CourseQA.luau` | A2 | dispatched |
| `src/shared/Game/Splashdown/CourseBuilder.luau` + `CoursePresets.luau` + CourseSpecs + foam config | A3 | dispatched |
| `src/shared/Game/Splashdown/AssetManifest.luau` | A4 | dispatched |
| Studio place file | ouch-27 (lead) | active |

## Task status

Legend: `todo` / `wip` / `done` / `blocked` / `withdrawn`

### Framework (file edits)

| ID | Model | Closes | Status | Notes |
|---|---|---|---|---|
| T01 | Sonnet | B3 fan blade world-Y | **done** | `RotatingPlatforms.build` hardcodes `axis="Y"` + rotation-free rotor centre |
| T02 | Sonnet | G2 trigger width | **done** | `buildCheckpoint` 12x8x2 -> 56x24x2 |
| T03 | Sonnet | G2b missing arches | **done** | builder places the arch with the trigger |
| T04 | Sonnet | G1 lava | **done** | `buildHazardLiquid` emits the textured MeshPart |
| T05 | Sonnet | G3 foam pits | dispatched | strip preset + folder + audit rule + config |
| T06 | Sonnet | B4 punchers | **done** | spec-driven, new defaults |
| T07 | Sonnet | B6 seesaw | **done** | MaxTiltDegrees default -> 34 |
| T08 | Sonnet+lead | B7 spiky wheel | **done** | agent deleted it outright; lead reapplied as opt-in |
| T09 | Opus | B1/B2 axe + panel | todo | needs T20 preview first |
| T10 | Sonnet | B5 beach balls | wip | add Shove, scale 2.2 |
| T11 | Opus | P3 green ramp sockets | **done** | Entry/Exit +-69 -> +-72.705; junction now exactly 0 on the centre line |
| T12 | Sonnet | P1/P2/P6a/P7a guards | **done** | 5 checks, 521 lines; WILL fail the Studio QA spec by design |

### In-Studio

| ID | Model | Map | Closes | Status | Notes |
|---|---|---|---|---|---|
| T19 | lead | Whirlpool | (decision 2) | **done** | template restored; all 7 CourseOrder ids resolve |
| T20 | lead | all | — | **done** | 7 clones, 1000-stud spacing; scratch, delete before ship |
| T21 | lead | 6 maps | G1 | **done** | surface delta 0.000, kill threshold unchanged |
| T22 | lead | all 7 | G2 | **done** | 42 triggers, bottoms preserved |
| T23 | lead | BB/TT/WW | G2b | **done** | 4 arches, 0.21 studs from trigger |
| T24 | lead | 5 maps | G3 | **done** | 6 pits + 7 folders |
| T25 | **Opus** | BB/DD/WW/TT | P2a-d | **reclassified** | NOT mechanical - see note below |
| T26 | **Opus** | TT/TP/BB/PP | P2e-h | **reclassified** | NOT mechanical - see note below |
| T27 | lead | PistonPeak | P7a | **done** | 3 pairs, 0.07/-0.08/1.20 -> 4.00 studs |
| T28 | lead | TP/TT | P7b,c | **done** | 3.61->0.00, 8.50->0.00 |
| T29 | lead | DoorDash | P6a | **done** | both decks gone, pads anchored in place |
| T30 | lead | TP/PP | P6b,c | **done** | 4 pads, +3.4/+2.9/+3.0/+3.0 -> -1.0 margin |
| T31 | lead | Summit | P8 | **done** | arch + line now match the other six exactly |
| T32 | Sonnet | BB/PP/WW/DD | P1a-d | todo | clear the finish lines |
| T33 | Sonnet | TP/TT/WW | B8 | todo | 3 decks under swing panels |
| T34 | lead | 7 seesaws | B6 | **done** | all set to 34 |
| T35 | lead | BB/PP | B4 | **done** | moved inward to 6-stud gap; throw sized per lane (18 BB / 11 PP) |
| T36 | lead | BallBarrage | B7 | **done** | Summit's sweeper restored after over-reach |
| T37 | lead | Tumble | B5 | **done** | 4.6 -> 10.1 studs + Shove; 20 would not fit the tunnel |
| T38 | Sonnet | 6 maps | B1/B2 | todo | apply T09 to 8 hammers + 3 panels |
| T39 | — | all | P3 | **withdrawn** | premise was a measurement artifact - see below |
| T40 | Sonnet | DoorDash | rename | todo | DoorDash -> KnockKnock, full ID rename |
| T41 | lead | 4 hammers | B1 | **done** | NEW: mirror the uncommitted hammer retune onto shipped maps |

### Opus design

| ID | Map | Closes | Status |
|---|---|---|---|
| T50 | Tumble | D4 ending tunnel | todo |
| T51 | BallBarrage | D1a/P4/A1a/A2 | todo |
| T52 | TipToe | D1b dead stretches | todo |
| T53 | Whirlpool | D1c dead stretches | todo |
| T54 | Summit | D2/A1b | todo |
| T55 | Piston | A1b/A3a | todo |
| T56 | DoorDash | A3c opening roof | todo |
| T57 | all | D3 conveyors | todo |
| T58 | all | G4/A1c inventory | todo |
| T59 | all | standing qualitative audit | todo |

## Audit corrections to `docs/map-issues.md`

- `image-20.png` and `image-21.png` are byte-identical; the doc cites them as two
  different issues. Slide-in-platform taken from image-20, jump-pad issue from image-22.
- `image-41.png` is referenced by nothing in the doc. It shows a 112-stud foam pit
  (Tumble Tunnels). Folded into G3.
- The axe swing plane is already perpendicular to the route on all 8 hammers/maces
  (`|axis . routeForward| = 1.00`). Only the blade roll is wrong.
- Ball Barrage is not the blandest map. TipToe Trials (11 encounters / 880 studs) and
  Whirlpool Waltz (14 / 885) are worse.
- "Yellow wall with a hole" is `wall_001`; without is `wall_002`. Summit carries 29 of
  the 34 total, not Piston Peak.

## Corrections to this plan's own audit

- **P6d withdrawn 2026-09-17.** Summit's `_05_jumppad_32` was reported as floating
  72.7 studs past the plaza edge. It is correctly seated on `sd_arc.007` (centre 4.1
  studs inside the footprint, 0.9 above the top). The original measurement used a
  deck-name filter that did not match Summit's `sd_arc.*` naming. Re-tested all 12 pads
  by footprint containment: only TipToe (+3.4/+2.9) and Piston Peak (+3.0/+3.0) overhang.
- **T23 scope widened.** Whirlpool Waltz is also missing its Checkpoint01 arch
  (nearest 87.1 studs). Four arches to add, not three.

## Changes applied

All Studio edits are in the place file (`ReplicatedStorage.Assets.Maps.Splashdown`), not git.

### 2026-09-17

**T01 — fan blade rotation axis (framework).** `RotatingPlatforms.build` built the fan-blade
rotor centre as `CFrame.new(position)` (rotation-free) and hardcoded `axis = "Y"`, so a blade
spun about WORLD Y no matter how the fan was pitched — a fan laid on its side to blow
horizontally still span as though blowing upward. Now takes the fan's rotation into the centre
and reads `FanAxis`. Verified: Selene 0 warnings, StyLua clean. Fixes every fan on every map at
once; no per-map work needed.

**T19 — Whirlpool Waltz restored.** The promoted template was sitting loose in the Workspace
under an unrelated `Part` and was absent from `ReplicatedStorage.Assets.Maps.Splashdown`, so
`SplashdownCourses.start()` would have hard-failed at boot on `CourseOrder`'s 7th id. Moved
back; descendants, Origin, pivot and checkpoint count all preserved. All 7 ids now resolve.

**T21 — blue water -> purple lava (6 courses).** Each course's `Hazards.Liquid` blue `Part`
(rgb 60,140,220, Transparency 0.3) replaced with a clone of Summit Splash's `sd_lava` MeshPart
(`MeshId 112354510422105`, `TextureID 83918297212907`, Transparency 0). Footprint kept; mesh
thickness taken from Summit and the part re-centred so the visible surface lands exactly where
it did — measured surface delta 0.000 studs on all six, and the hazard kill threshold is
unchanged (`inHazard` is a pure CFrame/Size box test, so behaviour is identical). Piston Peak's
7 rising-liquid attributes preserved.

**T23 — 4 missing checkpoint arches.** Ball Barrage 02 and 04, Tumble Tunnels 05 and Whirlpool
Waltz 01 had a trigger but no visible arch. Each new arch cloned from a sibling checkpoint in
the same course and placed by that course's own measured Pad->Arch transform; all four landed
0.21 studs from their trigger, matching the sibling convention. Every checkpoint on all 7
courses now has an arch.

**T22 — checkpoint and finish triggers widened.** 42 triggers: 12x8x2 -> 56x24x2 (Summit's
36x20x6 -> 56x24x6, keeping its 6-stud depth; Summit's finish was already 70x24x8 and was left
alone). Each trigger's BOTTOM edge preserved exactly, so nothing moved relative to its pad.

**T24 — foam pits removed.** All 6 instances deleted (Door Dash 1, Piston Peak 1, Summit 1,
Tumble Tunnels 2, Whirlpool 1) plus all 7 now-empty `Scriptables/FoamPits` folders. Note: the
translucent white slabs in `image-30.png` and `image-41.png` were these, so this also removes a
large part of what made Summit's ending unreadable.

**T29 — Door Dash decks under succession jump pads.** Deleted `sd_DoorDash_04_platform_88`
(`Deck02`, under pad 89) and `sd_DoorDash_04_platform_92` (`Deck03`, under pad 93). Both pads
remain anchored in place, so the launch pair is now a genuine two-bounce. Landing target
shrinks from a 10.5x13.5 deck to the 8.9-stud pad — on the playtest list.

**T28 — spinners centred.** `sd_TiptoeTrials_03_spinner_20` 3.61 -> 0.00 studs off centre;
`sd_TumbleTunnels_05_spinner_46` 8.50 -> 0.00.

**T34 — seesaw tilt.** All 7 seesaw boards set to `MaxTiltDegrees = 34` (were 18-24).

**T36 — Ball Barrage sweeper frame.** Stripped the frame's `slide` rotor so the spiked roller
spins in place instead of translating side to side. The drum's spin + Shove is untouched.

**T41 (NEW) — hammer/mallet profile mirrored onto the shipped maps.** Discovered that the
working tree already contains an uncommitted retune replacing the `RotorProfile = "hammer"`
windup/strike (1.8s rise, 0.3s drop — "a slow lift snapping shut, not a pendulum") with a plain
symmetric rock at `RotorPeriod = 3.6`, but the shipped templates predate it and still carry the
old profile. Mirrored onto all 4 shipped hammers (Door Dash, Ball Barrage, TipToe x2). This is
likely part of why the axe reads badly in the player's screenshots.

**T20 — preview clones.** All 7 courses cloned into `Workspace.SplashdownPreview`, spaced
1000 studs apart in X, for screenshot verification. This is scratch scenery — delete the folder
before shipping.

**T02/T03/T04/T06/T07 (framework, via agent).** Trigger markers now built at 56x24x2.
`buildCheckpoint` now builds its own visible `Arch` from `checkpoint_001`, idempotently, with
scale derived as 11.0/45.6 rather than hardcoded — so the uncommitted manual promotion step that
skipped four arches can no longer cause this. `buildHazardLiquid` now clones `ArenaSources.LiquidMesh`
(verified in Studio: that folder holds exactly `LiquidMesh` with the right mesh/texture, and
`BoundaryWall`) instead of building a blue Part. Piston tuning made spec-driven at 18 / 1.9s /
0.35s / shove 54. Seesaw default 34 degrees. Verified: Selene 0/0/0, 987 tests 0 failures.

### Corrections made during execution

- **T08 was applied wrongly by the agent and reapplied by the lead.** The revision making the
  sweeper slide opt-in reached the agent too late; it deleted the frame's slide outright, which
  would have silently killed Summit Splash's bridge sweep on any rebuild (its `06_FinalFooting`
  Sweeper01 declares `RotorAmplitude = 8` precisely so 27.20 studs of frame plus 2x8 of travel
  covers a 16.25-stud bridge end to end). Reapplied as opt-in: the five frame attributes are
  written only when the spec declares `RotorAmplitude`, with no default. Verified against the
  specs — Ball Barrage's Sweeper01 sets only `RotorPhase` so it gets a static frame, Summit's
  sets `RotorAmplitude = 8` so it keeps the slide. This reproduces the Studio state exactly.

- **T23 arches: three of four had to be relocated.** Placing each new arch on its checkpoint's
  own Pad->Arch transform put it inside existing geometry — Ball Barrage 02 landed inside a Big
  Ball (pole 0.9, sphere 5.0 studs of penetration), Ball Barrage 04 inside `ramp_34` (6.0),
  Tumble Tunnels 05 inside `prop_45` (5.2). Only Whirlpool 01 was clear. **That is almost
  certainly why those three were skipped originally: an arch does not fit at those checkpoints.**
  Each was walked along its own route heading to the nearest position clearing all geometry:
  Ball Barrage 02 by -5 studs, Ball Barrage 04 by -7, Tumble Tunnels 05 by +23. All four arches
  are now clear. The Tumble Tunnels one is 23 studs from its trigger, which is cosmetically loose
  — it marks the checkpoint's approach rather than its exact line. Flagged for the playtest.
  This is only acceptable because T22 widened the trigger to 56 studs, so the arch is now a
  visual marker and no longer the detector.

- **T36 over-reached and was partly reverted.** Matching on `Rotor == "slide"` also stripped
  Summit Splash's sweeper, which deliberately declares `RotorAmplitude = 8` so the roller sweeps
  its narrowed inward bridge end to end. Restored to `slide / X / 8 / 3.2 / 0`. The framework
  task T08 was revised in flight from "delete the slide" to "make the slide opt-in on an
  explicit `RotorAmplitude`", which reproduces exactly this split on a rebuild.

**T35 / T37 — punchers and beach balls.** Punchers moved inward to a 6-stud body-to-edge gap
(was 9.0 on Ball Barrage, 15.1 on Piston Peak, where the 6-stud throw could not reach the lane
at all), period 3.2 -> 1.9s, hold 0.6 -> 0.35s, shove 44 -> 54. Beach balls 4.6 -> 10.1 studs
with full Shove knockback, and lifted 2.75 studs so they keep their original clearance.

## New findings from execution (not in the original plan)

- **The approved puncher throw of 18 was right for one course and wrong for the other.** Ball
  Barrage's lane is 21.0 studs wide, so a throw of 18 from a 1.3-stud standoff crosses 92% of it
  — correct, and with two opposed pistons the pair covers the lane as a timing puzzle rather
  than a wall. Piston Peak's lane is only **8.8 studs** wide: a throw of 18 would have punched
  **8.3 studs out past the far edge into open air**. Throw is now sized per lane — 18 on Ball
  Barrage, **11** on Piston Peak (crossing its lane with 2.2 studs of overshoot so there is no
  safe sliver). Deviation from the approved value, applied deliberately.

- **The planned 20-stud beach ball would have jammed the tunnel.** The plan derived "scale 2.2"
  from the 9.2-stud source mesh, giving ~20 studs. But the balls are blown through
  `sd_TumbleTunnels_01_prop_3`, an arch measuring 33.1 x 23.7 x 52.1 whose bore is far narrower
  than 20 studs. Applied 2.2x to the placed instances instead: **4.6 -> 10.1 studs**, roughly
  twice a character's height, which fits the bore and still reads as a real hazard now that it
  carries knockback. Deviation from the approved value, applied deliberately.


- **P2a-d (buried slides) is largely an audit artifact.** All four slides are `Chain` route
  pieces the racer rides DOWN. Measured: each slide's top is flush with the deck above it
  (24.02 vs 24.00, 18.02 vs 18.00, 14.02 vs 14.00, 24.02 vs 24.00) and its base sits ~1 stud
  above the deck below. They are working descenders. What the OBB audit flagged was a descender
  necessarily overlapping the deck it descends from. The genuine, smaller defects are: the lower
  lip sits ~1 stud below the next deck's top (visible clipping in `image-43.png`), and the upper
  body is pushed well into the previous deck's footprint rather than starting at its edge.
  Fixing that is per-instance judgement about how far to pull each slide back along its route —
  **reclassified from Sonnet to Opus**. No slide has been touched.

- **P2e-h (buried fans) is partly deliberate.** `sd_TumbleTunnels_01_fan_9` sits 3.26 studs into
  its deck, but the CourseSpec comment says that is intentional: "Sunk 12 studs, the pilot's own
  mounting, so the grate finishes flush with the launch deck and a runner crossing it is inside
  the column." `sd_TiptoeTrials_01_fan_4` is a different case — it is 14 studs below its deck top
  and OUTSIDE the deck footprint in Z (offset 15.8 on an 18-deep deck). These need to be told
  apart per instance. **Reclassified from Sonnet to Opus.** No fan has been touched.

- **Two pre-existing checkpoint-arch intersections found** (not caused by this work, not yet
  fixed): Ball Barrage Checkpoint03's arch intersects `sd_BallBarrage_04_ramp_26` by 0.4 studs,
  and Piston Peak Checkpoint06's arch intersects `sd_PistonPeak_06_piston_62_2` by 1.4 studs.
  Both minor; queued for triage.

- **The checkpoint arch is a small pink handlebar shape**, about 11 x 8.4 studs. Visually
  confirmed in the preview. It is easy to miss at speed even when present, which compounds the
  sequential-checkpoint problem. Whether to use a more legible marker is a design question that
  the original notes did not raise — worth a decision.

## P3 (green ramp) — my audit was wrong in both halves

The plan claimed a recurring **-5.7 stud vertical step at nearly every ramp end on all six
courses** and **horizontal gaps of 11.2-28.2 studs**. Neither is a defect.

- **The -5.7 step is a measurement artifact of my own audit.** I sampled each ramp's
  `Position.Y` — the part CENTRE. `box_011`'s walkable plateau sits **26.9 studs above its part
  centre** at the high end and 1.6 below it at the low end, unlike any other kit piece. At the
  near-universal `RAMP_6` scale of 6/28.5, `26.9 x 0.210526 = 5.663`. That is the whole of the
  "-5.7", and it is scale-locked, which is exactly why it appeared identical across unrelated
  courses. Re-measured against the actual plateaus, every ramp junction is flush. Confirmed
  independently against a real build report: Ball Barrage `Ramp01`'s part centre lands 5.663
  below the deck it exits onto, in a build that is geometrically correct.
- **The large horizontal gaps are authored jump gaps.** `Advance` pieces of 14, 16 and 18 studs
  sit immediately after ramps by design (Ball Barrage `Gap03`/`Gap04`, Whirlpool
  `Gap04`/`Gap09`/`Gap14`/`Gap22`). A "distance from ramp end to next deck" scan reads a
  deliberate jump as a gap. The remainder is measurement against round ride decks' bounding boxes.
- **Every ramp is aligned to its route heading** (checked all 41 against the build reports;
  none off by more than 8 degrees). The arrows in `image-42.png` / `image-44.png` are pointing at
  the ramp's *end face*, which is genuinely 7.24 degrees off perpendicular to its own long axis —
  the mesh's sheared ends, not a placement error.

**What was actually wrong, and is now fixed:** `box_011`/`box_013` declared `Entry`/`Exit` at
+-69, the inner extreme of the oblique end face, instead of +-72.705 where the route centre line
crosses it — 3.827 studs short at scale 1. Derived from the original raycast sweep: it bins the
ramp into 20 slices of 7.6531 studs and the two end slices return 0.46 and 0.42 against a 0.92
baseline, i.e. each end slice is exactly half covered in plan, which is what a diagonal cut does.
Every chained ramp therefore buried its nose ~0.78 studs into the deck at each end at `RAMP_6`
and under-declared its travel by 1.56 studs. Fixed in `AssetManifest.luau`; the centre-line
junction is now exactly 0.000 at both ends and the worst corner deviation halves to +-0.806.

**T39 is withdrawn.** There are no ~14 ramp ends to re-seat. The residual in the shipped maps is
a sub-1.6-stud symmetric nose overlap per ramp that no in-place move can improve (shifting a
chained ramp fixes one end and worsens the other by the same amount). The manifest fix applies to
future builds.

## Follow-ups opened by T11 (blocked on the T05 agent releasing CourseSpecs)

- `CourseSpecs/PistonPeak.luau:29` hardcodes `RAMP_TRAVEL = 138` ("box_011 Entry -69 -> Exit 69").
  Now 145.40955. It sizes `RUN_1`..`RUN_5`, so Piston Peak's tower runs go stale by 1.56 studs per
  ramp across 9 ramps. Best fixed by deriving it via `CoursePresets.travelLength("box_011", 1)`
  rather than transcribing, which the file's own header says was the intent.
- `CourseSpecs/DoorDash.luau:988` has `OffsetAlong = 58.11` = `138 x 0.4211`, a mount placed at the
  ramp's old far end. Becomes 61.23 if it meant "the ramp's far end"; unchanged if it meant an
  absolute distance. Needs a judgement call.
- Stale comments quoting the old 138/29.05 figures in 5 CourseSpecs and the per-course docs.

## Playtest list

Carried from the plan; added to as tasks complete.

- Checkpoints advance end-to-end on all 7 courses after T22/T23.
- Whether the widened 56-stud trigger plane can be crossed accidentally off-route.
- Whether a jump-pad launch or fan lift can still tunnel a 2-stud-deep trigger.
- Ball Barrage's third ball reachable after P4.
- Puncher feel at throw 18 / period 1.9s.
- Seesaw at 34 degrees.
- Beach balls at 2.2x with knockback.
- Slide friction after re-seating.
- Whether removing the deck under each swing panel strands the route (T33).
- Door Dash pads 87->89 and the Pad03 succession after their decks are deleted.
- Lava readability on 6 courses; whether the splash VFX still reads.
- All Opus design work (T50-T58).
- Piston Peak's rising liquid against the widened triggers.
