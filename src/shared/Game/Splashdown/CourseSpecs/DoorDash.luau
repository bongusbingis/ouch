-- Name: DoorDash.luau
-- Author: Jack C.
-- Description: Declarative spec for Door Dash (HANDOFF.md section 7.3): a Chute layout -- one wide five-channel door corridor, a hairpin at the route's 60% mark, and a second straight run back -- carrying three real 5-door rows at quota 2, counterbelts under a paddle wheel, a launch chain over a foam catch basin, and a mace gauntlet before one readable finishing sweep. Beat length targets are the section 7.3 targets, unchanged, because the set-wide route length is fixed at 880 measured studs and this build measures inside a stud of it (docs/splashdown/03-overrides.md). Every scale, speed and socket figure traces to AssetManifest or to the measured evidence cited in docs/splashdown/courses/door-dash.md.
-- Created: 2026-09-16

--!strict

local CourseBuilder = require(script.Parent.Parent.CourseBuilder)

-- HANDOFF 5.2 guide: "One wide straight run, one hairpin, a second wide straight
-- run ... The hairpin sits at roughly 55-60% of the route (between beats 03 and
-- 04). Both runs, corners included, stay inside the 300 radius; the runs are
-- separated so that no launch in 04 can reach the other run."
--
-- Run length 482.35 is not a round number by choice: it is exactly the route the
-- beats below consume on the first run plus one clean 26.4-stud filler slab and
-- the corner's own 13.18 studs of approach, so the builder's fill never has to
-- invent a sliver to reach the vertex. LANE_PITCH is the whole cross segment and
-- therefore the separation between the two runs.
local RUN_LENGTH = 482.35
local LANE_PITCH = 98
local RUN_Z = 56

-- box_011 is a measured descending ramp: at scale s it travels 138 * s studs and
-- drops 28.5 * s. Entered from its low end (Reversed) it is the only climb the
-- kit can make, exactly as the pilot documented. slide_001 drops 51.8 * s over
-- 25 * s of travel, which is how beat 02 spends 12 studs of descent in under six
-- studs of route.
local RAMP_6 = 0.2105
local RAMP_12 = 0.4211
local SLIDE_12 = 0.2317

-- The hammer hangs. obstacle_3_001 is an axle housing with its head suspended a
-- measured 8.925 studs BENEATH it at scale 0.6, so the original OffsetUp-0 mounting
-- swept the head under the floor: measured on the promoted `8c00a748` template the
-- head spanned Y 5.694..24.456 under a deck at Y 23.997, putting only its top 0.46
-- studs at deck level and never reaching a runner at all. This is the same defect
-- Ball Barrage carried and is fixed the same way, from the same measurement.
-- HANDOFF 8.3 exempts a suspended pendulum from the support rule, which is what
-- this course's own maces already rely on at OffsetUp 21.
--
-- The height comes from the SWING, not the rest pose. CoursePresets clears every
-- display pivot, so the head rocks about its own centre through +-55 degrees about
-- the route axis and its vertical half-extent is halfY*cos(t) + halfX*sin(t), whose
-- maximum over the amplitude is hypot(halfX, halfY) = 10.903 studs at 30.7 degrees.
-- Hanging the head so that maximum clears the deck by 0.6 studs keeps it out of the
-- floor at mid-swing and leaves the resting head bottom 2.12 studs up, inside a
-- runner's body band. Across the 18.22-stud Floor09 slab the head spans +-5.558 at
-- rest and a measured +-10.872 at full swing, so it seals the lane on the strike and
-- leaves 3.55 studs of corridor on each side between strikes.
local HAMMER_LARGE_UP = 8.925 + math.sqrt((11.115 / 2) ^ 2 + (18.761 / 2) ^ 2) + 0.6

-- The door corridor. Channels are uniformly scaled platform slabs 19.62 studs
-- wide, so no single channel can hold the 24x24 breather square section 8.4
-- forbids, and they sit at 0 / -1 / -2 studs from the centre outward: the crown
-- breaks the corridor into five readable lanes without cutting holes in the floor
-- that a 30-racer crush would fall through. The 98.1-stud corridor also sets how
-- close it gets to the second run: its outer edge stops 31.9 studs short of the
-- finish plaza, outside the measured 22-stud jump envelope.
--
-- A door is scaled so that one slab is exactly one channel wide. The first build
-- used wider slabs, which overhung the corridor by 11 studs a side -- and the
-- outermost door's opening then led half over open water, which a scripted trial
-- found the hard way by walking through it and falling off. One door per channel,
-- edge to edge, spans the corridor exactly: no overhang, no gap, and no opening
-- that leads off the deck.
local CHANNEL = 0.28
local CHANNEL_WIDTH = 70.06987762451172 * CHANNEL
local DOOR = CHANNEL * 70.06987762451172 / 75.15200042724609
local DOOR_WIDTH = CHANNEL_WIDTH

