-- Name: TiptoeTrials.luau
-- Author: Jack C.
-- Description: Declarative spec for Tiptoe Trials (HANDOFF.md section 7.5): an Archipelago layout -- nine islands placed radially around the origin, stepping inward from a perimeter start plaza to a centre finish island -- whose consecutive islands are linked only by a fan launch, five three-tile falling-tile bridges and two jump-pad launches. It carries two rider-weighted seesaws on both of the kit's board forms, a two-arm cross on a mid-hop rock, a mace over a stepped ascent, a large and a small hammer between the climax's tile groups, and a rocking swing panel. Beat length targets are the scaled section 7.5 targets recorded in docs/splashdown/03-overrides.md. Every scale, speed, anchor and socket figure traces to AssetManifest or to the measured evidence cited in docs/splashdown/courses/tiptoe-trials.md.
-- Created: 2026-09-16

--!strict

local CourseBuilder = require(script.Parent.Parent.CourseBuilder)

-- HANDOFF 5.2 guide: "Islands placed radially around the origin; start at the
-- perimeter and finish at the centre island (or the reverse if the measured launch
-- envelopes fit better); consecutive islands are linked only by the beat's launch or
-- tile group; non-consecutive islands are separated by more than the maximum measured
-- launch reach."
--
-- The nine anchors below are the point at which the route ARRIVES on each island, in
-- polar coordinates about the course origin. They were solved, not drawn: the island
-- contents below fix each island's own length, the links fix the crossings, and the
-- twelve round-deck turns were searched until the route closed with strictly
-- decreasing anchor radii (267.42 down to 17.96), a worst route radius of 267.42
-- inside the 300 bound, and a worst non-consecutive island separation of 53.02 studs
-- -- comfortably past the 38.89-stud worst launch this course can produce. The
-- builder re-derives all of those from the built geometry and fails if they move.
local LIQUID_Y = -8

-- box_011 is a measured descending ramp: at scale s it travels 138 * s studs and
-- drops 28.5 * s. Entered from its low end (Reversed) it is the only climb the kit
-- can make, and it costs 4.842 studs of route for every stud of rise -- which is why
-- beat 01's +12 is split between one ramp and the fan launch rather than ramped
-- whole.
local RAMP_4 = 4 / 28.5
local RAMP_6 = 6 / 28.5

-- Section 6 fixes the falling tile at scale 0.25. color_box measures 18.6366 x
-- 9.3183 x 27.9549 with a flat top at +4.6592 across |x| <= 8.50 and |z| <= 13.00, so
-- a 0.25 tile is 4.50 studs of walkable width and 6.875 studs of travel, and a group
-- of three bridges 20.625 studs of open water. Three tiles is what section 7.5 asks
-- for in both tile beats. RespawnSeconds is 3 and CriticalRoute is true on every one
-- of them (HANDOFF 13: "No permanent critical falling tiles").
local TILE = 0.25

-- Seesaw geometry, measured. obstacle_25's board top is 17.7227 above the pedestal's
-- centre and the pedestal's lowest collision point is -9.3184, so at 0.6 the board top
-- sits 16.2247 studs above its base and a plinth has to reach exactly that far;
-- platform_002 stands 28.575 * s studs above its own Support socket.
local SEESAW_25 = 0.6
local SEESAW_25_DROP = (17.7227 + 9.3184) * SEESAW_25
local function plinthScale(boardTopY: number): number
	return (boardTopY - SEESAW_25_DROP - LIQUID_Y) / 28.575
end

-- obstacle_11 is the other board form, and it cannot stand on a plinth like that: its
-- fulcrum bar's underside is only 3.3378 studs below the plank's own top, so at MaxTilt
-- 22 the plank's underside clears the bar's base only within |z| <= 4.253 * scale --
-- 2.127 studs at 0.5. The pier therefore has to be THIN along the route: a door panel
-- is 6.2765 studs thick at scale 1, so at the 0.269 the height needs it is 1.69 studs
-- thick and 20.24 wide, which matches the bar it carries and never meets the plank.
local SEESAW_11 = 0.5
local SEESAW_11_DROP = (0.9482 + 2.3896) * SEESAW_11
local function pierScale(plankTopY: number): number
	return (plankTopY - SEESAW_11_DROP - LIQUID_Y) / 45.79
end

