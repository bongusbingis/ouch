# Gate 1 — proposed scope and approval

Discovery is complete in [00-findings.md](00-findings.md) and [01-asset-inventory.md](01-asset-inventory.md). **No kit or course implementation has begun.** Numbers below are intended coverage, not measured performance promises.

## Preserve and stage

Keep every existing source course and recipe. Preserve the seven parked models in an approved Deprecated archive; do not delete them. Keep the existing registration until a validated replacement set can be swapped safely. First establish an authored arena asset snapshot/manifest: the current template folder is empty and the repo lacks the base arena place needed by the normal build script. CrossCurrent's missing template remains an explicit failure, not a silently skipped test.

Build a declarative spec + socket/asset manifest adapter around the existing author conventions. New IDs never overwrite legacy IDs. Specs own numbered beats, palette, asset scales, entry/exit sockets, support mounts, hazard attributes, gates and route nodes; generated runtime markers retain the mode's contract. No gameplay UI work, new meshes or name-list additions.

## Phase 1 kit sequence → Gate 2

| Work package | Implementation boundary | Required proof |
|---|---|---|
| Rotor composition / carrying | Parent-local transform tree, unambiguous nearest motion owner, course-only authoritative rider option; canonical Origin RotationSpeed=0 | Nested spin+slide, hammer on hub, spin/slide/rock riders; arena-regression defaults |
| Attribute adapters / existing bugs | Per-pad LaunchSpeed; explicit name-free selectors for JumpPad/FoamPit/BeachBall and legacy presets; strict attributes/axes; Door row/index validation | Two independent course clones, no arena-name matches, destroy/reclone cleanup; 3/4/5-door layouts and configurable breakables |
| Beach balls + airflow | Multiple server-owned balls; directional, visible fan volume as an opt-in path; shared anchored conveyor motion | Two balls simultaneously, rotated fans, belt transport, reset at420 /−80, no client authority |
| BigBall | Sphere cap-angle landing bounce with float; side roll-off; bob composed with Rotor | Top/edge/side contacts, spam cooldown/guard, three-ball course segment and reset |
| Sweepers / pendulums / hammer / piston presets | Existing Rotor+Shove; deterministic asymmetric rock and extend/hold/retract profiles rather than duplicate motion loops | Tip speed/contact envelope, blocked cycle fraction, phase cascades, cooldown/re-entry and measured edge reach |
| Conveyor | Signed speed on explicitly authored chevron axis; anchored AssemblyLinearVelocity | Up/down/sideways belts, player and ball physics, slope/friction trials |
| FallingTile | Authoritative timed collision/drop/restore; client shake only | Trigger race, multiple riders, checkpoint recovery; no permanent critical-route loss |
| Seesaw | Deterministic rider moment / clamped tilt, return-to-level, server carry | One/two/30 riders, symmetry, empty recovery, join/leave |
| Gap platform / carousel presets | Rotor+Carries with verified mesh holes; optional RotorAccel only if low risk | No OBB “solid hole” shoves, phase-aware traversal and landing |
| RisingLiquid config helper | Adapt existing Summit 20 s delay /60 studs over140 s; optional monotone pauses | Same Summit trajectory/reset, flood-spawn regression; reusable by Piston Peak |
| Checkpoints | Reuse existing system and markers, **no new checkpoint kit** | Ordered credit, fall respawn, flooded-pad fallback |

Each package: additive commented tuning/Attributes, server-authoritative gameplay, cosmetic client feedback, smoke/cleanup/regression tests, and one usage paragraph in `02-kits.md`. No existing shared values change without another explicit gate note. Rotors remain the implementation for ordinary hammer/mace/sweeper shapes; don't multiply modules just to inflate variety counts.

Deliver commits by kit plus tests/docs, then **stop at Gate 2**.

## Course set after Gate 2

These are proposed two-word display names with fresh stable IDs. Each has a start for30, 6–7 numbered beats and a finish. Six actual runtime kits minimum; preset counts reported separately. Detail specs/sketches/Loophole answers/tuning are written before each build and calibrated from the probes, not guessed.

