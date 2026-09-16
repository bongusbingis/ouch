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

## Context budget

New HANDOFF section 2.4 (subagent delegation, large outputs to files, handoff refresh at every
gate and before context runs low); section 0.9, 2.1 and 13 reference it.

## Unchanged

All frozen contracts (HANDOFF 3.1), asset and naming contracts (3.3), the section 6 presets except
the door-course note and the `obstacle_11` usage note, the STOP-not-estimate policy, and the
deletion policy for retired courses.
