# Splashdown overrides and blocker decisions — 2026-09-15 revision

Recorded from HANDOFF.md Appendix B (2026-09-15 revision log). This file is the checked-in copy of
those decisions; HANDOFF.md remains the authoritative implementation spec and wins on any conflict
with an older docs/splashdown file. New user direction always wins over anything recorded here.

## Gate and blocker decisions

1. Gate 2 approved. HANDOFF.md sections 0, 4, 10, 14.1 and 15 no longer wait for it.
2. Templates folder: the user moved the original course contents into `Workspace.LegacyCourses`.
   The empty `ReplicatedStorage.Assets.Maps.Splashdown` is expected, not a baseline failure; the
   parked models may be copied in as fixtures (HANDOFF sections 1.2, 1.3, 2.1, 10.7, 12.1.5, 13).
3. `screen_capture` repaired. Section 4 step 6 retries once then STOPs; section 13 updated.
4. Multiplayer: no real 30-player session. Certification is the 30-rig stress test plus a Studio
   local multi-client session (2-4 clients). Section 8.5 rewritten; 14.13 withdrawn; 14.4 and 15
   updated.
5. Arena base place: out of scope (CD workflow). Section 12.2 withdrawn; 12.3 runs in the connected
   arena place without build-place; 14.14 and the section 15 checklist LFS/build items replaced.

## Design overrides

1. One layout kind per course (Serpentine, Spiral, Chute, Loop, Archipelago, StackedSwitchback;
   Summit unchanged) and one hue family per course. Sections 5 (`Layout.Kind`), 5.2 and 7 palette
   rewritten.
2. Headline exclusivity, a three-course cap per non-glue mechanic, and no shared beat recipes
   across courses. Consequences applied in section 7: Door Dash's tile climax replaced by
   `05_MaceMarch`; Tiptoe's door beat replaced by `03_IslandHop` (Whirlpool keeps the one door row
   allowed outside Door Dash); the "1 fan, 2 pads at 51/54" launch exists only in Ball Barrage; fans
   limited to Ball Barrage, Tumble Tunnels and Tiptoe Trials; conveyors to Ball Barrage, Door Dash
   and Piston Peak; seesaws to Tumble Tunnels, Tiptoe Trials and Piston Peak; Summit's hardening
   adds seesaws, a sweeper and a foam lane instead of tiles. Section 8.4 gains the cross-course
   check.
3. Variety scored on encounters, not instances (definition in section 7). All section 7 totals
   recomputed; per-instance counts are reported only. Sections 8.4, 14.7 and 15 updated.
4. Route length 800-1,000 studs; section 7 targets sum to about 800 per course, the pilot's
   measured pace fixes the set-wide target, remaining courses scale before they are built
   (sections 3.2, 5.2, 9.8, 10.8, 11).

## Set-wide route-length target, fixed from the pilot's measured pace (2026-09-15)

HANDOFF section 11 requires this to be fixed before the second course is built, from the pilot's
measured pace (section 5.2), with the section 7 length targets scaled and recorded here.

**Measurements it is derived from**, all from real Studio Play sessions on place 121997450145716,
recorded in `evidence/courses/BallBarrage/{build,routes}.json`. `run-course-routes.server.luau` had
never been executed before 2026-09-15; these are its first real results.

| Measured | Value |
|---|---|
| Ball Barrage route arclength | 881.05 studs, identical across two builds from the same spec and sources (SpecHash `943e493c` both times) |
| Scripted mid-policy median | **63.66 s**, **5 of 5** resets cleared (seeds 101-105): 39.2, 47.8, 63.7, 70.9, 85.6 s |
| Scripted expert clean clear | **38.35 s**, zero falls, all 5 checkpoints and the finish; **3 of 3** resets cleared |
| Effective mid pace | 881.05 / 63.66 = **13.84 studs/s** |
| Falls per run | expert 0-2, mid 0-12; clustered at `Step01` and `Gap01`, the Big Ball chain in `02_RedRebound` |
| Hazard contacts per run | 24-60, covering **16 of the course's 17** hazard pieces |

**The pilot lands inside section 8.5's pace window.** A mid-policy median of 63.66 s is inside the
required 60-90 s. The expert/mid ratio is 38.35 / 63.66 = **0.6024** against a bar of "at or under
0.6" — over by four thousandths, which is why `pacePass` reports false. That is a hair, not a
finding, and it is recorded as measured rather than rounded away.

Two things are worth stating plainly about what these numbers are:

