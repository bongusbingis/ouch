# Splashdown asset inventory

Date: 2026-09-15. Source: **Workspace.battle_stadium** in Match Place121997450145716. Complete raw data: [inventory.json](evidence/inventory.json). Collector: [inspect-assets.luau](probes/inspect-assets.luau).

## What is actually present

**176 asset roots /222 BaseParts**, all roots are MeshParts, not Models. A “model” below means a source root plus its BasePart descendants. No source asset contains a script or an authored behaviour attribute, and there are **zero Attachments/sockets**. All source parts are unanchored and collidable in the Edit showcase; the course author anchors clones. Never infer runtime safety from a parked source display. The separate arena has name-matched, differently named/scaled instances; those name lists are not a source registry for new courses.

Usage is mesh-ID matching against the **seven current parked courses**, including static dressing. It does not prove the asset has behaviour, and it excludes missing CrossCurrent. Child parts may share a mesh with another source; the raw manifest preserves that ambiguity. Runtime assignment is described separately.

Each row supplies upright group bounds (X×Y×Z, studs), part count, and **PΔ** = source pivot position minus upright group-bounds centre (world-axis studs). Every imported pivot has the same rotation: local X→world+X, local Y→world+Z, local Z→world−Y, so its formal `LookVector` (local−Z) points **world+Y**, not along a route! Full absolute pivots, every child's Size/CFrame/PivotOffset/MeshId and bounds in the imported-pivot frame are in inventory.json. The table reports world-upright bounds to avoid calling depth “height.”

For sockets, normalize to a course-upright bottom-centre frame as the existing uniform-scale author does, then define entry/exit separately. **Do not use raw imported LookVector for conveyors, launch direction or route forward.** Long boards/tunnels generally run ±Z in the upright source frame; arched bridge span/roller axis is ±X; rotationally symmetric pieces have no unique forward. Symmetric entry direction must be authored explicitly. Exact travel sign for a particular chevron skin remains a visual/socket validation step.

## Reference crosswalk and important corrections

| Brief/reference silhouette | Actual source | Existing behaviour / required action |
|---|---|---|
| Rectangular blue slab, blue octagon, raised yellow-top octagon | platform_001–003; octagon_002; octagon_001 | Static, uniformly scalable |
| Four curved track colourways | arc_001–004 | Summit uses all four; source pivots far from bounds centres, so socket normalization matters |
| Green zigzag/switchback ramp blocks | box_011/013, connected by box_003/012 | Static; actual collision/slope trials needed |
| Green/orange ribbed arched ramps | bridge_001/002 | BumperBay uses001; old helper calls it a plank, but it is arched |
| Yellow/pink/green inflatable tunnels | arch_004/005/006 | Currently unused; ±Z route axis |
| Small arches/hurdles, inflatable slide | arch_001–003; slide_001 | Slide static in Downpour |
| Individual rainbow tiles | color_box_001–008 | Static stairs in BumperBay; FallingTile candidates |
| Stacked mattress/foam platforms and stubs | water_platform_*, partition_*, tube_*; box_* | Separate compatible pieces; source overlap is deliberate assembly, not a geometry QA failure |
| Framed crossed panels | door_002–007 | **Confirmed Door Dash slabs**, not decoration; colours are not breakability |
| Colourful drums/barrels | podium_001–007 | Large upright drums; uniform scaled/rotated log-roll candidate, not a new mesh |
| Rung/bar arrays on bases | road_001/002; wall_* rail variants | **Static rung bridges**, not currently flipper scripts |
| Large/small hoops | ring_002/001 | Large static hoop; small has pickup silhouette; no pickup system |
| Beach balls | ball_001 | Only one standalone ball source. Large “striped ball” at air_balloon_001 has a basket: **hot-air balloon**, not collision-equivalent. Enlarge ball_001 uniformly if approved |
| Grey guard-rail arc | fence_001 | Unused source; .55 scale gives ~15.8-stud height, but visible gaps/foot geometry need collision and anti-climb audit |
| Start/finish lights + checkers | finish_002 + finish_001; checkpoint_001–003 arches | Visible meshes plus separate race triggers; zero-thickness strip needs slight surface offset |
| Low yellow hurdles, flags/towers | wall_004/006–008; flag_001/002; tower_* | Low hurdles are not 14-stud anti-skip walls |
| Banana, unicorn, small cubes | banana_001, unicorn_001, box_001/002 | Static dressing only, off route |
| Dumbbell spinner; four-arm cross; two-arm bar | obstacle_6_001; obstacle_12_001; obstacle_27_001 |6 has legacy Spinner name path;12/27 dead unless given Rotor+Shove |
| Three apparent disc sizes | obstacle_14_001,15_001,26_001 |14 diameter39.62;15 and26 are both66.49. **Two measured diameters, not three**; make third by uniform scale, not distortion |
| Pizza platform / green hub | obstacle_16_001 with child16_002 | Used by DiscJockey with whole-assembly Origin rotation; gaps are actual mesh geometry |
| Striped carousel | obstacle_13_001 +13_002 | Dead currently; Rotor+Carries preset |
| Big Balls | obstacle_23_001 pole +23_002 sphere | Sphere≈13.70 diameter; no bounce/roll-off today |
| Spiked roller | obstacle_2_001 frame +2_002 drum | BumperBay already spins drum X +Shove; sliding parent composition missing |
| Mace on chain | obstacle_5_001…011 | Summit already rocks root/chain+Shove; not decorative and not physics chain constraints |
| Mallets / hammers | obstacle_1_001 (single mesh),3_001/002,4_001/002 | Small mallet currently misused as Bumper in TiltTrip.3/4 rock on axle; asymmetric stroke absent |
| Spring piston | obstacle_22_001 +22_002/003 | Dead; moving head/spring pose must preserve proportions |
| Seesaw silhouettes | obstacle_11_001 with chevron board9_001.001; obstacle_25_001/002 narrow plank | **No weight-driven seesaw**.25 is called “windmill” and Y-spun in old recipes despite its plank/pedestal silhouette |
| Cyan half-pipe panels on pink frame (reference9) | **obstacle_24_001 with24_002–005** | This is the paddle-wheel assembly, spun X in current WhirlPool/Downpour. It is **not** the legacy SwingPanel prefix |
| Existing SwingPanel code asset | **obstacle_8_001 axle +8_002 flat square flap** | Pink/yellow square target panel, visibly different from cyan cradle. Keep separate presets |
| Caged fan | propeller_trampoline_1_001 +propeller_trampoline_2_001 | Fan/FanBlade; default updraft is vertical, not horizontal ball flow |
| Red/grey round pads / striped trampoline | trampoline_1–5 roots (child of5 is named trampoline_6_001) | All two-part pad families;3 already JumpPad. Geometry alone is not Bumper; choose explicit kit |
| Chevron belt | obstacle_9_001; long board under11 | Static mats today, no conveyor force |
| Button cube/triangle bumpers | obstacle_18_001 /19_001 | Bumper attribute; forced-contact placements required |
| Blue small humps | obstacle_20_001 /21_001 | Not spring pistons/buttons; convex blue humps, one strapped. Keep static or explicit ride preset |
| Small ribbed cylinder | obstacle_10_001 | Static stub; optional log-roll preset |
| Collectibles | heart/star/ring/key/crown/diamond/bomb/dynamite/berries/apple/coin | No Splashdown pickup system. “Candle” may be the red single dynamite stick; exact mapping unresolved, out of scope |
| Battle Stadium object | battle_stadium_002 | Excluded by brief |

