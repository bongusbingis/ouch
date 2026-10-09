# Course Forge

A Studio plugin for assembling Splashdown courses out of the `battle_stadium`
source pack by clicking, instead of by working out offsets and yaw angles by
hand. It is the direct-manipulation counterpart to the declarative
`CourseBuilder` pipeline, and it places pieces with the same maths, so a run
built here lands where a spec would have put it.

## Install

```
python tools/plugins/build_plugin.py
```

That writes `CourseForge.rbxmx` next to the source. Drop that file into your
local plugins folder and restart Studio, or use **Plugins -> Plugins Folder** to
open it:

```
%LOCALAPPDATA%\Roblox\Plugins
```

The plugin is one self-contained `Script`. It does not `require` anything from
this repo, so it runs in a bare design baseplate that holds nothing but the
source pack.

## What the design baseplate needs

One Workspace child holding the ~176 source roots, with the hierarchy it has in
the Match Place today. The plugin looks for `battle_stadium`, `Battle_Arena`,
`battle_arena`, `BattleArena`, `BattleStadium` and `AssetPack`, and if none of
those are present it falls back to whichever Workspace child holds the most
children named in the source scheme (`platform_003`, `obstacle_12_001`,
`water_platform_tube_002`). **Rescan** re-runs that search.

The pack itself is never modified, and it is excluded from the placement
raycast, so the cursor cannot land on the showcase and build a course inside it.

## Use

The list shows only the **118 map-building pieces** of the 176 in the pack, under
friendly names and grouped by category (Floors, Ramps, Tracks, Belts & tiles,
Rung bridges, Arches & gates, Barriers, Pads & fans, Markers, Blocks, Hazards).
Balloons, drones, collectibles, banners, speakers and the column/cap dressing are
filtered out. Each row carries a live 3D preview of the actual mesh, its friendly
name, its raw source id, and a badge saying how its sockets were obtained.

Pick a piece and a translucent ghost follows the cursor.

- **Free joints are drawn in the viewport** as green spheres, and the one the
  ghost will attach to turns yellow and grows. That is the whole snapping model,
  made visible: a piece attaches to a joint, and only joints that are actually
  free are offered.
- **Click** places the piece. The ghost stays live, so clicking repeatedly builds
  a run.
- **Repeat** (or <kbd>Enter</kbd>) places another copy straight onto the last
  piece's Exit without using the mouse. The fast path for a straight run.
- **Joint nudge** (forward / sideways / up, in studs) offsets the piece along the
  joint's own frame, so "forward" follows the route rather than a world axis and
  a gap stays a gap after the run turns. Use it to open deliberate gaps, close a
  seam, or lift a piece. <kbd>+</kbd> and <kbd>-</kbd> step the forward nudge by
  one stud. Unlike rotation this is a **setting**: it persists until reset, so a
  whole run can be laid with a consistent gap.
- **Rot -/+** (or <kbd>R</kbd> / <kbd>Shift</kbd>+<kbd>R</kbd>) turns the piece by
  the rotation step. That one applies to the piece being placed and then resets,
  so a turn meant for one piece is not inherited by the rest of the chain.
- **End: Exit / Entry** (or <kbd>Tab</kbd>) switches between chaining forward and
  prepending to the front of a run.
- <kbd>Esc</kbd> cancels placement.

**Surface pieces chain; mount pieces drop.** A piece the manifest calls a `Mount`
-- a bumper, hammer, fan, big ball -- has no meaningful route through it, so it is
never chained into the run. It drops onto the surface under the cursor by its
Support socket instead, optionally grid-snapped. Those rows are badged `mount`.

Everything lands in `Workspace.CourseForgeBuild`, one Model per piece, and every
placement is a single undo step.

### Occupied joints

A joint that already has a piece attached is **not offered**. This was the cause
of the worst early bug: the tool used to hand back the nearest Exit socket within
a wide radius across every placed piece, so hovering near the middle of a
finished run snapped to a joint that was already filled, and the new piece landed
*inside* the piece attached there. A socket is now treated as taken when any
other piece's Entry or Exit sits within `max(1.5, 4 x scale)` studs of it, and the
search radius is a much tighter 45 studs.

## Socket data

Each placed piece carries `CF_Asset`, `CF_Scale` and `CF_Yaw` attributes, which
is how the tool finds sockets on pieces placed in an earlier session.

Sockets come from two places, and the list marks which:

- **Measured** (`measured` badge) — 58 assets whose Entry/Exit/Support/Axle
  sockets were swept in Studio. 57 come from
  `src/shared/Game/Splashdown/AssetManifest.luau`, baked from manifest
  **Version 7** (`SourceHash e9e69d1…`); `box_012` is measured here and has no
  manifest entry. If the manifest is re-measured, re-extract it.