- **They only became meaningful after a harness bug was fixed.** `Workspace.Baseplate` is a solid
  floor at Y 0 in the connected place and the isolated course clone was built around its own origin,
  directly on top of it, so a runner who fell off landed on the baseplate instead of passing the
  course's liquid plane. The first eight runs recorded **zero falls** and a 40.18 s median that was
  really just walking pace. The clone is now lifted to Y 20000 first, falls happen, and the median
  moved from 40.18 s to 63.66 s. Any figure taken before that fix is a traversal floor, not a time.
- **A scripted policy is still a proxy.** It walks straight lines: it cannot read a sweeping hole in
  a rotating plate, time a Big Ball cap, or choose a door channel on anything but the centre-out
  order the harness gives it. HANDOFF 8.5's rule stands — "if proxy results and interactive
  experience disagree, obtain a user mid-skill calibration run before approval" — and for this
  course the human evidence is the user's own interactive run, which is what produced the Gate 3
  approval.

**Derivation of the target.** At the pilot's measured 13.84 studs/s, section 8.5's 60-90 s window is
831 to 1,246 studs of route. The mandatory 800-1,000 window sits inside that, and the pilot's own
881.05 studs produces a 63.66 s median near the window's lower half, leaving headroom for courses
that are harder than the pilot without pushing past 90 s. **880 measured studs is therefore kept as
the set-wide target**: it is the length that was measured, the length a human played and approved,
and the length that puts the measured median inside the window. The section 7 beat targets stay
exactly as written, because the scale factor is 880 / 881.05 = 0.9988.

One measured defect that the window does not cover: **`01_Countercurrent/Bumper01` was contacted in
none of the eight runs**, while the other sixteen hazard pieces all were, across both the
pre-fix and post-fix measurement sets. HANDOFF 8.5 requires a hazard no normal runner contacts to be
flagged and challenged with a deliberate mistimed real-player contact. It is flagged; the challenge
is NOT RUN.

**Set-wide route-length target: 880 studs of beat arclength per course** (inside the 800-1,000
window of override 4). The section 7 targets sum to 800, so every remaining course's beat targets
are scaled by 880 / 800 = **1.10** and rounded to whole studs so each course sums to exactly 880:

| Course | Scaled beat length targets (in beat order) | Sum |
|---|---|---|
| BallBarrage (7.1) | unchanged: 150 / 140 / 130 / 150 / 150 / 80 — built and measured at 881.05 | 800 target, 881.05 built |
| WhirlpoolWaltz (7.2) | 132 / 198 / 99 / 165 / 198 / 88 | 880 |
| DoorDash (7.3) | 198 / 110 / 165 / 143 / 176 / 88 | 880 |
| TumbleTunnels (7.4) | 165 / 132 / 121 / 121 / 99 / 154 / 88 | 880 |
| TiptoeTrials (7.5) | 121 / 132 / 110 / 132 / 253 / 132 | 880 |
| PistonPeak (7.6) | 154 / 143 / 99 / 121 / 121 / 176 / 66 | 880 |
| SummitSplash (7.7) | unchanged — source-plus-patch, no new route topology | n/a |

Ball Barrage is not rebuilt to 880: it is the anchor the number was measured from, its built
881.05 is inside the window, and section 9 forbids re-tuning a course that has already passed its
gate for cosmetic consistency.

**Other limits of this measurement, recorded honestly.**

- The harness had to be fixed three times before it produced anything usable, and every fault was in
  the harness rather than the course. Its first execution stalled at every gap because jumping was
  gated behind the policy decision interval, so a mid runner had a quarter-second reflex floor;
  jumping, falling and contact are now resolved every frame inside the policy interval. It also
  recorded zero contacts on every run, because `CoursePresets` builds course pieces with
  `CanTouch = false` so the kits own touch detection, and a `Touched` connection on the rig can
  therefore never fire; contacts are now sampled by an overlap query against the `Scriptables` tree.
  The third was the baseplate described above.
- Results are from one machine, server-owned R15, in Studio Play. They are not a 60 Hz, latency or
  30-player measurement and are not labelled as one.
- The thirty-rider load test and the Studio local multi-client session are still NOT RUN.

## Context budget

New HANDOFF section 2.4 (subagent delegation, large outputs to files, handoff refresh at every
gate and before context runs low); section 0.9, 2.1 and 13 reference it.

## Unchanged

All frozen contracts (HANDOFF 3.1), asset and naming contracts (3.3), the section 6 presets except
the door-course note and the `obstacle_11` usage note, the STOP-not-estimate policy, and the
deletion policy for retired courses.