| Course | Headline and draft dominant-beat sequence | Actual kit coverage planned |
|---|---|---|
| **Ball Barrage** (pilot) | Counter-belt ride → three staggered Big Balls → piston ledge timing → guided fan/pad launch past a mace gate → asymmetric hammer climax → short descending sprint | Conveyor, BigBall, RotorBump, Fan, JumpPad, Bumper (forced belt-feed contact) |
| **Whirlpool Waltz** | Arch-ramp descent → gapped pizza/carousel ride → door choke crowd → dumbbell timing bridge → disc/pad precision climax → short belt sprint to hub | RotorBump, Door, JumpPad, Fan, Bumper, Conveyor; carrying on all ride platforms |
| **Door Dash** | Three differently configured door rows → slide descent → counter-belt ride → pad launch → falling-tile/hammer landing climax → short readable cross-spinner sprint | Door, Conveyor, JumpPad, FallingTile, RotorBump, Bumper |
| **Tumble Tunnels** | Ball tunnel crowd → seesaw ride → arch stair climb → bumper-mouth precision → fan launch → opposing conveyor tunnel climax → short descending exit | BeachBall, Fan, Conveyor, Seesaw, Bumper, FoamPit; foam is a measured ≥5 s penalty lane |
| **Tiptoe Trials** | Controlled fan/pad launch → seesaw ride → door crowd choke → stepped climb → falling-tile island climax with telegraphed hammer landings → short belt sprint | Fan, JumpPad, Seesaw, Door, FallingTile, RotorBump, Conveyor |
| **Piston Peak** | Zigzag climb with belt support → piston timing → seesaw ride → forced bumper precision → fan/pad launch → rolling-log/hammer climax → short final ramp to arch | Conveyor, RotorBump, Seesaw, Bumper, Fan, JumpPad; rising liquid only here among new courses |

Draft sequences are **mechanics**, not final layouts. Families may recur with a different mechanic, but no dominant mechanic repeats or occupies adjacent beats. Each course has ≥4 families. Secondary hazards reinforce that beat's dominant task. Palette follows beat transitions, not random asset colours. Climax is second-to-last; final is short/readable and easier.

Big Balls appear nowhere else. Falling-tile paths use at most three consecutive tiles before a different encounter; they must still read as one route family. Four/five consecutive balls, eleven discs and repeated six-panel corridors are explicitly rejected. Disc diameter variants use existing meshes and uniform scaling only. Set coverage includes both bumpers, both bar/cross-spinner silhouettes, rollers, mace, mallet/hammer variants, punch piston, carousel, pizza gaps, disc variants, seesaw, SwingPanel, fan and each usable pad variant. Unidentified assets must be resolved before placing them; inventory flags are not permission to invent replacements.

**Gate 3:** Build only Ball Barrage, deliver its course doc, fixed-camera screenshots, automated QA and scripted plus interactive clear-time evidence. Stop and calibrate with the user before building the other five.

## Summit hardening

Preserve route and rising-liquid schedule. Add measured anti-skip enclosure, force bumper contact only where fair, tune **course-specific attributes**, and strengthen sparse beats with one or two unused kit assets. Audit every existing encounter for full width, contact speed, escape distance and all five loophole questions. Preserve the original Summit source for comparison.

## Verification plan

Luau course-QA module: bounds/spawns/finish; strict attributes; intended-route and time/phase-aware movement graph; beat cut sets; gap audit; support/seam/intersection tolerances; lane coverage/open-space/same-type runs; kit/family distribution and set-wide coverage; part/instance/clone/build timings. Export machine-readable evidence and a human QA report.

Every final course, including Summit: top-down + three-quarter fixed cameras; compare explicitly with bad references1/9/10/11; route-driving Humanoid trials (times, falls, hit rate); Studio keyboard-controlled run; expected-fall/timing/fairness checklist. Teleports between test cases are allowed, never counted as a traversal. Never mark estimated pars or an unrun manual checklist as passed.

## Approval requested

1. Approve the additive kit plan and six proposed course headlines, with Ball Barrage as the pilot?
2. Approve retaining the parked courses as Deprecated and disabling their old registrations only during a validated replacement swap?
3. Approve the compatibility decisions: positive respawn for critical falling tiles; three-ball pilot; timed jumping through a hazard is allowed but bypassing its gate is not; existing lifecycle folders retained through the builder adapter; opt-in server-authoritative course carry/ball behaviour; uniform scaled disc variants?

Open technical limits remain explicit in the findings: authored base place missing from repo, CrossCurrent absent, desktop helper unavailable (Studio input tools are an alternative), no new course timings yet. If any decision is rejected, revise specs before implementation.

**WAITING FOR GATE 1 APPROVAL.**