-- Launch decks in beat 04. Deliberately small: section 7.3's "successive short
-- launches" are a precision chain, and the pilot's own launch landings are the
-- same 0.15 slab.
local LAUNCH_DECK = 0.15

-- Roof slabs over the door section, rotated 90 degrees so a slab's long axis
-- spans the corridor: four of them are 98.1 studs across, exactly the corridor's
-- width, and each is only 19.5 deep, which keeps every level band of roof under
-- the 24-stud breather square as well. The width matters twice over: a wider
-- roof overhung the corridor by 25 studs, and the cut-set audit found a racer
-- could climb it and jump from that overhang onto the second run, skipping five
-- gates at once.
local ROOF = 0.2786
local ROOF_PITCH = 88 * ROOF

local DoorDash: CourseBuilder.CourseSpec = {
	Version = 1,
	Id = "DoorDash",
	DisplayName = "Door Dash",
	-- HANDOFF 7.3: "Headline: three Door Dash rows, not fifteen identical
	-- straight-line gates."
	Headline = "Door",
	Difficulty = 3,
	ParSeconds = 75,
	CapSeconds = 180,
	CloseWindowSeconds = 60,
	Layout = {
		Kind = "Chute",
		LanePitch = LANE_PITCH,
		BoundsRadius = 300,
		LiquidY = -20,
		Guide = {
			Vector3.new(-RUN_LENGTH / 2, 0, RUN_Z),
			Vector3.new(RUN_LENGTH / 2, 0, RUN_Z),
			Vector3.new(RUN_LENGTH / 2, 0, RUN_Z - LANE_PITCH),
			Vector3.new(-RUN_LENGTH / 2, 0, RUN_Z - LANE_PITCH),
		},
		Chute = {
			-- Measured at the hairpin's midpoint -- the far end of the cross run,
			-- where the route actually turns around -- because the cross segment is a
			-- lane pitch long and the entry and exit fractions straddle it.
			HairpinFractionMin = 0.55,
			HairpinFractionMax = 0.62,
			MinRunToPitchRatio = 2,
		},
		Corner = { Source = "platform_002", Scale = 0.3 },
		Fill = { Source = "platform_002", Scale = 0.3 },
	},
	-- HANDOFF 7.3: "StartY 18."
	Start = { Rows = 5, Columns = 6, Spacing = 6, Heading = -90, Position = Vector3.new(-RUN_LENGTH / 2, 18, RUN_Z) },
	Beats = {
		{
			Id = "01_DoorDrama",
			Family = "Crowd",
			Mechanic = "DoorChoice",
			LengthTarget = 180,
			Pieces = {
				-- The beat entrance is ONE channel wide on purpose. A QA gate volume is
				-- 60 studs across, and the corridor behind it is 98: if the corridor
				-- began at the beat entrance, a racer could enter it outside the gate
				-- plane and the cut-set audit would have nothing to cut. Everything
				-- leaving the start plaza is funnelled through this slab first.
				{ Id = "Funnel01", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.22 },

				-- Band 1: five channels. Flanks are listed before the Chain slab they
				-- sit beside so the whole band shares one entry line.
				{
					Id = "W1_L2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = CHANNEL,
					OffsetSide = -2 * CHANNEL_WIDTH,
					OffsetUp = -2,
				},
				{
					Id = "W1_L1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_003",
					Scale = CHANNEL,
					OffsetSide = -CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W1_R1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_003",
					Scale = CHANNEL,
					OffsetSide = CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W1_R2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = CHANNEL,
					OffsetSide = 2 * CHANNEL_WIDTH,
					OffsetUp = -2,
				},
				{ Id = "W1", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = CHANNEL },

				-- Band 2, carrying row 1 at its midpoint.
				{
					Id = "W2_L2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_003",
					Scale = CHANNEL,
					OffsetSide = -2 * CHANNEL_WIDTH,
					OffsetUp = -2,
				},
				{
					Id = "W2_L1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_001",
					Scale = CHANNEL,
					OffsetSide = -CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W2_R1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_001",
					Scale = CHANNEL,
					OffsetSide = CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W2_R2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_003",
					Scale = CHANNEL,
					OffsetSide = 2 * CHANNEL_WIDTH,
					OffsetUp = -2,
				},
				{ Id = "W2", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = CHANNEL },

				-- Row 1, square to the route. Five slabs at their own width tile into
				-- one continuous wall 98.1 studs across, exactly the corridor's width, so
				-- there is no edge to walk around; each slab sits on its own channel, at
				-- that channel's height, so nothing opens underneath it either. The
				-- slabs stand 11.95 studs tall and the roof above them is what stops
				-- the row being climbed (see the course doc: a rig jump-climbed a
				-- 14.65-stud slab in 0.6 s, so height alone never closed it).
				{
					Id = "Door01",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_002",
					Scale = DOOR,
					OffsetAlong = -12.32,
					OffsetSide = -2 * DOOR_WIDTH,
					OffsetUp = -2,
					DoorRow = 1,
					DoorIndex = 1,
					EncounterGroup = "DoorRow01",
				},
				{
					Id = "Door02",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_003",
					Scale = DOOR,
					OffsetAlong = -12.32,
					OffsetSide = -DOOR_WIDTH,
					OffsetUp = -1,
					DoorRow = 1,
					DoorIndex = 2,
					EncounterGroup = "DoorRow01",
				},
				{
					Id = "Door03",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_004",
					Scale = DOOR,
					OffsetAlong = -12.32,
					OffsetSide = 0,
					OffsetUp = 0,
					DoorRow = 1,
					DoorIndex = 3,
					EncounterGroup = "DoorRow01",
				},
				{
					Id = "Door04",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_005",
					Scale = DOOR,
					OffsetAlong = -12.32,
					OffsetSide = DOOR_WIDTH,
					OffsetUp = -1,
					DoorRow = 1,
					DoorIndex = 4,
					EncounterGroup = "DoorRow01",
				},
				{
					Id = "Door05",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_006",
					Scale = DOOR,
					OffsetAlong = -12.32,
					OffsetSide = 2 * DOOR_WIDTH,
					OffsetUp = -2,
					DoorRow = 1,
					DoorIndex = 5,
					EncounterGroup = "DoorRow01",
				},

				-- The roof over the door section, and the reason it exists. A measured
				-- climb test in the connected place put a plain R15 rig on top of a
				-- 14.65-stud door slab in about 0.6 seconds, from the corridor floor,
				-- by walking into the slab and jumping: root height rose 13.6 studs
				-- (evidence: docs/splashdown/courses/door-dash.md, "The door tops were
				-- climbable"). That is well past the 11.5-stud ledge the movement
				-- evidence says a jump clears, and past what CourseQA's graph models,
				-- so the doors alone did NOT close their over-jump space. Section 6's
				-- remedy is explicit -- "close their over-jump space with VISIBLE stock
				-- supported tunnel/roof geometry" -- so the corridor is roofed in four
				-- stepped bands of stock slabs, rotated so their long axis spans the
				-- corridor. Each band's underside sits at or just above the tallest
				-- door top beneath it, which leaves 0-1 studs of space above a door:
				-- far below the 5 studs of headroom a standable surface needs, so the
				-- door tops stop being surfaces at all. The undersides sit BELOW EVERY
				-- door top on purpose -- 8 and 9 studs above the corridor against door
				-- tops at 9.95, 10.95 and 11.95 -- so each slab is set into the roof
				-- like a real doorway and there is no ledge to catch and no pocket to
				-- wedge in: the first roofed build left a 0-1 stud gap, and the route
				-- rig jammed itself in it, and a second build that left the outer door
				-- tops 0.46 studs proud of one band handed the cut-set audit a real
				-- staircase: jump 11 studs onto an exposed top, then onto the roof, then
				-- walk the whole corridor and drop past five gates. With every top
				-- buried there is nothing to stand on, and the roof's own top is 17.7
				-- studs above the floor, well past the measured 11.5-stud ledge. Bands
				-- alternate 8 / 9 so no 24-stud square of level roof exists either, and
				-- the corridor keeps 8 studs of headroom against a 5-stud character.

				-- The roof over the door section, and the reason it exists. A measured
				-- climb test in the connected place put a plain R15 rig on top of a
				-- 14.65-stud door slab in about 0.6 seconds, from the corridor floor,
				-- by walking into the slab and jumping: root height rose 13.6 studs
				-- (evidence: docs/splashdown/courses/door-dash.md). That is well past
				-- the 11.5-stud ledge the movement evidence says a jump clears, and past
				-- what CourseQA's graph models, so the doors alone did NOT close their
				-- over-jump space. Section 6's remedy is explicit -- "close their
				-- over-jump space with VISIBLE stock supported tunnel/roof geometry" --
				-- so the corridor is roofed in five stepped bands of stock slabs.
				--
				-- Every band's underside sits BELOW every door top beneath it (8 and 9
				-- studs above the corridor against tops at 9.95, 10.95 and 11.95), so
				-- each slab is set into the roof like a real doorway: no ledge to catch,
				-- no pocket to wedge in, and no exposed door top to use as a step. Bands
				-- alternate 8 / 9 so no 24-stud square of level roof exists, and the
				-- roof's own top is 17.7 studs above the floor, well past the 11.5-stud
				-- ledge. The corridor keeps 8 studs of headroom against a 5-stud
				-- character.
				{
					Id = "RoofA_L2",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_001",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -15.28,
					OffsetSide = -1.5 * ROOF_PITCH,
					OffsetUp = 9,
				},
				{
					Id = "RoofA_L1",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_002",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -15.28,
					OffsetSide = -0.5 * ROOF_PITCH,
					OffsetUp = 9,
				},
				{
					Id = "RoofA_R1",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_003",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -15.28,
					OffsetSide = 0.5 * ROOF_PITCH,
					OffsetUp = 9,
				},
				{
					Id = "RoofA_R2",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_001",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -15.28,
					OffsetSide = 1.5 * ROOF_PITCH,
					OffsetUp = 9,
				},

				-- Band 3, carrying row 2.
				{
					Id = "W3_L2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_001",
					Scale = CHANNEL,
					OffsetSide = -2 * CHANNEL_WIDTH,
					OffsetUp = -2,
				},
				{
					Id = "W3_L1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = CHANNEL,
					OffsetSide = -CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W3_R1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = CHANNEL,
					OffsetSide = CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W3_R2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_001",
					Scale = CHANNEL,
					OffsetSide = 2 * CHANNEL_WIDTH,
					OffsetUp = -2,
				},
				{ Id = "W3", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = CHANNEL },

				-- Row 2, yawed +15 degrees (section 7.3: "row yaw 0/+15/-15 relative to
				-- route, spacing 26/34"). The row is rotated as a UNIT: each slab keeps
				-- the same 19.62-stud pitch along the rotated line, so the wall stays
				-- continuous instead of opening five wedges. A slab d studs out sits at
				-- OffsetSide d*cos(15) and OffsetAlong d*sin(15), which is exactly
				-- right(yaw + 15) * d in the cursor's frame.
				{
					Id = "Door06",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_007",
					Scale = DOOR,
					FacingOffsetDegrees = 15,
					OffsetAlong = -10.96 - 2 * DOOR_WIDTH * 0.258819,
					OffsetSide = -2 * DOOR_WIDTH * 0.965926,
					OffsetUp = -2,
					DoorRow = 2,
					DoorIndex = 1,
					EncounterGroup = "DoorRow02",
				},
				{
					Id = "Door07",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_002",
					Scale = DOOR,
					FacingOffsetDegrees = 15,
					OffsetAlong = -10.96 - DOOR_WIDTH * 0.258819,
					OffsetSide = -DOOR_WIDTH * 0.965926,
					OffsetUp = -1,
					DoorRow = 2,
					DoorIndex = 2,
					EncounterGroup = "DoorRow02",
				},
				{
					Id = "Door08",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_003",
					Scale = DOOR,
					FacingOffsetDegrees = 15,
					OffsetAlong = -10.96,
					OffsetSide = 0,
					OffsetUp = 0,
					DoorRow = 2,
					DoorIndex = 3,
					EncounterGroup = "DoorRow02",
				},
				{
					Id = "Door09",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_004",
					Scale = DOOR,
					FacingOffsetDegrees = 15,
					OffsetAlong = -10.96 + DOOR_WIDTH * 0.258819,
					OffsetSide = DOOR_WIDTH * 0.965926,
					OffsetUp = -1,
					DoorRow = 2,
					DoorIndex = 4,
					EncounterGroup = "DoorRow02",
				},
				{
					Id = "Door10",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_005",
					Scale = DOOR,
					FacingOffsetDegrees = 15,
					OffsetAlong = -10.96 + 2 * DOOR_WIDTH * 0.258819,
					OffsetSide = 2 * DOOR_WIDTH * 0.965926,
					OffsetUp = -2,
					DoorRow = 2,
					DoorIndex = 5,
					EncounterGroup = "DoorRow02",
				},

				{
					Id = "RoofB_L2",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_002",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -20.4,
					OffsetSide = -1.5 * ROOF_PITCH,
					OffsetUp = 8,
				},
				{
					Id = "RoofB_L1",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_003",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -20.4,
					OffsetSide = -0.5 * ROOF_PITCH,
					OffsetUp = 8,
				},
				{
					Id = "RoofB_R1",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_001",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -20.4,
					OffsetSide = 0.5 * ROOF_PITCH,
					OffsetUp = 8,
				},
				{
					Id = "RoofB_R2",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_002",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -20.4,
					OffsetSide = 1.5 * ROOF_PITCH,
					OffsetUp = 8,
				},

				-- Band 4.
				{
					Id = "W4_L2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = CHANNEL,
					OffsetSide = -2 * CHANNEL_WIDTH,
					OffsetUp = -2,
				},
				{
					Id = "W4_L1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_003",
					Scale = CHANNEL,
					OffsetSide = -CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W4_R1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_003",
					Scale = CHANNEL,
					OffsetSide = CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W4_R2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = CHANNEL,
					OffsetSide = 2 * CHANNEL_WIDTH,
					OffsetUp = -2,
				},
				{ Id = "W4", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = CHANNEL },

				{
					Id = "RoofC_L2",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_003",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -25.52,
					OffsetSide = -1.5 * ROOF_PITCH,
					OffsetUp = 9,
				},
				{
					Id = "RoofC_L1",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_001",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -25.52,
					OffsetSide = -0.5 * ROOF_PITCH,
					OffsetUp = 9,
				},
				{
					Id = "RoofC_R1",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_002",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -25.52,
					OffsetSide = 0.5 * ROOF_PITCH,
					OffsetUp = 9,
				},
				{
					Id = "RoofC_R2",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_003",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -25.52,
					OffsetSide = 1.5 * ROOF_PITCH,
					OffsetUp = 9,
				},

				-- Row 3, yawed -15 degrees.
				{
					Id = "Door11",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_006",
					Scale = DOOR,
					FacingOffsetDegrees = -15,
					OffsetAlong = -1.6 + 2 * DOOR_WIDTH * 0.258819,
					OffsetSide = -2 * DOOR_WIDTH * 0.965926,
					OffsetUp = -2,
					DoorRow = 3,
					DoorIndex = 1,
					EncounterGroup = "DoorRow03",
				},
				{
					Id = "Door12",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_007",
					Scale = DOOR,
					FacingOffsetDegrees = -15,
					OffsetAlong = -1.6 + DOOR_WIDTH * 0.258819,
					OffsetSide = -DOOR_WIDTH * 0.965926,
					OffsetUp = -1,
					DoorRow = 3,
					DoorIndex = 2,
					EncounterGroup = "DoorRow03",
				},
				{
					Id = "Door13",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_002",
					Scale = DOOR,
					FacingOffsetDegrees = -15,
					OffsetAlong = -1.6,
					OffsetSide = 0,
					OffsetUp = 0,
					DoorRow = 3,
					DoorIndex = 3,
					EncounterGroup = "DoorRow03",
				},
				{
					Id = "Door14",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_003",
					Scale = DOOR,
					FacingOffsetDegrees = -15,
					OffsetAlong = -1.6 - DOOR_WIDTH * 0.258819,
					OffsetSide = DOOR_WIDTH * 0.965926,
					OffsetUp = -1,
					DoorRow = 3,
					DoorIndex = 4,
					EncounterGroup = "DoorRow03",
				},
				{
					Id = "Door15",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_004",
					Scale = DOOR,
					FacingOffsetDegrees = -15,
					OffsetAlong = -1.6 - 2 * DOOR_WIDTH * 0.258819,
					OffsetSide = 2 * DOOR_WIDTH * 0.965926,
					OffsetUp = -2,
					DoorRow = 3,
					DoorIndex = 5,
					EncounterGroup = "DoorRow03",
				},

				{
					Id = "RoofD_L2",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_001",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -6,
					OffsetSide = -1.5 * ROOF_PITCH,
					OffsetUp = 8,
				},
				{
					Id = "RoofD_L1",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_003",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -6,
					OffsetSide = -0.5 * ROOF_PITCH,
					OffsetUp = 8,
				},
				{
					Id = "RoofD_R1",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_002",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -6,
					OffsetSide = 0.5 * ROOF_PITCH,
					OffsetUp = 8,
				},
				{
					Id = "RoofD_R2",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_001",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -6,
					OffsetSide = 1.5 * ROOF_PITCH,
					OffsetUp = 8,
				},

				-- Band 5. Row 3, above, is yawed the other way and reaches 12.45 studs
				-- either side of its centre line, so it needs five-channel floor in this
				-- band as well as band 4; the taper starts after it.
				{
					Id = "W5_L2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_003",
					Scale = CHANNEL,
					OffsetSide = -2 * CHANNEL_WIDTH,
					OffsetUp = -2,
				},
				{
					Id = "W5_L1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_001",
					Scale = CHANNEL,
					OffsetSide = -CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W5_R1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_001",
					Scale = CHANNEL,
					OffsetSide = CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W5_R2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_003",
					Scale = CHANNEL,
					OffsetSide = 2 * CHANNEL_WIDTH,
					OffsetUp = -2,
				},
				{ Id = "W5", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = CHANNEL },

				{
					Id = "RoofE_L2",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_002",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -11.12,
					OffsetSide = -1.5 * ROOF_PITCH,
					OffsetUp = 9,
				},
				{
					Id = "RoofE_L1",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_001",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -11.12,
					OffsetSide = -0.5 * ROOF_PITCH,
					OffsetUp = 9,
				},
				{
					Id = "RoofE_R1",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_003",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -11.12,
					OffsetSide = 0.5 * ROOF_PITCH,
					OffsetUp = 9,
				},
				{
					Id = "RoofE_R2",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_002",
					Scale = ROOF,
					FacingOffsetDegrees = 90,
					OffsetAlong = -11.12,
					OffsetSide = 1.5 * ROOF_PITCH,
					OffsetUp = 9,
				},

				-- Band 6: the taper. Three channels, then one, which is the lane beat 02
				-- inherits (HANDOFF 5.2: "the lane tapers from the 30-pad start through
				-- the door rows").
				{
					Id = "W6_L1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = CHANNEL,
					OffsetSide = -CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{
					Id = "W6_R1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = CHANNEL,
					OffsetSide = CHANNEL_WIDTH,
					OffsetUp = -1,
				},
				{ Id = "W6", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = CHANNEL },
				{ Id = "Stub01", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.2 },
				{ Id = "Stub02", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.17 },
			},
		},
		{
			Id = "02_SlideSwipe",
			Family = "ClimbDescend",
			Mechanic = "SlideExit",
			LengthTarget = 100,
			Pieces = {
				{ Id = "Floor01", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.26 },
				-- slide_001 at 0.2317 drops exactly the 12 studs section 7.3 asks for,
				-- in 5.79 studs of route; the pilot uses the same scale for the same
				-- drop.
				{ Id = "Slide01", Kind = "Chain", Preset = "Slide", Source = "slide_001", Scale = SLIDE_12 },
				{ Id = "Floor02", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.26 },
				-- The cross spinner is 29.04 studs across at 0.5 and the lane under it
				-- is 18.22, so the sweep covers the whole floor and both edges: there is
				-- no strip to walk down. Its speed is the section 6 formula at the
				-- measured 14.519 contact radius; the sign is opposite Whirlpool Waltz's
				-- cross so the two courses do not pose the same silhouette identically.
				{
					Id = "Cross01",
					Kind = "Mount",
					Preset = "Spinner",
					Source = "obstacle_12_001",
					Scale = 0.5,
					OffsetAlong = -11,
					RotorSpeed = 135,
					RotorPhase = 0,
				},
				{ Id = "Floor03", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = 0.26 },
				-- Section 7.3's "1 forced bumper". A single bumper only forces contact
				-- on a lane narrow enough that a runner cannot pass beside it: this slab
				-- is 11.91 studs wide and the bumper is 7.17, leaving 2.37 studs a side
				-- against a body about 2 wide, with race liquid off both edges.
				{ Id = "Floor04", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.17 },
				{
					Id = "Bumper01",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_18_001",
					Scale = 0.5,
					OffsetAlong = -7.5,
				},
				{ Id = "Floor05", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.19 },
			},
		},
		{
			Id = "03_BeltBrawl",
			Family = "Ride",
			Mechanic = "TripleCounterbelt",
			LengthTarget = 150,
			Pieces = {
				{
					Id = "Ramp01",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				-- Three belts running against the racer at the three speeds section 7.3
				-- names, in increasing magnitude, all inside section 9.7's 13-18.2 band.
				{
					Id = "Belt01",
					Kind = "Chain",
					Preset = "Conveyor",
					Source = "obstacle_9_001",
					Scale = 0.5,
					ConveyorSpeed = -13,
				},
				{
					Id = "Belt02",
					Kind = "Chain",
					Preset = "Conveyor",
					Source = "obstacle_9_001",
					Scale = 0.5,
					ConveyorSpeed = -15.6,
				},
				-- The paddle wheel crosses the MIDDLE belt: its cradles orbit a measured
				-- 7.743-stud radius at 0.5 and its X axle lies across the 13.98-stud
				-- belt, so the four cradles sweep the whole belt width 1.5 studs above
				-- the deck. Speed is the section 6 formula at that radius (255 deg/s),
				-- not a chosen number.
				{
					Id = "PaddleWheel01",
					Kind = "Mount",
					Preset = "PaddleWheel",
					Source = "obstacle_24_001",
					Scale = 0.5,
					OffsetAlong = -14,
					OffsetUp = 1.5,
					RotorPhase = 0,
				},
				{
					Id = "Belt03",
					Kind = "Chain",
					Preset = "Conveyor",
					Source = "obstacle_9_001",
					Scale = 0.5,
					ConveyorSpeed = -18.2,
				},
				-- The hairpin's first turn. The builder tiles one 26.4-stud filler slab
				-- up to the guide vertex before it, which is the run-out the belts need
				-- anyway; the corner slab itself carries the route through 90 degrees on
				-- one continuous walkable top.
				{ Id = "CornerA", Kind = "Corner", Direction = "Left" },
			},
		},
		{
			Id = "04_PadParade",
			Family = "Launch",
			Mechanic = "SuccessiveLaunches",
			LengthTarget = 130,
			Pieces = {
				-- The foam catch basin, built first so it is measured from this beat's
				-- entrance. Section 7.3 requires a missed landing to cost a foam slog of
				-- at least five seconds rather than a splash: the basin is a ramp
				-- dropping 12 studs under the launch chain and a flat deck at its foot,
				-- both covered by foam, and its only way out is back UP to this beat's
				-- entrance -- so a miss redoes the beat at 0.45 speed instead of
				-- respawning at a checkpoint. It is a Flank pair: placed beside the
				-- route without advancing it.
				{
					Id = "BasinRamp",
					Kind = "Flank",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_12,
					OffsetUp = -0.5,
				},
				{
					Id = "BasinDeck",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = 0.3,
					OffsetAlong = 58.11,
					OffsetUp = -12.5,
				},
				-- The volume's top stays at +4.5 from this beat's entrance, below the
				-- underside of the lowest launch deck (+7.72), so no racer standing on
				-- the route is ever inside it.
				{
					Id = "Foam01",
					Kind = "Mount",
					Preset = "FoamPit",
					Scale = 1,
					OffsetAlong = 42,
					OffsetUp = -12.5,
					VolumeSize = Vector3.new(28, 4.5, 84),
				},

				{ Id = "Deck01", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = LAUNCH_DECK },
				{
					Id = "Pad01",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_4_001",
					Scale = 0.6,
					OffsetAlong = -6,
					LaunchSpeed = 48,
				},
				-- 14-stud launch gaps that also step up 4 studs, three times, which is
				-- the entire +12 section 7.3 gives this beat: there is no room on the
				-- cross run for a 58-stud ramp as well as the launch chain. These are
				-- launch transfers, not ordinary jumps, so section 8.3's 13.2-19.8 rule
				-- does not apply and the audit reports them as measured reach windows.
				{ Id = "Gap01", Kind = "Advance", OffsetAlong = 14, OffsetUp = 4 },
				{ Id = "Deck02", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = LAUNCH_DECK },
				{
					Id = "Pad02",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_4_001",
					Scale = 0.6,
					OffsetAlong = -6,
					LaunchSpeed = 50,
				},
				{ Id = "Gap02", Kind = "Advance", OffsetAlong = 14, OffsetUp = 4 },
				-- The second launch lands on the builder's own 19.93-stud filler slab,
				-- which is the run-in to the hairpin's second turn; the corner slab then
				-- carries the route back onto the second run.
				{ Id = "CornerB", Kind = "Corner", Direction = "Left" },
				{ Id = "Deck03", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = LAUNCH_DECK },
				{
					Id = "Pad03",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_4_001",
					Scale = 0.6,
					OffsetAlong = -6,
					LaunchSpeed = 52,
				},
				{ Id = "Gap03", Kind = "Advance", OffsetAlong = 14, OffsetUp = 4 },
				-- The landing slab, and the last solid ground of the beat: the next
				-- beat's checkpoint pad is placed four studs back from its entrance and
				-- has to stand on something.
				{ Id = "Deck04", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.22 },
				{
					Id = "Bumper03",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_18_001",
					Scale = 0.5,
					OffsetAlong = -9,
				},
			},
		},
		{
			Id = "05_MaceMarch",
			Family = "Timing",
			Mechanic = "PendulumGauntlet",
			LengthTarget = 160,
			Pieces = {
				{ Id = "Ramp02", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6 },
				-- The lane narrows through the gauntlet -- 15.42, 14.01, 12.61 studs --
				-- which is how a mace whose ball sweeps 10.3 studs either side of centre
				-- covers it (section 9.3 narrows a lane before it touches a shove).
				{ Id = "Floor06", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.22 },
				-- Section 6: mace at 0.7, top-link axle, rock Z amplitude 45 period 3.2,
				-- neighbour phases 0 and 1.07. The axle hangs 21 studs above the deck so
				-- the ball's underside sweeps 2.89 studs above it at the bottom of its
				-- arc. HANDOFF 8.3: "suspended mace links are supported by their chain
				-- and axle, not required to touch a floor".
				{
					Id = "Mace01",
					Kind = "Mount",
					Preset = "Mace",
					Source = "obstacle_5_001",
					Scale = 0.7,
					OffsetAlong = -10,
					OffsetUp = 21,
					RotorPhase = 0,
				},
				{ Id = "Floor07", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = 0.2 },
				{
					Id = "Bumper02",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_19_001",
					Scale = 0.5,
					OffsetAlong = -8.8,
				},
				{ Id = "Floor08", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.18 },
				{
					Id = "Mace02",
					Kind = "Mount",
					Preset = "Mace",
					Source = "obstacle_5_001",
					Scale = 0.7,
					OffsetAlong = -8,
					OffsetUp = 21,
					RotorPhase = 1.07,
				},
				{
					Id = "Ramp03",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{ Id = "Floor09", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.26 },
				-- The large hammer at the exit, on the widest slab of the beat so its
				-- 55-degree strike is readable from the ramp below it.
				{
					Id = "HammerLarge",
					Kind = "Mount",
					Preset = "Hammer",
					Source = "obstacle_3_001",
					Scale = 0.6,
					OffsetAlong = -11,
					OffsetUp = HAMMER_LARGE_UP,
					RotorAmplitude = 55,
					RotorPhase = 0,
				},
				{ Id = "Floor10", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = 0.26 },
				{ Id = "Floor11", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.15 },
			},
		},
		{
			Id = "06_CrossFinish",
			Family = "Timing",
			Mechanic = "CrossSweep",
			LengthTarget = 80,
			Pieces = {
				{ Id = "Ramp04", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6 },
				{ Id = "Floor12", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.26 },
				-- One readable sweep, the easiest window in the course: a two-arm cross
				-- leaves half its circle open at any moment, against the four-arm cross
				-- in beat 02. Opposite sign to Whirlpool Waltz's two-arm, and a
				-- different phase, so the same silhouette is posed differently.
				{
					Id = "TwoArm01",
					Kind = "Mount",
					Preset = "Spinner",
					Source = "obstacle_27_001",
					Scale = 0.5,
					OffsetAlong = -11,
					RotorSpeed = -135,
					RotorPhase = 0.5,
				},
				{ Id = "Floor13", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = 0.26 },
			},
		},
	},
}

return DoorDash