Visual evidence resolving misidentifications: [panels](evidence/panels.jpg), [square SwingPanel](evidence/swing.jpg), [blue humps](evidence/halfpipe.jpg), [bars/mallet](evidence/bars.jpg), [cyan cradle wheel](evidence/frames.jpg), [tiles](evidence/tiles.jpg), [ramps/rungs](evidence/ramps.jpg), [tunnels](evidence/gates.jpg), [hot-air balloon](evidence/balloons.jpg), [Door slabs](evidence/doors.jpg). The historically named “halfpipe.jpg” capture actually disproves that guess at obstacle20/21. Cameras are recorded in [cameras.json](evidence/cameras.json).

## Complete root inventory

Attached behaviour is **none for every row**. “Kit/role” is current assigned course behaviour or a clearly labelled candidate, not an attached source script. All imported forward axes are +Y as explained above; logical route axes must come from sockets.

| Source root | Identity | Upright bounds X×Y×Z | Parts | PΔ X,Y,Z | Kit/role | Used by current course |
|---|---|---:|---:|---:|---|---|
| TV_001 | Named scenery/prop; exact gameplay role unverified | 242.2 × 234.9 × 242.2 | 1 | 0, -45.2, 0 | Static / out of scope | — |
| air_balloon_001 | Hot-air balloon (basket attached); not a beach ball | 65.3 × 93.0 × 66.2 | 1 | 0, -46.5, 0 | Dressing | — |
| air_balloon_002 | Small balloon on a string | 14.0 × 65.8 × 14.0 | 1 | 0, -32.9, -0.2 | Dressing | — |
| airship_001 | Striped airship / propellers | 52.4 × 64.9 × 99.2 | 5 | 0, 6.4, -1.0 | Dressing | — |
| apple_001 | Collectible/pickup silhouette; no Splashdown system | 7.3 × 7.8 × 7.1 | 1 | -0.1, -0.3, 0 | Out of scope | — |
| arc_001 | Curved track colour/sector variant | 515.0 × 10.2 × 162.9 | 1 | -0.4, 0, -285.2 | Static | SummitSplash |
| arc_002 | Curved track colour/sector variant | 342.9 × 10.2 × 112.9 | 1 | 0.1, 0, -310.1 | Static | SummitSplash |
| arc_003 | Curved track colour/sector variant | 342.9 × 10.2 × 113.2 | 1 | -0.5, 0, -310.0 | Static | SummitSplash |
| arc_004 | Curved track colour/sector variant | 278.2 × 10.2 × 101.2 | 1 | 0.2, 0, -316.0 | Static | SummitSplash |
| arch_001 | Small inflatable arch/hurdle variant | 18.9 × 9.5 × 7.8 | 1 | 0, -2.1, 0 | Static | — |
| arch_002 | Small inflatable arch/hurdle variant | 18.9 × 9.5 × 7.8 | 1 | 0, -2.1, 0 | Static | — |
| arch_003 | Small inflatable arch/hurdle variant | 29.5 × 12.8 × 7.8 | 1 | 0, 0.3, 0 | Static | — |
| arch_004 | Inflatable arch tunnel colourway | 57.1 × 40.8 × 89.9 | 1 | 0, -20.4, 0 | Static | — |
| arch_005 | Inflatable arch tunnel colourway | 57.1 × 40.8 × 89.9 | 1 | 0, -20.4, 0 | Static | — |
| arch_006 | Inflatable arch tunnel colourway | 57.1 × 40.8 × 89.9 | 1 | 0, -20.4, 0 | Static | — |
| ball_001 | Striped beach ball; enlarge uniformly for large version | 9.2 × 9.3 × 9.3 | 1 | 0, 0, 0 | BeachBall (legacy prefix) | BumperBay, WhirlPool |
| banana_001 | Banana inflatable | 17.0 × 29.8 × 49.2 | 1 | -0.3, -4.5, 2.2 | Static | — |
| battle_stadium_002 | Battle Stadium branding/object — excluded | 304.7 × 34.3 × 16.4 | 1 | 0, -124.5, -723.3 | Other mode | — |
| berries_001 | Collectible/pickup silhouette; no Splashdown system | 9.1 × 10.2 × 5.1 | 1 | 0, -1.2, 0 | Out of scope | — |
| bomb_001 | Collectible/pickup silhouette; no Splashdown system | 7.6 × 10.5 × 7.6 | 1 | 0, -2.1, 0 | Out of scope | — |
| box_001 | Stackable small cuboid dressing | 15.0 × 15.3 × 15.0 | 1 | 0, -7.7, 0 | Static | — |
| box_002 | Stackable small cuboid dressing | 15.0 × 16.4 × 15.0 | 1 | 0, -8.2, 0 | Static | — |
| box_003 | Green-top raised block / height connector | 51.2 × 25.4 × 55.4 | 1 | 0, -12.7, 0.1 | Static | — |
| box_004 | Coloured bar/foam block; socket profile unverified | 28.0 × 4.7 × 9.3 | 1 | 0, 0, 0 | Static / identify | — |
| box_005 | Coloured bar/foam block; socket profile unverified | 55.9 × 4.7 × 9.3 | 1 | 0, 0, 0 | Static / identify | — |
| box_006 | Coloured bar/foam block; socket profile unverified | 83.9 × 4.7 × 9.3 | 1 | 0, 0, 0 | Static / identify | — |
| box_007 | Coloured bar/foam block; socket profile unverified | 9.3 × 18.6 × 9.3 | 1 | 0, -9.3, 0 | Static / identify | — |
| box_008 | Coloured bar/foam block; socket profile unverified | 83.9 × 4.7 × 9.3 | 1 | 0, 0, 0 | Static / identify | — |
| box_009 | Coloured bar/foam block; socket profile unverified | 55.9 × 4.7 × 9.3 | 1 | 0, 0, 0 | Static / identify | — |
| box_010 | Coloured bar/foam block; socket profile unverified | 28.0 × 4.7 × 9.3 | 1 | 0, 0, 0 | Static / identify | — |
| box_011 | Green-top zigzag/slope block | 153.1 × 53.9 × 60.3 | 1 | 2.2, -26.9, 2.4 | Static climb | — |
| box_012 | Green-top raised block / height connector | 51.2 × 53.9 × 55.4 | 1 | 0, -26.9, 0.1 | Static | — |
| box_013 | Green-top zigzag/slope block | 153.1 × 53.9 × 60.3 | 1 | -2.2, -26.9, 2.4 | Static climb | — |
| bridge_001 | Green ribbed arched ramp | 116.7 × 24.2 × 33.5 | 1 | 0, -12.1, -0.1 | Static / Rotor rock in BumperBay | BumperBay |
| bridge_002 | Orange ribbed arched ramp | 116.7 × 24.2 × 33.5 | 1 | 0, -12.1, -0.1 | Static | — |
| bridge_003 | Broad checker/bridge segment; exact socket profile unverified | 224.8 × 9.3 × 139.1 | 1 | 0, 0, -0.8 | Static / identify | — |
| cannon_001 | Named scenery/prop; exact gameplay role unverified | 35.0 × 22.4 × 39.8 | 2 | 0, 0, 0 | Static / out of scope | — |
| canopy_001 | Named scenery/prop; exact gameplay role unverified | 2048.0 × 232.6 × 578.1 | 1 | 0, -485.7, -1562.1 | Static / out of scope | — |
| car_place_001 | Named scenery/prop; exact gameplay role unverified | 22.9 × 0 × 15.8 | 1 | 0, 0, 0.6 | Static / out of scope | — |
| checkpoint_001 | Checkpoint arch | 45.6 × 34.9 × 9.9 | 1 | 0, -17.5, 0 | Static + separate race marker | BumperBay, DiscJockey, Downpour, KnockKnock, SummitSplash, TiltTrip, WhirlPool |
| checkpoint_002 | Checkpoint colour variant | 44.3 × 28.7 × 7.3 | 1 | 0, -14.4, 0 | Static | — |
| checkpoint_003 | Checkpoint colour variant | 44.3 × 28.7 × 7.3 | 1 | 0, -14.4, 0 | Static | — |
| coin_001 | Collectible/pickup silhouette; no Splashdown system | 9.5 × 9.5 × 2.6 | 1 | 0, 0, 0 | Out of scope | — |
| color_box_001 | Individual rainbow foam tile | 18.6 × 9.3 × 28.0 | 1 | 0, 0, 0 | Static today; FallingTile candidate | BumperBay |
| color_box_002 | Individual rainbow foam tile | 18.6 × 9.3 × 28.0 | 1 | 0, 0, 0 | Static today; FallingTile candidate | BumperBay |
| color_box_003 | Individual rainbow foam tile | 18.6 × 9.3 × 28.0 | 1 | 0, 0, 0 | Static today; FallingTile candidate | BumperBay |
| color_box_004 | Individual rainbow foam tile | 18.6 × 9.3 × 28.0 | 1 | 0, 0, 0 | Static today; FallingTile candidate | BumperBay |
| color_box_005 | Individual rainbow foam tile | 18.6 × 9.3 × 28.0 | 1 | 0, 0, 0 | Static today; FallingTile candidate | — |
| color_box_006 | Individual rainbow foam tile | 18.6 × 9.3 × 28.0 | 1 | 0, 0, 0 | Static today; FallingTile candidate | — |
| color_box_007 | Individual rainbow foam tile | 18.6 × 9.3 × 28.0 | 1 | 0, 0, 0 | Static today; FallingTile candidate | — |
| color_box_008 | Individual rainbow foam tile | 18.6 × 9.3 × 28.0 | 1 | 0, 0, 0 | Static today; FallingTile candidate | — |
| crown_001 | Collectible/pickup silhouette; no Splashdown system | 12.4 × 8.8 × 14.2 | 1 | 0, -2.6, 0 | Out of scope | — |
| diamond_001 | Collectible/pickup silhouette; no Splashdown system | 8.0 × 7.2 × 8.0 | 1 | 0, 1.5, 0 | Out of scope | — |
| door_001 | Large doorway/tunnel decoration; not Door Dash slab | 98.0 × 52.3 × 127.0 | 1 | 0, -157.6, -856.4 | Static / profile unverified | — |
| door_002 | Cross-framed Door Dash slab colourway | 75.2 × 45.8 × 6.3 | 1 | 0, -22.9, 0 | DoorRow / DoorIndex | KnockKnock |
| door_003 | Cross-framed Door Dash slab colourway | 75.2 × 45.8 × 6.3 | 1 | 0, -22.9, 0 | DoorRow / DoorIndex | KnockKnock |
| door_004 | Cross-framed Door Dash slab colourway | 75.2 × 45.8 × 6.3 | 1 | 0, -22.9, 0 | DoorRow / DoorIndex | KnockKnock |
| door_005 | Cross-framed Door Dash slab colourway | 75.2 × 45.8 × 6.3 | 1 | 0, -22.9, 0 | DoorRow / DoorIndex | KnockKnock |
| door_006 | Cross-framed Door Dash slab colourway | 75.2 × 45.8 × 6.3 | 1 | 0, -22.9, 0 | DoorRow / DoorIndex | KnockKnock |
| door_007 | Cross-framed Door Dash slab colourway | 75.2 × 45.8 × 6.3 | 1 | 0, -22.9, 0 | DoorRow / DoorIndex | KnockKnock |
| drone_001 | Named scenery/prop; exact gameplay role unverified | 61.1 × 38.1 × 15.9 | 7 | -0.5, 11.3, -0.5 | Static / out of scope | — |
| dynamite_001 | Collectible/pickup silhouette; no Splashdown system | 2.2 × 9.7 × 2.2 | 1 | 0, -4.9, 0 | Out of scope | — |
| dynamite_002 | Collectible/pickup silhouette; no Splashdown system | 11.0 × 4.1 × 4.5 | 1 | 1.6, -2.0, -0.1 | Out of scope | — |
| fence_001 | Grey curved guard rail | 332.8 × 28.8 × 36.6 | 1 | -0.1, -14.4, 15.4 | Static enclosure | — |
| finish_001 | Checkered finish strip (near-zero thickness) | 189.0 × 0 × 18.6 | 1 | 0, 0, 0 | Static | BumperBay, DiscJockey, Downpour, KnockKnock, SummitSplash, TiltTrip, WhirlPool |
| finish_002 | Yellow traffic-light finish arch | 225.9 × 74.4 × 33.4 | 1 | 0, -37.2, 4.4 | Static | BumperBay, DiscJockey, Downpour, KnockKnock, SummitSplash, TiltTrip, WhirlPool |
| firework_001 | Named scenery/prop; exact gameplay role unverified | 34.8 × 135.8 × 31.5 | 1 | 1.5, -67.9, -0.5 | Static / out of scope | — |
| flag_001 | Small flag | 5.1 × 22.1 × 2.6 | 1 | 1.2, -11.1, 0 | Dressing | — |
| flag_002 | Tall pennant pole | 53.9 × 152.3 × 14.7 | 1 | 19.6, -76.2, 0 | Dressing | BumperBay, DiscJockey, Downpour, KnockKnock, SummitSplash, TiltTrip, WhirlPool |
| foam_finger_001 | Named scenery/prop; exact gameplay role unverified | 17.8 × 33.6 × 2.5 | 1 | -1.1, 1.7, 0 | Static / out of scope | — |
| heart_001 | Collectible/pickup silhouette; no Splashdown system | 10.7 × 9.3 × 4.9 | 1 | 0, 0.7, 0 | Out of scope | — |
| holder_001 | Named scenery/prop; exact gameplay role unverified | 94.4 × 306.2 × 414.3 | 1 | 0, -410.3, -1502.8 | Static / out of scope | — |
| key_001 | Collectible/pickup silhouette; no Splashdown system | 14.9 × 7.4 × 1.9 | 1 | 0.6, -0.2, 0 | Out of scope | — |
| key_002 | Collectible/pickup silhouette; no Splashdown system | 15.8 × 7.9 × 1.5 | 1 | 0.8, -0.3, 0 | Out of scope | — |
| lifebuoy_001 | Named scenery/prop; exact gameplay role unverified | 6.0 × 1.2 × 6.0 | 1 | 0, 0, 0 | Static / out of scope | — |
| net_001 | Named scenery/prop; exact gameplay role unverified | 90.6 × 30.7 × 2.4 | 1 | 0, 0, 0 | Static / out of scope | — |
| obstacle_10_001 | Small ribbed pink/yellow cylinder stub | 6.1 × 14.0 × 6.1 | 1 | 0, -7.0, 0 | Static; log-roll candidate | — |
| obstacle_11_001 | Long opposing-chevron plank on yellow axle | 38.7 × 4.8 × 75.9 | 2 | 0, 0, 0 | Static today; Seesaw candidate | — |
| obstacle_12_001 | Four-arm pink cross spinner | 58.1 × 12.3 × 58.1 | 1 | 0.1, -6.2, -0.1 | Static today; Rotor+Shove candidate | — |
| obstacle_13_001 | Yellow striped-ring carousel / canopy | 52.6 × 36.6 × 52.6 | 2 | 0, -18.3, 0 | Static today; Rotor+Carries candidate | — |
| obstacle_14_001 | Small orange-rim disc, flat central button | 39.6 × 5.1 × 39.6 | 2 | 0, 0, 0 | Disc legacy; Origin rotation in course | DiscJockey |
| obstacle_15_001 | Yellow-rim disc with red centre ball | 66.5 × 14.4 × 66.5 | 2 | 0, 0, 0 | Origin rotation in course | DiscJockey |
| obstacle_16_001 | Blue missing-wedge pizza platform, green hub | 77.8 × 6.3 × 72.4 | 2 | 0, 0.2, -2.8 | Origin rotation in course | DiscJockey |
| obstacle_18_001 | Green cuboid yellow-button bumper | 14.3 × 13.4 × 14.3 | 1 | 0, -6.7, 0 | Bumper | BumperBay, Downpour, WhirlPool |
| obstacle_19_001 | Pink triangular yellow-button bumper | 19.9 × 12.8 × 21.2 | 1 | -2.9, -6.4, 0 | Bumper | BumperBay, Downpour, SummitSplash, TiltTrip, WhirlPool |
| obstacle_1_001 | Small pink mallet on striped post, single mesh | 19.2 × 11.9 × 13.2 | 1 | 7.1, -5.9, -0.3 | Bumper in TiltTrip; Rotor preset candidate | TiltTrip |
| obstacle_20_001 | Blue convex hump with yellow straps | 17.8 × 10.5 × 10.6 | 1 | 0, -5.2, -0.4 | Static (helper calls it hump) | WhirlPool |
| obstacle_21_001 | Plain blue convex hump | 17.8 × 10.5 × 10.6 | 1 | 0, -5.2, -0.4 | Static (helper calls it hump) | WhirlPool |
| obstacle_22_001 | Yellow/blue spring piston with red head | 16.5 × 16.5 × 44.2 | 3 | 0, 0, 10.4 | Static today; piston profile candidate | — |
| obstacle_23_001 | Big red sphere on blue pole | 13.7 × 45.7 × 13.7 | 2 | 0, -22.8, 0 | Static today; BigBall candidate | — |
| obstacle_24_001 | Pink paddle wheel with four cyan half-pipe cradles | 59.8 × 48.0 × 43.9 | 5 | 0, 1.4, 0 | Rotor X spin + Shove; NOT legacy SwingPanel | Downpour, WhirlPool |
| obstacle_25_001 | Yellow-topped narrow pink beam on a pedestal | 9.3 × 27.1 × 46.6 | 2 | 0, -13.6, 0 | Y-spin windmill in old courses; Seesaw candidate | Downpour, SummitSplash, WhirlPool |
| obstacle_26_001 | Pink-rim disc with purple centre ball | 66.5 × 14.4 × 66.5 | 2 | 0, 0, 0 | Static today; same diameter as15 | — |
| obstacle_27_001 | Two-arm pink sweep bar on striped hub | 6.2 × 12.3 × 58.1 | 1 | 0, -6.2, -0.1 | Static today; Rotor+Shove candidate | — |
| obstacle_2_001 | Spiked cyan/pink roller + frame | 49.5 × 36.4 × 12.3 | 2 | 0, 14.7, 0 | Rotor spin + Shove | BumperBay |
| obstacle_3_001 | Large round hammer/axle on pillar | 18.5 × 34.4 × 4.4 | 2 | 0, 17.2, 0 | Rotor rock + Shove | BumperBay |
| obstacle_4_001 | Small mallet/pendulum variant on pillar | 13.7 × 35.0 × 9.8 | 2 | 0, 15.2, 0 | Rotor rock + Shove | Downpour, TiltTrip |
| obstacle_5_001 | Spiked mace and chain (11 pieces) | 10.0 × 27.8 × 11.5 | 11 | 0, 13.9, 0 | Rotor rock + Shove | SummitSplash |
| obstacle_6_001 | Pink bar / dumbbell spinner on striped posts | 38.4 × 11.1 × 5.0 | 1 | 0.1, -5.5, 0 | Spinner legacy; course Rotor+Shove | WhirlPool |
| obstacle_7_001 | Rail with sliding cyan-edged panel assembly | 67.4 × 11.4 × 5.1 | 2 | 0, -5.4, 0 | Rotor slide + Shove | KnockKnock |
| obstacle_8_001 | Flat square swing flap with axle and centre target | 41.1 × 5.5 × 40.0 | 2 | 0, 0, 17.3 | SwingPanel legacy; course Rotor rock | KnockKnock |
| obstacle_9_001 | Single chevron panel / belt | 28.0 × 1.7 × 55.9 | 1 | 0, -0.9, 0 | Static today; Conveyor candidate | BumperBay, Downpour, KnockKnock, WhirlPool |
| octagon_001 | Raised pink/purple octagon plaza, yellow top | 217.4 × 84.0 × 217.4 | 1 | 0, -42.0, 0 | Static | — |
| octagon_002 | Large blue flat octagon platform | 309.8 × 11.2 × 309.8 | 1 | 0, 0, 0 | Static | Downpour, SummitSplash, TiltTrip, WhirlPool |
| platform_001 | Blue-top rectangular slab; trim colour variant | 70.1 × 28.5 × 89.9 | 1 | 0, -14.3, 0 | Static | BumperBay, WhirlPool |
| platform_002 | Blue-top rectangular slab; trim colour variant | 70.1 × 28.5 × 89.9 | 1 | 0, -14.3, 0 | Static | Downpour, KnockKnock |
| platform_003 | Blue-top rectangular slab; trim colour variant | 70.1 × 28.5 × 89.9 | 1 | 0, -14.3, 0 | Static | DiscJockey, TiltTrip |
| podium_001 | Large colourful drum/barrel platform | 94.1 × 97.3 × 94.1 | 1 | 0, -48.7, 0 | Static | — |
| podium_002 | Large colourful drum/barrel platform | 94.1 × 97.3 × 94.1 | 1 | 0, -48.7, 0 | Static | — |
| podium_003 | Large colourful drum/barrel platform | 94.1 × 97.3 × 94.1 | 1 | 0, -48.7, 0 | Static | — |
| podium_004 | Large colourful drum/barrel platform | 94.1 × 97.3 × 94.1 | 1 | 0, -48.7, 0 | Static | — |
| podium_005 | Large colourful drum/barrel platform | 94.1 × 97.3 × 94.1 | 1 | 0, -48.7, 0 | Static | — |
| podium_006 | Large colourful drum/barrel platform | 94.1 × 97.3 × 94.1 | 1 | 0, -48.7, 0 | Static | — |
| podium_007 | Large colourful drum/barrel platform | 94.1 × 97.3 × 94.1 | 1 | 0, -48.7, 0 | Static | — |
| propeller_trampoline_1_001 | Blue caged fan, purple ring + blade child | 35.4 × 22.6 × 35.4 | 2 | 0, 0.7, 0 | Fan / FanBlade | WhirlPool |
| ring_001 | Small gold ring; pickup silhouette | 10.0 × 10.0 × 1.3 | 1 | 0, 0, 0 | Out of scope unless static hoop | — |
| ring_002 | Large hoop | 29.3 × 29.3 × 5.8 | 1 | 0, 0, 0 | Static | — |
| road_001 | Green-framed yellow rung bridge | 29.5 × 6.2 × 64.7 | 1 | 0, 0, -0.2 | Static | SummitSplash |
| road_002 | Pink-framed yellow rung bridge | 29.5 × 6.2 × 64.7 | 1 | 0, 0, -0.2 | Static | — |
| slide_001 | Inflatable slide | 34.0 × 56.8 × 89.7 | 1 | 0, -28.4, 0 | Static today; friction tuning candidate | Downpour |
| speakers_001 | Named scenery/prop; exact gameplay role unverified | 199.7 × 474.8 × 159.0 | 1 | -0.6, -195.1, -41.7 | Static / out of scope | — |
| speakers_002 | Named scenery/prop; exact gameplay role unverified | 496.9 × 201.9 × 122.9 | 1 | 0, -58.6, -59.8 | Static / out of scope | — |
| spotlight_001 | Named scenery/prop; exact gameplay role unverified | 21.7 × 36.0 × 24.3 | 1 | 0, 18.0, -4.7 | Static / out of scope | — |
| spotlight_002 | Named scenery/prop; exact gameplay role unverified | 21.7 × 36.0 × 24.3 | 1 | 0, 18.0, -4.7 | Static / out of scope | — |
| spotlight_003 | Named scenery/prop; exact gameplay role unverified | 21.7 × 36.0 × 24.3 | 1 | 0, 18.0, -4.7 | Static / out of scope | — |
| star_001 | Collectible/pickup silhouette; no Splashdown system | 12.0 × 11.4 × 2.3 | 1 | 0, -0.6, 0 | Out of scope | — |
| star_002 | Collectible/pickup silhouette; no Splashdown system | 11.1 × 10.6 × 2.5 | 1 | 0, -0.5, 0 | Out of scope | — |
| tower_001 | Small column/cap dressing; exact silhouette not catalogued | 7.2 × 9.5 × 7.2 | 1 | 0, -4.7, 0 | Static / identify | BumperBay, DiscJockey, KnockKnock, TiltTrip, WhirlPool |
| tower_002 | Small column/cap dressing; exact silhouette not catalogued | 4.9 × 14.0 × 4.9 | 1 | 0, -7.0, 0 | Static / identify | — |
| tower_003 | Small column/cap dressing; exact silhouette not catalogued | 4.9 × 14.0 × 4.9 | 1 | 0, -7.0, 0 | Static / identify | — |
| tower_004 | Small column/cap dressing; exact silhouette not catalogued | 2.7 × 14.0 × 2.7 | 1 | 0, -7.0, 0 | Static / identify | — |
| tower_005 | Small column/cap dressing; exact silhouette not catalogued | 7.2 × 9.5 × 7.2 | 1 | 0, -4.7, 0 | Static / identify | — |
| tower_006 | Small column/cap dressing; exact silhouette not catalogued | 7.2 × 9.5 × 7.2 | 1 | 0, -4.7, 0 | Static / identify | — |
| tower_007 | Small column/cap dressing; exact silhouette not catalogued | 7.2 × 9.5 × 7.2 | 1 | 0, -4.7, 0 | Static / identify | — |
| tower_008 | Small column/cap dressing; exact silhouette not catalogued | 4.9 × 14.0 × 4.9 | 1 | 0, -7.0, 0 | Static / identify | — |
| tower_009 | Small column/cap dressing; exact silhouette not catalogued | 4.9 × 13.9 × 4.9 | 1 | 0, -6.9, 0 | Static / identify | — |
| tower_010 | Small column/cap dressing; exact silhouette not catalogued | 4.9 × 14.0 × 4.9 | 1 | 0, -7.0, 0 | Static / identify | — |
| tower_011 | Small column/cap dressing; exact silhouette not catalogued | 4.0 × 14.0 × 4.0 | 1 | 0, -7.0, 0 | Static / identify | — |
| tower_012 | Small column/cap dressing; exact silhouette not catalogued | 13.5 × 14.2 × 14.3 | 1 | 0, -7.1, 0 | Static / identify | — |
| tower_013 | Stacked cylinder/column block near hazard display | 15.0 × 15.3 × 15.0 | 1 | 0, -7.6, 0 | Static | — |
| tower_014 | Stacked cylinder/column block near hazard display | 15.0 × 15.0 × 15.0 | 1 | 0, -7.5, 0 | Static | — |
| tower_015 | Small column/cap dressing; exact silhouette not catalogued | 13.5 × 14.2 × 14.3 | 1 | 0, -7.1, 0 | Static / identify | — |
| tower_016 | Tall stacked tower dressing | 82.6 × 158.9 × 80.8 | 1 | 0, -79.4, 0 | Static | — |
| tower_palm_001 | Small column/cap dressing; exact silhouette not catalogued | 12.0 × 20.2 × 12.0 | 1 | 0, -10.1, 0 | Static / identify | — |
| tower_top_001 | Small column/cap dressing; exact silhouette not catalogued | 7.1 × 8.1 × 7.1 | 1 | 0, -3.2, 0 | Static / identify | — |
| tower_top_002 | Small column/cap dressing; exact silhouette not catalogued | 5.7 × 12.0 × 6.4 | 1 | 0, -6.0, 0.3 | Static / identify | — |
| tower_top_003 | Small column/cap dressing; exact silhouette not catalogued | 5.3 × 9.1 × 5.3 | 1 | 0, -4.6, 0 | Static / identify | — |
| trampoline_1_001 | Low round pad, frame + centre | 11.6 × 3.9 × 11.6 | 2 | 0, -2.0, 0 | JumpPad convention candidate | — |
| trampoline_2_001 | Tall-base round pad, frame + centre | 12.4 × 12.0 × 12.4 | 2 | 0, 2.0, 0 | JumpPad convention candidate | — |
| trampoline_3_001 | Striped-ring trampoline, grey centre | 27.0 × 5.0 × 27.0 | 2 | 0, -2.5, 0 | JumpPad (renamed Outer/Inner) | DiscJockey |
| trampoline_4_001 | Tall wider round pad, frame + centre | 14.9 × 13.3 × 14.9 | 2 | 0, 3.0, 0 | JumpPad convention candidate | — |
| trampoline_5_001 | Low wider round pad; child named trampoline_6_001 | 14.2 × 3.5 × 14.2 | 2 | 0, -1.8, 0 | JumpPad convention candidate | — |
| unicorn_001 | Unicorn inflatable | 22.6 × 37.9 × 22.8 | 1 | 0, -18.9, -4.7 | Static dressing | — |
| wall_001 | Tall inflatable wall/endcap | 18.9 × 22.9 × 7.7 | 1 | 0, -11.5, 0 | Static | KnockKnock |
| wall_002 | Tall inflatable wall/endcap | 18.9 × 22.9 × 7.7 | 1 | 0, -11.5, 0 | Static | — |
| wall_003 | Long rail/bar array colourway | 55.9 × 21.0 × 6.5 | 1 | 0, -10.5, 0 | Static | SummitSplash |
| wall_004 | Low hurdle/rail colourway | 28.0 × 7.0 × 2.6 | 1 | 0, -3.5, 0 | Static; too low for anti-skip alone | BumperBay, DiscJockey, KnockKnock, TiltTrip, WhirlPool |
| wall_006 | Low hurdle/rail colourway | 28.0 × 7.0 × 2.6 | 1 | 0, -3.5, 0 | Static; too low for anti-skip alone | — |
| wall_007 | Low hurdle/rail colourway | 28.0 × 7.0 × 2.6 | 1 | 0, -3.5, 0 | Static; too low for anti-skip alone | — |
| wall_008 | Low hurdle/rail colourway | 28.0 × 7.0 × 2.6 | 1 | 0, -3.5, 0 | Static; too low for anti-skip alone | — |
| wall_009 | Long rail/bar array colourway | 55.9 × 21.0 × 6.5 | 1 | 0, -10.5, 0 | Static | — |
| wall_010 | Long rail/bar array colourway | 55.9 × 21.0 × 6.5 | 1 | 0, -10.5, 0 | Static | — |
| wall_011 | Long rail/bar array colourway | 55.9 × 21.5 × 6.5 | 1 | 0, -10.8, 0 | Static | — |
| wall_012 | Long rail/bar array colourway | 55.9 × 21.5 × 6.5 | 1 | 0, -10.8, 0 | Static | — |
| wall_013 | Long rail/bar array colourway | 55.9 × 21.5 × 6.5 | 1 | 0, -10.8, 0 | Static | — |
| wall_014 | Long rail/bar array colourway | 55.9 × 21.0 × 6.5 | 1 | 0, -10.5, 0 | Static | — |
| wall_015 | Long rail/bar array colourway | 55.9 × 21.5 × 6.5 | 1 | 0, -10.8, 0 | Static | — |
| water_platform_001 | Square stacked foam/platform base colourway | 37.3 × 9.4 × 37.3 | 1 | 0, -4.7, 0 | Static | Downpour, KnockKnock |
| water_platform_002 | Square stacked foam/platform base colourway | 37.3 × 9.4 × 37.3 | 1 | 0, -4.7, 0 | Static | — |
| water_platform_003 | Square stacked foam/platform base colourway | 37.3 × 9.4 × 37.3 | 1 | 0, -4.7, 0 | Static | BumperBay, DiscJockey, Downpour, SummitSplash, TiltTrip, WhirlPool |
| water_platform_partition_001 | Stacked square middle pad | 23.7 × 5.5 × 23.7 | 1 | 0, -0.3, 0 | Static | — |
| water_platform_partition_002 | Stacked square middle pad | 23.7 × 5.5 × 23.7 | 1 | 0, -0.3, 0 | Static | — |
| water_platform_partition_003 | Stacked square middle pad | 23.7 × 5.5 × 23.7 | 1 | 0, -0.3, 0 | Static | — |
| water_platform_tube_001 | Cylinder stub on square-pad assembly | 15.9 × 16.2 × 15.9 | 1 | 0, -8.1, 0 | Static | — |
| water_platform_tube_002 | Cylinder stub on square-pad assembly | 15.9 × 16.2 × 15.9 | 1 | 0, -8.1, 0 | Static | — |
| water_platform_tube_003 | Cylinder stub on square-pad assembly | 15.9 × 16.2 × 15.9 | 1 | 0, -8.1, 0 | Static | — |

## Remaining identification and integration risks

- Named scenery rows marked “identify/unverified” are enumerated but their gameplay role/socket profile is not assumed. They remain unused until inspected; this does not block the identified hazard set.
- Imported pivots often sit at axle/ground/origin locations outside the bounds; do not bottom-snap moving children independently. Preserve parent/child offsets while defining the mount and mechanism axle separately.
- There are **no authored entry/exit Attachments**. A small reviewed socket manifest is required; bounds alone are not enough for curved ramps, half-pipes, mesh holes and the spiral arcs.
- Default source scale is enormous for some scenery (canopy width2048); the new 600-stud bound applies after approved uniform scale, including corners. The original source display is outside the arena and is not itself a valid course footprint.
- Source anchor state must not propagate to clones. All gameplay geometry is anchored except deliberate server-owned beach balls; a falling tile can be moved/hidden deterministically while remaining anchored.
- MeshId reuse proves source-family coverage, not mechanic coverage. Per-course checks must count behaviour-bearing roots and resolve visual mounts/supports, not every descendant mesh.