- **Derived** (`approx` badge) — the remaining assets, whose sockets
  are computed at scan time from the root's local bounding box: Entry and Exit
  at the centres of the two end faces on the longer horizontal axis, level with
  the top of the box, and Support at bottom centre.

Derived sockets are a bounding-box guess, not a measurement. They are exact for
slab-like pieces and wrong by the difference between the box top and the real
walkable deck for anything open-topped — a rung bridge such as `road_001` chains
in about a rail's height low. Nudge those by hand, or measure the asset properly
and add it to the manifest.

Socket positions are in each root part's own local CFrame space at scale 1, and
are multiplied by the placement scale, exactly as `CoursePresets` does. The
default placement scale is **0.55**, which is what the arena and every shipped
course use.

### The green switchback family

`box_011`, `box_013` (the ramps) and `box_012` (the flat connector between them)
were re-measured in Studio on 2026-09-17 by raycast sweep, because their ends are
not square:

- The ramps' decks are **trapezoids**, 137.6 studs long down one side and 152.4
  down the other, with the end faces cut on roughly an 8.5 degree bevel. The
  visible mid-span crease is a vertical bend, not a plan-view one: each ramp is a
  flat plateau at 26.915, a slope, and a flat plateau at -1.625. Entry and Exit
  now sit exactly where the deck crosses the **route centre line** (-72.79 and
  +72.96), measured rather than assumed.
- `box_012` was **absent from `AssetManifest` entirely**, so the plugin was
  deriving its sockets from the bounding box and picking **Z** as the route axis
  because Z is the longer side (55.44 against 51.17). That laid the connector
  ninety degrees across the run. Its bevelled ends are in fact the **X** pair —
  its Z ends measure square at a constant +-27.6517 — so it is now baked with
  `ForwardAxis = "X"`.

Because the bevel is a property of the mesh, a ramp chained in a straight line
still meets a square-ended neighbour flush only on the centre line, opening into
a shallow wedge toward the edges. That cannot be fixed by moving a socket; the
pieces are cut to switchback, where the mirrored ramp presents the matching
angle.

## Placement maths

Lifted from `CoursePresets.placeTravelPiece` so both tools agree:

```lua
rootTarget = CFrame.new(cursorPosition)
	* CFrame.Angles(0, math.rad(cursorYaw - forwardHeading), 0)
	* CFrame.new(-socketLocal)
```

`forwardHeading` is the scalar yaw that a piece's own Entry→Exit direction
represents, in the convention where yaw 0 faces world −Z. Using that scalar
rather than the sockets' own axis vectors is what lets an X-forward ramp
(`box_011`, heading −90) chain onto a Z-forward slab (heading 180) without a
twist. The `Axis` field on each socket is documentation, not placement input.

## Verified

- 11 placement-identity cases pass headlessly (straight runs, cross-axis ramp
  chaining, the connector's X route axis, turns, prepending, support mounts).
- A five-piece chain built in the real Match Place from the real source parts:
  every junction gap measured `0.0000`, the ramp descended the expected 28.5
  studs, and a Support-mounted bumper landed with `0.0000` error.
- The green switchback (ramp, connector, ramp, connector) built at 0.55 and
  walked along its centre line in 0.25-stud steps: no holes, and off the meshes'
  exact centre seam **zero** vertical steps over 0.35 studs. On the seam itself a
  ray slips through and reads 14.8 studs low, but a 2-stud character-sized probe
  there touches solid deck, so it is a raycast artifact rather than a hole.
- Catalog scan over all 176 pack children: every one resolves a root, none has
  degenerate bounds, and all 58 baked keys match a real child name. Scan is 1 ms.
  117 of the 118 whitelisted ids are present and 59 children are excluded as
  scenery (117 + 59 = 176). `box_003` is listed in the inventory document but is
  genuinely absent from the pack, so it simply never appears.
- Occupancy: a four-piece run yields **one** free Exit socket, where the old
  nearest-socket search offered all four. Placing a fifth piece on that joint
  gives a `0.0000` gap, lands past the end of the run, and overlaps no other
  build piece.
- Joint nudge: `+5` and `-2` studs produce exactly `+5.0000` and `-2.0000` studs
  of travel along the route direction.

Not yet exercised: the plugin's own UI, viewport previews and mouse loop in an
installed Studio session — the placement maths, catalog, occupancy and nudge are
all verified headlessly and against the live pack, but loading the `.rbxmx` and
clicking around still needs a human.