-- The hammers hang. obstacle_3_001 and obstacle_4_001 are axle housings with their
-- heads suspended 16.85 and 16.35 studs beneath them, so mounting one with its Support
-- on the deck (the pilot's mounting) leaves the head sweeping entirely BELOW the lane,
-- where it can never touch a runner. HANDOFF 8.3 explicitly exempts a suspended
-- pendulum from the support rule -- "suspended mace links are supported by their chain
-- and axle, not required to touch a floor" -- and Door Dash already hangs its maces at
-- OffsetUp 21 on that basis. These two are hung by the same rule, at the height that
-- puts the head's resting bottom 0.6 studs clear of the deck: at rest it blocks the
-- lane from deck level to 19 studs up, and past +-42 degrees of its 55-degree amplitude
-- the whole head is above 8.9 studs, which is the readable window.
local HAMMER = 0.6
local HAMMER_LARGE_UP = (16.846 + 31.2676 / 2) * HAMMER - 1.97 * HAMMER + 0.6
local HAMMER_SMALL_UP = (16.353 + 32.5873 / 2) * HAMMER - 2.32 * HAMMER + 0.6

local TiptoeTrials: CourseBuilder.CourseSpec = {
	Version = 1,
	Id = "TiptoeTrials",
	DisplayName = "Tiptoe Trials",
	-- HANDOFF 7.5: "Headline: falling-tile islands, never a permanently destroyed
	-- checkpoint route." Falling tiles appear in no other course in the set.
	Headline = "FallingTile",
	Difficulty = 3,
	ParSeconds = 75,
	CapSeconds = 180,
	CloseWindowSeconds = 60,
	Layout = {
		Kind = "Archipelago",
		-- An archipelago has no parallel lanes, so it has no lane pitch; the spacing
		-- that matters is the island separation, which the builder measures.
		LanePitch = 0,
		BoundsRadius = 300,
		LiquidY = LIQUID_Y,
		Archipelago = {
			Islands = {
				{ Id = "Shore", AngleDegrees = 269.80452, Radius = 267.4246, Y = 0 },
				{ Id = "Balance", AngleDegrees = 250.25389, Radius = 261.8685, Y = 12 },
				{ Id = "Midhop", AngleDegrees = 204.60547, Radius = 219.9074, Y = 12 },
				{ Id = "Spire", AngleDegrees = 191.10059, Radius = 213.9767, Y = 12 },
				{ Id = "FirstFade", AngleDegrees = 131.49013, Radius = 185.4873, Y = 18 },
				{ Id = "SecondFade", AngleDegrees = 114.08442, Radius = 177.9427, Y = 18 },
				{ Id = "LastFade", AngleDegrees = 93.87764, Radius = 119.5558, Y = 24 },
				{ Id = "PadRock", AngleDegrees = 76.35476, Radius = 35.936, Y = 21 },
				{ Id = "Finish", AngleDegrees = 280.63347, Radius = 17.9623, Y = 18 },
			},
			-- HANDOFF 3.2's measured movement constants. Every reach in this layout is
			-- derived from them: the ordinary jump is sqrt(2 * 120 * 10) = 48.99 studs/s
			-- and the model predicts 21.23 studs of flat gap against the measured 22, so
			-- the 0.7711 calibration is the avatar's own body extent.
			Gravity = 120,
			WalkSpeed = 26,
			JumpHeight = 10,
			JumpReachCalibration = 0.7711,
			-- A round landing deck absorbs a heading change with no wedge seam, which is
			-- what every turn in this course happens on. Sixty degrees is the most any one
			-- of them turns.
			MaxTurnDegrees = 60,
			MaxFlightDeviationDegrees = 6,
			PerimeterRadius = 245,
			CentreRadius = 40,
		},
		-- An Archipelago turns on round decks, never on corner slabs, so neither of
		-- these is used; they are required by the shared layout contract.
		Corner = { Source = "platform_002", Scale = 0.3 },
		Fill = { Source = "platform_002", Scale = 0.3 },
	},
	-- HANDOFF 7.5: "StartY 0." The plaza centre sits 24 studs behind the first
	-- island's anchor along the start heading, which is exactly the offset
	-- buildStartPads walks off a five-row grid at 6-stud spacing.
	Start = {
		Rows = 5,
		Columns = 6,
		Spacing = 6,
		Heading = 103.4574,
		Position = Vector3.new(22.4293, 0, -272.9972),
	},
	Beats = {
		{
			Id = "01_FloatFlight",
			Family = "Launch",
			Mechanic = "FloatLanding",
			LengthTarget = 121,
			Pieces = {
				{ Id = "Shore", Kind = "Island", Island = 1, Link = "Start" },
				{ Id = "Lane01", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.26 },
				{
					Id = "Climb01",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{ Id = "Lane02", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.2 },
				-- The fan stands IN the water seven studs past the shore's launch edge,
				-- not on the deck. Its column is a 6.19-stud-radius cylinder about its own
				-- axis, and the kit launches a runner the moment they enter it: mounted back
				-- on the deck the launch would fire 6.19 studs before the edge and the flight
				-- would need 26.69 studs of reach against the 22.96 a 48/0.2 launch makes
				-- over a 6-stud rise. Out here the column's near edge sits 0.81 studs past
				-- the shore, so the runner has to leave the island before it fires and the
				-- crossing it has to make is the measured 20.5.
				{
					Id = "Fan01",
					Kind = "Mount",
					Preset = "Fan",
					Source = "propeller_trampoline_1_001",
					Scale = 0.5,
					MountTo = "Liquid",
					OffsetAlong = 7,
					FanAxis = "Y",
					FanDirection = 1,
					LaunchSpeed = 48,
					FloatFactor = 0.2,
				},
				{ Id = "Balance", Kind = "Island", Island = 2, Link = "Launch" },
				{
					Id = "Land02",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.8,
					TurnDegrees = 15.002,
				},
				-- The forced bumper at the landing. The landing rock is 29.82 studs across,
				-- far too wide to force anything, so the bumper sits three studs past its
				-- exit rim where the route has already narrowed onto a 7.01-stud lane, and
				-- 2.2 studs off centre: the free strip beside it measures 2.12 studs, under
				-- the avatar's own width, so contact cannot be walked around.
				{
					Id = "Bumper01",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_18_001",
					Scale = 0.5,
					OffsetAlong = 3,
					OffsetSide = -2.2,
				},
			},
		},
		{
			Id = "02_BalanceBay",
			Family = "Ride",
			Mechanic = "LoadBalance",
			LengthTarget = 132,
			Pieces = {
				{ Id = "Lane03", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.1 },
				-- obstacle_25's board: 5.59 studs wide over 27.6 studs of travel, with open
				-- water on both sides. Its plinth is a platform_002 stub standing from the
				-- liquid to the pedestal's own base 16.22 studs below the board.
				{
					Id = "Seesaw01",
					Kind = "Chain",
					Preset = "Seesaw",
					Source = "obstacle_25_001",
					Scale = SEESAW_25,
					MaxTiltDegrees = 22,
				},
				{
					Id = "Plinth01",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_002",
					Scale = plinthScale(12),
					MountTo = "Liquid",
					OffsetAlong = -13.8,
				},
				{
					Id = "Turn02a",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.4,
					TurnDegrees = 26.6375,
				},
				{ Id = "Drop02", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6 },
				-- The opposing board (section 7.5: "obstacle_25 and opposing-board
				-- obstacle_11"). Reversed swaps its measured Entry and Exit sockets, so the
				-- plank is entered from its other end: 17.34 studs wide over 37.5 studs of
				-- travel, three times the first board's length and three times its width.
				{
					Id = "Seesaw02",
					Kind = "Chain",
					Preset = "Seesaw",
					Source = "obstacle_11_001",
					Scale = SEESAW_11,
					Reversed = true,
					MaxTiltDegrees = 22,
				},
				{
					Id = "Pier02",
					Kind = "Mount",
					Preset = "Prop",
					Source = "door_003",
					Scale = pierScale(6),
					MountTo = "Liquid",
					OffsetAlong = -18.75,
				},
				{
					Id = "Turn02b",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.4,
					TurnDegrees = 35.5808,
				},
			},
		},
		{
			Id = "03_IslandHop",
			Family = "Precision",
			Mechanic = "TileSteppingStones",
			LengthTarget = 110,
			Pieces = {
				{
					Id = "Climb03",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{
					Id = "TileA1",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_001",
					Scale = TILE,
					DropDelaySeconds = 0.65,
					RespawnSeconds = 3,
					EncounterGroup = "TileA",
				},
				{
					Id = "TileA2",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_002",
					Scale = TILE,
					DropDelaySeconds = 0.65,
					RespawnSeconds = 3,
					EncounterGroup = "TileA",
				},
				{
					Id = "TileA3",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_003",
					Scale = TILE,
					DropDelaySeconds = 0.65,
					RespawnSeconds = 3,
					EncounterGroup = "TileA",
				},
				{ Id = "Midhop", Kind = "Island", Island = 3, Link = "Tiles" },
				{
					Id = "Land03",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.85,
					TurnDegrees = -17.0603,
				},
				-- The two-arm cross on the mid-hop rock. Its 29.04-stud bar sweeps a
				-- 31.68-stud deck, so the rock is covered corner to corner; the speed is
				-- section 6's formula at the measured 14.52-stud contact radius, not a
				-- chosen number.
				{
					Id = "TwoArm01",
					Kind = "Mount",
					Preset = "Spinner",
					Source = "obstacle_27_001",
					Scale = 0.5,
					OffsetAlong = -12,
				},
				{
					Id = "TileB1",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_004",
					Scale = TILE,
					DropDelaySeconds = 0.65,
					RespawnSeconds = 3,
					EncounterGroup = "TileB",
				},
				{
					Id = "TileB2",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_005",
					Scale = TILE,
					DropDelaySeconds = 0.65,
					RespawnSeconds = 3,
					EncounterGroup = "TileB",
				},
				{
					Id = "TileB3",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_006",
					Scale = TILE,
					DropDelaySeconds = 0.65,
					RespawnSeconds = 3,
					EncounterGroup = "TileB",
				},
				{ Id = "Spire", Kind = "Island", Island = 4, Link = "Tiles" },
				{
					Id = "Land04",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.55,
					TurnDegrees = 42.7703,
				},
			},
		},
		{
			Id = "04_StepSpire",
			Family = "Climb/Descend",
			Mechanic = "SteppedAscent",
			LengthTarget = 132,
			Pieces = {
				{ Id = "Lane05", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.12 },
				{
					Id = "Step04a",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_4,
					Reversed = true,
				},
				{ Id = "Deck04a", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.12 },
				{
					Id = "Turn04a",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.45,
					TurnDegrees = -21.6034,
				},
				{
					Id = "Step04b",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_4,
					Reversed = true,
				},
				{ Id = "Deck04b", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.12 },
				-- One mace over the middle step. Door Dash uses two at once over a
				-- narrowing flat lane; this is a single pendulum over an 8.41-stud stepped
				-- deck, which is the different pose override 2 asks for. Section 6's seeds
				-- (scale 0.7, rock Z, amplitude 45, period 3.2) are unchanged, and the
				-- 21-stud hang is Door Dash's own measured mounting for that scale.
				{
					Id = "Mace01",
					Kind = "Mount",
					Preset = "Mace",
					Source = "obstacle_5_001",
					Scale = 0.7,
					OffsetAlong = -5,
					OffsetUp = 21,
					RotorPhase = 0,
				},
				{
					Id = "Turn04b",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.4,
					TurnDegrees = 34.8737,
				},
				{
					Id = "Step04c",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_4,
					Reversed = true,
				},
				-- Wide enough to carry beat 05's checkpoint pad, which is 12 studs across.
				{ Id = "Deck04c", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.2 },
			},
		},
		{
			Id = "05_FadeFooting",
			Family = "Precision",
			Mechanic = "TileIslands",
			LengthTarget = 253,
			Pieces = {
				{ Id = "Drop05", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6 },
				{
					Id = "TileC1",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_007",
					Scale = TILE,
					DropDelaySeconds = 0.75,
					RespawnSeconds = 3,
					EncounterGroup = "TileC",
				},
				{
					Id = "TileC2",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_008",
					Scale = TILE,
					DropDelaySeconds = 0.75,
					RespawnSeconds = 3,
					EncounterGroup = "TileC",
				},
				{
					Id = "TileC3",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_001",
					Scale = TILE,
					DropDelaySeconds = 0.75,
					RespawnSeconds = 3,
					EncounterGroup = "TileC",
				},
				{ Id = "FirstFade", Kind = "Island", Island = 5, Link = "Tiles" },
				{
					Id = "Land05",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.55,
					TurnDegrees = 30.5913,
				},
				{
					Id = "HammerLarge",
					Kind = "Mount",
					Preset = "Hammer",
					Source = "obstacle_3_001",
					Scale = HAMMER,
					OffsetAlong = -10,
					OffsetUp = HAMMER_LARGE_UP,
					RotorAmplitude = 55,
					RotorPhase = 0,
				},
				{ Id = "Lane07", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.18 },
				{
					Id = "TileD1",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_002",
					Scale = TILE,
					DropDelaySeconds = 0.65,
					RespawnSeconds = 3,
					EncounterGroup = "TileD",
				},
				{
					Id = "TileD2",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_003",
					Scale = TILE,
					DropDelaySeconds = 0.65,
					RespawnSeconds = 3,
					EncounterGroup = "TileD",
				},
				{
					Id = "TileD3",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_004",
					Scale = TILE,
					DropDelaySeconds = 0.65,
					RespawnSeconds = 3,
					EncounterGroup = "TileD",
				},
				{ Id = "SecondFade", Kind = "Island", Island = 6, Link = "Tiles" },
				{
					Id = "Land06",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.55,
					TurnDegrees = 60,
				},
				{
					Id = "HammerSmall",
					Kind = "Mount",
					Preset = "Hammer",
					Source = "obstacle_4_001",
					Scale = HAMMER,
					OffsetAlong = -10,
					OffsetUp = HAMMER_SMALL_UP,
					RotorAmplitude = 55,
					RotorPhase = 0.7,
				},
				{ Id = "Lane08", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.14 },
				{
					Id = "Climb05",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{
					Id = "TileE1",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_005",
					Scale = TILE,
					DropDelaySeconds = 0.55,
					RespawnSeconds = 3,
					EncounterGroup = "TileE",
				},
				{
					Id = "TileE2",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_006",
					Scale = TILE,
					DropDelaySeconds = 0.55,
					RespawnSeconds = 3,
					EncounterGroup = "TileE",
				},
				{
					Id = "TileE3",
					Kind = "Chain",
					Preset = "FallingTile",
					Source = "color_box_007",
					Scale = TILE,
					DropDelaySeconds = 0.55,
					RespawnSeconds = 3,
					EncounterGroup = "TileE",
				},
				{ Id = "LastFade", Kind = "Island", Island = 7, Link = "Tiles" },
				{
					Id = "Land07",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.55,
					TurnDegrees = 43.2598,
				},
				-- Tumble Tunnels' panel rocks at phase 1.4 inside a tunnel; this one is on
				-- an open island deck at phase 0.6, which is the different pose override 2
				-- asks for. Section 6's amplitude 28 and period 2.8 are unchanged.
				{
					Id = "SwingPanel01",
					Kind = "Mount",
					Preset = "SwingPanel",
					Source = "obstacle_8_001",
					Scale = 0.5,
					OffsetAlong = -8,
					OffsetUp = 5,
					RotorAmplitude = 28,
					RotorPeriod = 2.8,
					RotorPhase = 0.6,
				},
				{ Id = "Lane09", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.3 },
			},
		},
		{
			Id = "06_LastDash",
			Family = "Launch",
			Mechanic = "PadFinish",
			LengthTarget = 132,
			Pieces = {
				{ Id = "Lane10", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.18 },
				-- Section 7.5's pads: trampoline_5, whose inner child really is
				-- trampoline_6_001. At 0.5 the pad is 7.12 studs across a 12.61-stud lane,
				-- so an avatar cannot pass beside it, and it sits with its centre on the
				-- launch edge: the kit launches wherever the runner jumps on the pad, and
				-- from the pad's back edge the crossing would need 29.56 studs against the
				-- 29.85 this launch reaches, so the pad is kept short and forward.
				{
					Id = "Pad01",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_5_001",
					Scale = 0.5,
					LaunchSpeed = 51,
					FloatFactor = 0.2,
				},
				{ Id = "PadRock", Kind = "Island", Island = 8, Link = "Launch" },
				{
					Id = "Land08",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.7,
					TurnDegrees = 15.9274,
				},
				{
					Id = "Pad02",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_5_001",
					Scale = 0.5,
					LaunchSpeed = 54,
					FloatFactor = 0.2,
				},
				{ Id = "Finish", Kind = "Island", Island = 9, Link = "Launch" },
				{
					Id = "Land09",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.8,
					TurnDegrees = 19.5471,
				},
				{ Id = "Lane11", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.1 },
			},
		},
	},
}

return TiptoeTrials
