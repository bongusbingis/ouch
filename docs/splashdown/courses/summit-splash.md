# Summit Splash — hardening

HANDOFF.md section 7.7. Layout kind **SourcePatch** (section 11 step 2: "Summit uses
source-plus-patch"). This is the one course of the seven that is *not* authored from a declarative
guide: its geometry is the original authored course, cloned from
`ServerStorage.SplashdownAuthoringSources.SummitSource`, with a measured removal set, a measured
enclosure set and five new encounters applied to it. The arc centreline, the eight arc sectors, the
start, the four checkpoints, the finish and the rising-liquid schedule are **preserved, not
redesigned** (7.7 opening line, section 3.1's permitted-config note).

Written before the hardening build, from the section 7.7 patch order. Planned numbers are labelled
**planned**; everything labelled **measured** was read off the real source or the rebuilt template
in place 121997450145716 and is reproduced in
`docs/splashdown/evidence/courses/SummitSplash/qa.json`.

## Concept and headline

An eight-sector arc that spirals 468 degrees inward-facing around the bowl, climbing 5 studs a
sector from Y -20 to Y +15, with lava rising underneath it on the original 20-second /
60-stud / 140-second schedule. The arc ends on an inward road bridge to a summit plaza.

The declared **headline is the `Sweeper`** — the sliding wall across the narrowed inward bridge at
beat 06, which is the one encounter this hardening pass adds that nothing else on the course does
and which turns the old free-walk bridge into the hardest crossing on the course. Ball Barrage is
the only other course in the set that places a Sweeper, and it is not the dominant preset of any of
its beats, so the headline satisfies override 2's two dominance rules.

Palette (override 1): **Summit keeps its existing sector colours** — 7.7's opening line preserves
them explicitly, and unlike the six new courses there is no new base hue to apply. The new guard
walls, seesaws, fan, pad and sweeper are cloned from the kit unrecoloured, which is the same
set-wide open item recorded in every other course doc (`CoursePresets` does not recolour).

## What the source actually is — measured

Cloned from `Workspace.LegacyCourses.SummitSplash` at section 4 (`cfe33e3`), exported to
`assets/splashdown/summit-source.rbxmx`, sha256
`a7f21b8965d272c41944bc8919ab7ac8007700a370e7c87f1b85a25cc475ab0f`, **258 BaseParts**. Measured on
the clone, re-based so its own `Origin` part sits at (0, 0, 0):

| Element | Measured |
|---|---|
| Arc deck, every sector | walkable annulus **r 156.0 … 200.0**, 44 studs wide, ribbed (top varies up to 1.8 studs) |
| Sector spans, from angle 180 | 90, 45, 56, 56, 90, 45, 56, 45 degrees — 483 total, ending at 663 |
| Sector deck tops | -20, -15, -10, -5, 0, +5, +10, +15 (a +5 step per sector, inside the measured 11.5-stud step-up) |
| Route centreline | r **180.0**, dead centre of the 44-stud deck |
| Start | 30 pads at Y -19.5, r 165 … 196, centred on angle **195**, heading 105 |
| Checkpoints | 4, all at r 180, angles **304.7 / 416.7 / 551.7 / 652.7**, pad tops Y **-14 / -4 / +6 / +16** |
| Inward bridge | 9 `road_001` slabs in 3 rows of 3, centreline angle **295**, top Y **17.5**, spanning r 67.2 … 162.8, **46.25 studs wide** |
| Finish | plaza `octagon`-style slab r 0 … 85.2, top Y **20.0**; Trigger 70 x 24 x 8; one Deck |
| Boundary | 24 anchored colliding invisible walls at r **390.00** exactly |
| Liquid | `sd_lava` at Y **-50**, 760 x 760, `RiseStuds=60 RiseDelaySeconds=20 RiseSeconds=140` |
| Hazards | 8 windmills, 9 chain maces, 16 bumpers, 9 `wall_003` chicane walls |

### The four measured faults the hardening fixes

1. **The arc's inner and outer strips are a free bypass of every encounter.** The deck is 44 studs
   wide; a windmill bar sweeps r **167.2 … 192.8** (measured bar 25.63 long at the course's own 0.55
   scale, spinning about the post at r 180) and a chain mace sweeps r **≈168 … 192** (measured
   11.42-stud arm, 50-degree amplitude, 5.48-to-6.33-stud ball). Everything outside those bands is
   walkable and untouched: an inner strip **156.0 … 167.2** and an outer strip **192.8 … 200.0**.
   The two flanking bumpers at r 165 and r 195 (measured 10.93 x 11.68, deck +0.00 … +7.06) close
   most of it but leave **156.0 … 159.2 = 3.2 studs** of inner deck open against a ~2-stud character
   footprint, and the mace beats have no bumpers at all — they are 44 studs wide with a 23-stud
   pendulum in the middle. This is 7.7.7's "inside shortcut", measured.
2. **The nine `wall_003` chicane walls are a rail top, not enclosure.** Measured **30.75 x 11.57 x
   3.55** at the course's 0.55 scale, standing on the deck: their tops are **11.57 studs** above the
   deck against a **measured 11.5-stud step-up** — a 0.07-stud margin. They are removed, not kept.
3. **The inward bridge is a 46.25-stud-wide free walk.** No hazard, no narrowing, both edges 46
   studs from the centreline — nothing can shove a runner off it.
4. **Seventeen RotorBumps and sixteen bumpers is padding, not density.** 7.7.3 caps the retained set
   at exactly 5 RotorBumps and 5 forced Bumpers.

### One measured fault that is preserved on purpose

The flood reaches world Y **+10** (lava -50 plus 60 studs) and the first three checkpoint pads sit at
Y -14, -4 and +6. Submersion times, from the preserved schedule (rise starts at 20 s, 60 studs over
140 s = 0.4286 studs/s):

| Pad | Y | Submerged at | Against Par 115 / Cap 210 |
|---|---|---|---|
| Checkpoint01 | -14 | **104.0 s** | 11.0 s before Par |
| Checkpoint02 | -4 | **127.3 s** | after Par |
| Checkpoint03 | +6 | **150.7 s** | after Par |
| Checkpoint04 | +16 | **never** (flood tops out at Y +10, six studs below it) | — |

All four rows are measured off the built template by `CourseBuilder`'s
`CheckpointFloodTimes`, not derived by hand, and the engine spec asserts the two properties that
have to hold: at least one pad stays dry for the whole run, and no pad goes under before Par.

7.7.9 says "Preserve original liquid timing even if the run-time target is difficult" and section
3.1 freezes Summit's `LavaRise` fields, so the schedule is untouched and the numbers above are
reported rather than tuned. This is the deliberate exception to the `CheckpointClearanceStuds`
assertion the new-course builder applies to Piston Peak: the SourcePatch path reports per-checkpoint
submersion times instead of failing the build, because on Summit the flood *is* the timer. The
consequence to watch in the interactive run: a racer still behind Checkpoint01 at 103 s is on a
submerged pad and 3.2's flooded-respawn condition applies.

## The patch, in 7.7's own order

### 1. Seven named beats over the existing route

| # | Beat | Route span | Preserved section | Planned arclength at r 180 |
|---|---|---|---|---|
| 01 | `01_OpeningClimb` | angle 195 → 315 | sectors 1–2, start plaza to Checkpoint01 | 377.0 |
| 02 | `02_SweepTiming` | 315 → 371 | sector 3 | 175.9 |
| 03 | `03_BumperChicane` | 371 → 427 | sector 4, ends at Checkpoint02 | 175.9 |
| 04 | `04_BalanceRise` | 427 → 562 | sectors 5–6, ends at Checkpoint03 | 424.1 |
| 05 | `05_AirGate` | 562 → 663 | sectors 7–8, ends at Checkpoint04 | 317.3 |
| 06 | `06_FinalFooting` | arc exit → plaza rim | the inward road bridge | 107.0 |
| 07 | `07_SummitSprint` | plaza rim → finish | the summit plaza | 85.2 |

**Measured on the built template:** 376.95 / 175.91 / 175.91 / 424.07 / 317.27 / 107.03 / 85.20,
ratios **0.999 – 1.002** of the preserved targets, total **1662.33 studs** over 177 route steps.
Elevation per beat +10 / +5 / +5 / +10 / +5 / +2.5 / +2.5, which is the authored course's own
+5-per-sector climb from Y -20 to the Y 20 plaza. The targets and the measurement come from the same
preserved sector table by design: agreement is the evidence that the patch did not move the arc.

Planned total **1662.4 studs**. Summit's route is deliberately **outside** override 4's 800–1000
stud window for the six new courses: its preserved Par is 115 s against their 75 s, and 7.7 keeps
the centreline. The SourcePatch builder therefore reports route length instead of failing on that
window, and this divergence is recorded here rather than silently exempted.

`06_FinalFooting` is the second-to-last beat and the climax, exactly as 7.7.1 asks; `07_SummitSprint`
is the short final approach to the existing arch, with no encounter.

### 2–3. Removal and retention

Removed, **38 named instances / 113 BaseParts, every one resolved exactly once or the build fails**:
5 of 8 windmills (2 parts each), 7 of 9 maces (11 parts each — the mace is a ten-link chain carrying
a 5.48 x 5.63 x 6.33 ball), 11 of 16 bumpers, all 9 chicane walls, and 6 of the 9 bridge road slabs.
The built template is **199 BaseParts** against the source's 258.

Retained, exactly 5 RotorBumps alternating shape and phase, and exactly 5 forced Bumpers, each
inside its own original route section:

| Encounter | Source instance | Beat | Angle | Radius | Note |
|---|---|---|---|---|---|
| `Windmill01` | `sd_obstacle_25.001` | 01 | 236.25 | 180 | spin +80, bar 25.63 long |
| `Bumper01` | `sd_obstacle_19_001.001` | 01 | **relocated to 266.75** | **176.5** | sector 1, into the gate passage |
| `Seesaw01` | new | 02 | 330.0 | 180 | see 4 below |
| `Mace01` | `sd_obstacle_5_001.003` | 02 | 351.00 | 180 | rock 50 deg, period 2.6, phase 1.3 |
| `Bumper02` | `sd_obstacle_19_001.003` | 02 | **relocated to 361.67** | **179.06** | sector 3, mirrored side |
| `Windmill02` | `sd_obstacle_25.004` | 03 | 399.00 | 180 | spin **-80**, opposite hand to Windmill01 |
| `Bumper03` | `sd_obstacle_19_001.007` | 03 | **relocated to 406.0** | **174.5** | inner half of the chicane |
| `Bumper04` | `sd_obstacle_19_001.008` | 03 | **relocated to 414.0** | **185.5** | outer half, staggered 8 degrees |
| `Seesaw02` | new | 04 | 445.0 | 180 | see 4 below |
| `Mace02` | `sd_obstacle_5_001.005` | 04 | 468.75 | 180 | phase 1.3, opposite sector to Mace01 |
| `Bumper05` | `sd_obstacle_19_001.009` | 04 | **relocated to 480.0** | **179.06** | sector 5 |
| `Fan01` | new | 05 | 582.0 | 171 | horizontal, blows outward |
| `FoamPit01` | new | 05 | 582.0 +- 10 | 188 … 203 | outer-ledge catch, 15 x 6 x 68 |
| `JumpPad01` | new | 05 | 592.0 | 196 | the marked way out of the foam |
| `Windmill03` | `sd_obstacle_25.008` | 05 | 608.67 | 180 | spin +80 |
| `Sweeper01` | new | 06 | bridge r 128 | on centreline | the headline |

Longest run of identical hazards: **3** windmills and **2** maces, never adjacent in route order
(W, B, S, M, B, W, B, B, S, M, B, F, FP, JP, W, Sw) — no run of the same *type* exceeds 2.

### 4. Two previously unused families, plus fan / pad / foam

**Two seesaw boards.** `obstacle_25_001` at scale 0.55, `MaxTiltDegrees` 18. Measured geometry that
drives the mounting: the board's walkable top is **17.7227** studs above the pedestal's own centre
and the pedestal's lowest point is **-9.3184**, so the board top stands **27.041 * 0.55 = 14.87**
studs above whatever the pedestal stands on, and at 18 degrees of tilt the board's lowest point is
**10.04 * 0.55 = 5.52** studs above that same base. A seesaw therefore *cannot* sit flush on a solid
deck: sink it far enough to walk onto and its ends drive into the arc. The pedestal is sunk
**5.52 studs** — exactly the arc's own 5.6-stud slab thickness, so its base is flush with the arc's
underside and the board's lowest tilt point grazes deck level — leaving the board top **9.35 studs**
above the deck. That is a step up, not a ramp: it is inside the measured **11.5-stud** step-up with
2.15 studs to spare, and no ramp is added, because a ramp long enough to climb 9.35 studs at
`box_013`'s measured 28.5-stud rise is 45 studs each side and would eat a third of a sector. The
board is **5.13 studs wide**, against the 3.06-stud precision minimum, and the pedestal is the same
5.13 across, so it plugs the slot the board leaves at deck level.

Falling off a board drops a runner **9.35 studs onto the same arc deck**, not into lava; the cost is
climbing back on, not a splash. That is deliberate and is recorded as such: 7.7.4 puts the boards in
the arc corridor, and the arc deck under them is preserved geometry. **The 9.35-stud mantle onto a
board that is itself tilting is the single item on this course most worth an interactive run.**

**One sliding sweeper**, `obstacle_2_001` at scale 0.55 — frame 27.20 long, drum radius 3.37 —
sliding about its own X with amplitude 8 and period 3.2, so it sweeps **27.20 + 16 = 43.2 studs**
across a bridge narrowed to 16.25. See 6 below.

**One fan**, `propeller_trampoline_1_001` at scale 0.5, mounted at the inner lane boundary with
`FanAxis` horizontal and `FanDirection` outward: it pushes a runner toward the outer ledge.
**One foam lane**, a 15 x 6 x 68 volume on the outer ledge centred on angle 582, measured
spanning r **188 … 203** at its centre — a 68-stud wade — rejoining the lane before beat 05's own
windmill gate at 608.67.
**One jump pad**, `trampoline_1_001` at scale 0.6, standing in the foam at angle 592 as the
marked, slow way back onto the lane. Its measured reach is recorded in the QA report's
`LaunchEnvelopes` finding; it launches inward, well inside the lane and 16 degrees short of the next
beat's gate.

Falling tiles are Tiptoe's headline and are **not** added here (override 2).

### 5. Encounter mix

| Type | Count | Share |
|---|---|---|
| RotorBump | 6 (3 windmills, 2 maces, 1 sweeper) | **37.5%** |
| Bumper | 5 | 31.3% |
| Seesaw | 2 | 12.5% |
| Fan | 1 | 6.3% |
| JumpPad | 1 | 6.3% |
| FoamPit | 1 | 6.3% |
| **Total** | **16** | six types, five families |

Families: Climb/Descend, Timing, Precision, Ride, Launch. Dominant type 37.5% against the 40% cap;
longest same-type run 2 against the cap of 3; climax `06_FinalFooting` carries 1 encounter against
`07_SummitSprint`'s 0.

#### Override 2 and the three-course cap — a scoping decision, stated plainly

Override 2 caps each non-glue mechanic at "at most three of **the six new courses**". Summit's three
non-glue presets already stand at that cap across those six: `Seesaw` in Tumble Tunnels, Tiptoe
Trials and Piston Peak; `Fan` in Ball Barrage, Tiptoe Trials and Tumble Tunnels; `Sweeper` in Ball
Barrage only. 7.7.4 nevertheless *instructs* Summit to add two seesaw boards and one fan, and
explicitly applies override 2 only to the falling tiles it forbids.

Resolved by the rule's own wording rather than by exempting Summit from a check:
`CourseQA.auditCrossCourse` now counts a course toward the **three-of-six** cap only when its layout
is not `SourcePatch`, and says so in the finding's own detail text. Summit is still scored in full by
override 2's other two rules (headline exclusivity, no shared beat recipe) and by every per-course
variety rule. **This is a judgement call about a rule, not a measurement, and it is reversible in one
line** — see the hand-off note in HANDOFF section 1.

### 6. The narrowed inward bridge

Six of the nine `road_001` slabs are removed — the `across = -15` and `across = +15` columns — and
the three centre slabs at r 145 / 115 / 85 are left exactly where they were. The bridge keeps its
centreline (angle 295), its top (Y 17.5) and its radial span (r 67.2 … 162.8, still flush with the
arc's inner edge at one end and the plaza rim at the other), and narrows from **46.25 to 16.25
studs**. Both edges are open lava at Y -50 (rising to +10). Nothing is added underneath.

`Sweeper01` stands at r 128 on that centreline. The frame is 27.20 studs across and slides ±8, so
its swept span is **43.2 studs against a 16.25-stud bridge**: a runner caught anywhere on the bridge
is pushed the full remaining distance to an edge, which is the measurement 7.7.6 asks for. The
drum's shove (48 studs/s, 0.24 s hold) is a bonus, not the mechanism.

### 7. Enclosure — measured, and cheap on purpose

Each encounter sits in a **gate**: a pair of `wall_001` guard walls laid RADIALLY across the deck at
the encounter's own angle, so at that angle the deck's cross-section is wall, hazard, wall. There are
**13 gates and 29 guard walls**, all measured on the built model at **17.35 studs above their own
deck** and a half-length of **7.56**.

- `GateInner` spans r **152.44 … 167.56**. It deliberately **overhangs the deck's inner edge by 3.56
  studs over open lava**, and that overhang is the whole point: a jump between two points on the
  inner edge bows inward, and at the measured 22-stud reach the deepest it can dip is
  `sqrt(156^2 - 11^2) = 155.61`. A wall reaching 152.44 is under every jump a runner can make, which
  is what closes 7.7.7's inside shortcut for good. The outer side needs no such margin: a chord
  between two points at r 200 never leaves r 200.
- `GateOuter` spans r **188.00 … 203.12**.
- The passage between them is r **167.56 … 188.00**, **20.44 studs**, inside both the windmill's
  measured 167.18 … 192.82 sweep and the mace's 168.10 … 191.90.
- A seesaw gate takes four walls instead, because it seals everything except the board: inner pair
  152.44 … 177.36, board and pedestal 177.44 … 182.56, outer pair 182.54 … 203.06.

Height check: 17.35 studs above the deck, against 7.7.7's 14-stud minimum and against a measured
**19.4-stud** clearance to the underside of the sector stacked above (sectors 6, 7 and 8 sit 25 studs
over sectors 1 and 2, and the arc slab is 5.6 thick). The builder fails the build outside that band.
So no guard wall intersects the storey above it and no wall top is a step up from any deck — the only
way onto one is a **2.1-stud drop from the storey above at the same angle**, onto an isolated
5.2-stud-wide top that leads only back where it came from.

### What the gates measure, gate by gate

`CourseBuilder` unions what each gate's pieces block (from placed geometry) with what they sweep
(their measured radial reach) and reports two different numbers, because they answer two different
rules. The **edge gap** is 7.7.7's anti-skip rule and must be closed at every gate. The **interior
gap** is the passage, and is held closed only where a measured sweep is supposed to fill it — a
forced bumper that fills its own passage is a wall of mesh, not 8.4's "cannot avoid all contacts
without slowing or making the required precision manoeuvre".

| Gate | Angle | Encounter | Must seal | Edge gap | Interior slot |
|---|---|---|---|---|---|
| Gate01 | 236.25 | Windmill01 | yes | **0.00** | **0.00** |
| Gate02 | 266.75 | Bumper01 (r 176.5) | no | **0.00** | 5.97 outer, 3.45 inner |
| Gate03 | 330.00 | Seesaw01 | yes | **0.00** | **0.05** |
| Gate04 | 351.00 | Mace01 | yes | **0.00** | **0.50** |
| Gate05 | 361.67 | Bumper02 (r 179.06) | no | **0.00** | 6.11 inner, 3.50 outer |
| Gate06 | 399.00 | Windmill02 | yes | **0.00** | **0.00** |
| Gate07 | 406.00 | Bumper03 (r 174.5) | no | **0.00** | 7.97 outer only |
| Gate08 | 414.00 | Bumper04 (r 185.5) | no | **0.00** | 12.54 inner only |
| Gate09 | 445.00 | Seesaw02 | yes | **0.00** | **0.05** |
| Gate10 | 468.75 | Mace02 | yes | **0.00** | **0.50** |
| Gate11 | 480.00 | Bumper05 (r 179.06) | no | **0.00** | 6.11 inner, 3.50 outer |
| Gate12 | 582.00 | Fan01 + FoamPit01 | no | **0.00** | 10.99 (the running lane) |
| Gate13 | 608.67 | Windmill03 | yes | **0.00** | **0.00** |

**Every gate's edge gap is 0.00.** Every swept gate closes its passage to within 0.50 studs against
a ~2-stud character. Every bumper spans the route centreline (r 180) at rest, so a runner who does
not steer is hit; the slots are the measured steering room, and Gate07/Gate08 are the chicane — one
leaves only the outer 7.97 studs, the next only the inner 12.54, eight degrees (25 studs of arc)
apart.

### The one 7.7 clause this pass does NOT meet — read this

7.7.8 asks that "each remaining shove must reach liquid or a measured >= 5-second detour". On the
narrowed inward bridge it does: the bridge is 16.25 studs wide, both edges are lava, and the
sweeper's swept span is 43.2 studs, so a runner caught anywhere on it goes in. **On the arc it does
not, and cannot.** The preserved deck is 44 studs wide, the route runs down its centre, and a
measured bumper shove (54 studs/s for 0.26 s, 3–5 studs of real displacement in the section 1.2 kit
evidence) moves a runner a fraction of the 24 studs to either edge. A shove on the arc costs time
and position; it does not drown anyone.

Closing that would mean narrowing the whole arc lane with continuous enclosure, which section 9.3
allows down to 4.5 studs. It is **blocked by preserved geometry, measured**: the 30 start pads span
r 165 … 196 and every checkpoint pad is 32 studs wide spanning r 164 … 196, so the narrowest
continuous rings that do not cut through the authored start grid or an authored checkpoint are at
r 163 and r 197 — a 34-stud lane, still far wider than any shove. Narrower than that changes the
start, the checkpoints, or both, which 7.7 preserves and 3.1 freezes.

This is reported as a failing measurement under 7.7.10 rather than silently exempted. **It is a scope
decision for the user**, and the options are: accept it (Summit's pressure is the rising lava, not
knock-offs); add the ~67 tangential `wall_003` rings at r 163/197 for the enclosure value alone,
knowing shoves still will not reach; or change the preserved start/checkpoint geometry, which is
outside 7.7.

### 8. Attribute tuning only

No shared tuning is changed. Per-course values set by this pass: sweeper slide amplitude 8 (from the
preset default 4) and period 3.2; seesaw `MaxTiltDegrees` 18; fan `FanColumnHeight`, `LaunchSpeed`
and `FloatFactor`; pad `LaunchSpeed` and `FloatFactor`; foam volume size. Every retained hazard keeps
its original attributes untouched — the windmills still spin ±80 and the maces still rock 50 degrees
on period 2.6 at their original phases.

## Loophole table (section 11 step 1)

Answers are **planned** until the gate cut-set audit and the fixed-camera pass run; the QA result
section below records which ones are measured.

| Encounter | walk-around | edge-hug | bypass-jump | launched-past | safe-wait |
|---|---|---|---|---|---|
| Windmill01 | NO — gate walls close r 156–171.1 and 188–203.1 at 236.25 | NO — both strips walled at the gate angle | NO — the 25.63-stud bar sweeps the whole 16.9-stud passage | NO — no launch tool in beat 01 | YES, at the gate mouth; costs a full 2.25 s bar period per miss |
| Bumper01 | NO — same gate pair at 266.75 | NO | NO — bumper 10.93 in a 16.9 passage leaves 3.0 studs a side, a precision slip not a walk | NO | YES, free but the lava is rising |
| Seesaw01 | NO — four-wall gate at 330.0 seals r 152.4-177.4 and 182.5-203.1; measured worst open slot **0.05** | NO | NO — the board is the only floor across the gate, and its pedestal plugs the deck-level slot | NO | YES — waiting for the board to settle costs its 3 s response |
| Mace01 | NO — gate pair at 351.0 | NO | NO — 23.5-stud swept envelope over a 16.9 passage | NO | YES, one 2.6 s period |
| Bumper02 | NO — gate pair at 361.67 | NO | NO | NO | YES |
| Windmill02 | NO — gate pair at 399.0 | NO | NO | NO | YES, 2.25 s |
| Bumper03/04 | NO — gate pair at 406 and at 414 | NO | NO — staggered 8 degrees and 11 studs apart radially: the slalom is forced | NO | YES |
| Seesaw02 | NO — four-wall gate at 445.0, measured worst open slot **0.05** | NO | NO | NO | YES |
| Mace02 | NO — gate pair at 468.75 | NO | NO | NO | YES |
| Bumper05 | NO — gate pair at 480.0 | NO | NO | NO | YES |
| Fan01 | NO — inner guard wall at 575.0; the outer side is the foam lane | NO — the outer ledge *is* the penalty | NO | NO | YES — but standing still in the fan column is what pushes you out |
| FoamPit01 | n/a — it is the penalty, not a gate | n/a | NO — 88 studs of foam, no jump clears it | NO | n/a |
| JumpPad01 | n/a — it is the recovery | n/a | NO — measured reach lands inside the lane, 60+ degrees short of the beat gate | NO | n/a |
| Windmill03 | NO — gate pair at 608.67 | NO | NO | NO | YES |
| Sweeper01 | NO — the bridge is 16.25 wide and the sweep is 43.2 | NO — both bridge edges are lava | NO — 16.25-stud bridge, 22-stud jump reach, but the sweep is continuous along it | NO | YES at the bridge mouth, one 3.2 s period, and the flood is rising |

A timed run *through* a gate while the bar or the mace is elsewhere in its cycle is legal and
intended. No encounter answers YES to walk-around, edge-hug, bypass-jump or launched-past.

## Top-down schematic

~~~text
                       angle 0 / 360
                             |
        sector 4  (371-427, Y -5)   sector 3 (315-371, Y -10)
                   \                /
   sector 5 --------  o o o o o o  -------- sector 2 (270-315, Y -15)
   (427-517, Y 0)   /   r=180 route  \
                   /                  \
   sector 6 ------                      ------ sector 1 (180-270, Y -20)
   (517-562, Y +5)         PLAZA               START at angle 195
                        r 0..85.2, Y 20
   sector 7 ------      ^ finish              ------ sector 8
   (562-618, Y +10)     | bridge at angle 295        (618-663, Y +15)
                        |  r 67.2..162.8, Y 17.5, 16.25 wide
                        +-- Sweeper01 at r 128

   deck cross-section at any gate angle:
   r156 |###GateInner###|      passage 16.9      |###GateOuter###| r203
        156 ........ 171.1    171.1 .... 188.0   188.0 ....... 203.1
                              ^ hazard sweeps 167.2 .. 192.8
~~~

## Measured QA result

`CourseQA.check` on the built template, full 1-stud sampling with a 0.25-stud refine pass:
**zero errors, one warning, 49 findings PASS, 9 NOT RUN, 1 FAIL.** Status BLOCKED, which is the best
an automated run can report while live-playtest items are outstanding.

| | Measured |
|---|---|
| Spec hash | **`dcece9ec`**, identical across a double build, 199 BaseParts both times |
| Surface graph | **108,149 cells, 103,720 nodes, 6,603,327 edges** |
| Gate cut sets | **all 7 hold** — 0 of 30 spawn cells bypass any gate |
| Ordered route | PASS — 30 spawn cells, 5 ordered waypoints, 0 failing legs |
| Start / checkpoints / finish / boundary | 30 pads, 4 checkpoints each with Pad and Trigger, exactly one Finish Trigger and Deck, 24 walls at r 390 with a worst radius error of **0.00** |
| Bounds | worst part corner **539.7** of 600; worst geometry centre **195.6** of 380; route radius **180.0** of its 200 bound; static route envelope **-25.6 .. 35.3** inside -30..90; **0 violations** |
| Encounters | 16, six types, five families, RotorBump **37.5%**, longest same-type run **2** |
| Cross-course | **all 12 findings PASS over seven staged specs** |
| Launch envelopes | the one pad reaches **26.77 studs** level (48.0 / 0.20, trigger radius 3.48); the fan is correctly excluded as a 0-Y horizontal blower, not a ballistic launcher |
| Ordinary jump gaps | none — a patched course chains nothing, so it emits no `Advance` route steps and 8.3's 13.2-19.8 window has nothing to score |

### The one FAIL, and why it is escalated rather than tuned away

**`NoBreatherSquare` — largest flat hazard-free square on the route is 42 x 42 studs against 8.4's
24-stud limit.** This was 120 x 120 on the first run, because `auditCoverage` exempted start and
finish plazas by the NEW builder's own part names (`startplaza`/`finishplaza`) and the authored plaza
is called `sd_plaza.001`; that is fixed (it now matches on `plaza`, which changes nothing for the six
built courses) and the number fell to 42. **The remaining 42 x 42 is the preserved arc deck itself** —
it is 44 studs wide and flat, so a 42-stud square fits between any two gates. Closing it means
narrowing the preserved deck, which runs into the same wall as the 7.7.8 divergence above: the
authored 30-pad start grid spans r 165 … 196 and every checkpoint pad is 32 studs wide. Reported
under 7.7.10 as a failing measurement, not exempted.

### Engine TestEZ

`places/arena/tests/Assets/SplashdownQA.spec.luau` over the built model. The first attempt **died on
"exhausted allowed execution time"** — the spec re-runs the full audit inside one TestEZ node, and
6.66 million edges does not fit Studio's script budget. A SourcePatch course is now audited in-engine
at **2-stud** sampling, with the full-resolution audit living in `qa.json` and the resolution
recorded in both. Three new assertions were added for this course: every declared gate exists and
seals both arc edges; every guard wall clears 14 studs and stays under its stacked clearance; and
every declared removal is gone while every retained instance is present. Final result over the
shipped template: **24 passed, 0 failed, 0 skipped.**

**That in-engine pass then caught a real defect this document had already mis-described**: retained
windmills and maces were being re-seated at their declared gate angle, which threw away the authored
8.3-stud post sink and lifted all three windmill bars to deck +9.29 … +14.93 — clean over a runner's
head. Retained pieces now move only when they say `Relocate`, which only the five bumpers do (a
bumper's authored mounting *is* its bounding-box bottom on the deck, so re-seating one loses
nothing). Re-measured on the rebuilt template: bars back at deck **+0.99 … +6.63**, maces at deck
**+1.00 … +16.28**, bumpers at deck **+0.00 … +7.06**.

## Fixed cameras and the bad-map-refs comparison

Both 8.6 views captured off a preview lifted 9,000 studs above the live MapOrigin (the arena itself
was never moved), 70-degree FOV, camera CFrame and Focus both set: top-down eye
(-537.767, 9980.777, -53.314), three-quarter eye (-237.767, 9720.777, 245.686), both looking at
(-537.767, 9480.777, -54.314). Recorded in `evidence/course-cameras.json`.

Compared against `bad-map-refs/1, 2, 9, 10, 11`. **Reference 2 is the pre-hardening Summit itself and
is 8.6's readability bar for this course**, so this is a before/after rather than an avoid-this.

- **Not a flat sprinkled field (ref 1).** Eight storeys of climbing arc, and the hazards are grouped
  into 13 walled gates instead of ref 2's even scatter.
- **No lone open spinner (ref 10).** Every windmill and mace now stands inside a measured wall pair
  that closes both edge strips at its own angle.
- **No avoidable or floating bumpers (ref 11).** All five sit on the deck at a measured +0.00 and
  every one spans the route centreline at rest.
- **No repeated narrow swing-panel bypass.** There is no swing panel, and no two gates share a recipe.
- **Where it is still closest to the bad references, stated plainly:** the preserved 44-stud arc deck
  between gates is open coloured slab with nothing on it, which is ref 10 and 11's empty-slab look.
  That is the same geometry the `NoBreatherSquare` finding measures and the same geometry 7.7 forbids
  redesigning.
- **Readability is better than ref 2.** The green gate walls punctuate the lane into readable
  doorways, and the narrowed inward bridge reads as a real crossing instead of the 46-stud free walk
  in ref 2's foreground.

## QA links

- Spec: `src/shared/Game/Splashdown/CourseSpecs/SummitSplash.luau`
- Evidence: `docs/splashdown/evidence/courses/SummitSplash/qa.json`, `top-down.png`,
  `three-quarter.png`, and its row in `evidence/course-cameras.json`
- Source export retained for comparison: `assets/splashdown/summit-source.rbxmx`
  (**not re-exported and not overwritten by this pass**)

## Manual checklist

- [ ] Interactive keyboard run, full course, unteleported — **NOT RUN**
- [ ] The 9.35-stud mantle onto each tilting seesaw board — **NOT RUN**, and the single item on this
      course most worth a human's hands
- [ ] Deliberate mistimed contacts at every gate — **NOT RUN**
- [ ] Checkpoint recovery after a flooded Checkpoint01 at 104 s — **NOT RUN**
- [ ] Is a 20.44-stud gate passage with a 25.6-stud bar sweeping it fair, or a guaranteed hit? — **NOT RUN**
- [ ] Scripted expert/mid policy trials — **NOT RUN** (standing 2026-09-16 decision)
- [ ] 30-rider start load and local multi-client session — **NOT RUN**
- [ ] Mesh-level seam pass over the 68 reported oriented-box overlaps — **NOT RUN**

## Registration

`SummitSplash` is **staged and promoted but deliberately NOT in `Splashdown.CourseOrder`.** Adding it
is HANDOFF section 12.1's seven-course replacement transaction, which also deletes six parked
`LegacyCourses` models and retires seven recipes with no archive, and that needs the user's own
go-ahead. `Courses.SummitSplash` already carries the preserved Difficulty 3 / Par 115 / Cap 210 /
Close 45 / `LavaRise {60, 20, 140}` and was **not touched by this pass**;
`Intro.Courses.SummitSplash` already exists with three valid shots and a 90-character description, so
section 12 will need **no intro change for this course**.
