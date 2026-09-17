-- Name: SummitSplash.luau
-- Author: Jack C.
-- Description: HANDOFF.md section 7.7's hardening of the authored Summit Splash course, declared as a SourcePatch layout: the arc centreline, eight sectors, start, four checkpoints, finish and rising-liquid schedule are preserved from ServerStorage.SplashdownAuthoringSources.SummitSource, and this spec names only what the patch removes, retains, relocates, encloses and adds. Every radius, angle and deck height here was measured on that source in place 121997450145716 and is written up in docs/splashdown/courses/summit-splash.md.
-- Created: 2026-09-16

--!strict

-- The measured arc. The authored recipe laid eight annular sectors from angle 180,
-- each 5 studs above the last; raycasting the clone at 0.25-stud radial steps put
-- every sector's walkable band at r 156.0 .. 200.0 with the route on r 180.
local INNER_RADIUS = 156.0
local OUTER_RADIUS = 200.0
local ROUTE_RADIUS = 180.0

-- Guard walls: wall_001 at 0.8 is 15.1172 long, 18.3522 tall, 6.1708 thick, with
-- its Support socket at its own bottom centre. Bedded 1 stud into the deck it
-- stands 17.3522 studs proud -- over 7.7.7's 14-stud minimum and under the
-- measured 19.4-stud clearance to the underside of the sector stacked above.
local WALL = 0.8
local WALL_BED = -1.0

-- A gate's inner wall deliberately OVERHANGS the deck's inner edge. A jump between
-- two points on the inner edge bows inward: at the measured 22-stud reach the
-- deepest a runner can dip is sqrt(156^2 - 11^2) = 155.61. An inner wall reaching
-- r 152.44 is therefore under every jump a runner can make, which is what closes
-- 7.7.7's "inside shortcut" for good. The outer side needs no such margin, because
-- a chord between two points at r 200 never leaves r 200.
local GATE_INNER_R = 160.0 -- spans 152.44 .. 167.56
local GATE_OUTER_R = 195.56 -- spans 188.00 .. 203.12
-- Passage between them: 167.56 .. 188.00, 20.44 studs, inside the windmill bar's
-- measured 167.18 .. 192.82 sweep and the mace's 168.10 .. 191.90.

-- A seesaw gate seals everything except the board itself, so it takes four walls.
local SEESAW_INNER_A = 160.0 -- 152.44 .. 167.56
local SEESAW_INNER_B = 169.8 -- 162.24 .. 177.36
local SEESAW_OUTER_A = 190.1 -- 182.54 .. 197.66
local SEESAW_OUTER_B = 195.5 -- 187.94 .. 203.06

-- Measured radial reach of each retained hazard, used by the gate seal audit.
-- Windmill: obstacle_25_002's bar is 25.6317 long at the course's own 0.55 scale,
-- spinning about the post on the centreline. Mace: an 11.42-stud chain rocking 50
-- degrees carries a 6.33-stud ball, so 11.42*sin(50) + 3.165 = 11.914.
local WINDMILL_SWEEP = 12.8159
local MACE_SWEEP = 11.914
-- The seesaw's pedestal and board are 9.3183 * 0.55 = 5.125 across, so the board
-- plugs r 177.44 .. 182.56 of its gate at deck level as well as above it.
local SEESAW = 0.55
local SEESAW_HALF = 9.3183 * SEESAW / 2

-- The board's walkable top stands (17.7227 + 9.3184) * 0.55 = 14.873 studs above
-- the pedestal's own base, and at 18 degrees of tilt its lowest point is
-- (22.0235 - (23*sin18 + 5.125*cos18)) * 0.55 = 5.52 studs above that base. Sinking
-- the pedestal by exactly that 5.52 puts its base flush with the arc slab's 5.6-stud
-- underside and grazes the board's lowest tilt point along the deck, which leaves a
-- measured 9.35-stud step up onto the board -- inside the measured 11.5-stud
-- step-up, with 2.15 studs to spare.
local SEESAW_SINK = -5.52
local SEESAW_BOARD_TOP = 14.873 + SEESAW_SINK -- 9.353
-- Half the board's own travel, in degrees of arc at r 180: the entry socket sits
-- 23 * 0.55 = 12.65 studs back along the route from the pedestal.
local SEESAW_ENTRY_OFFSET = math.deg(12.65 / ROUTE_RADIUS) -- 4.026

local function windmillGate(id: string, angle: number, deckY: number, source: string, pieceId: string)
	return {
		{
			Id = pieceId,
			Kind = "Retain" :: "Retain",
			Preset = "Spinner" :: "Spinner",
			SourceInstance = source,
			AngleDegrees = angle,
			Radius = ROUTE_RADIUS,
			DeckY = deckY,
			GateId = id,
			SweepHalfWidth = WINDMILL_SWEEP,
		},
		{
			Id = id .. "_WallInner",
			Kind = "Mount" :: "Mount",
			Preset = "Prop" :: "Prop",
			Source = "wall_001",
			Scale = WALL,
			AngleDegrees = angle,
			Radius = GATE_INNER_R,
			DeckY = deckY,
			OffsetUp = WALL_BED,
			GuardWall = true,
			GateId = id,
		},
		{
			Id = id .. "_WallOuter",
			Kind = "Mount" :: "Mount",
			Preset = "Prop" :: "Prop",
			Source = "wall_002",
			Scale = WALL,
			AngleDegrees = angle,
			Radius = GATE_OUTER_R,
			DeckY = deckY,
			OffsetUp = WALL_BED,
			GuardWall = true,
			GateId = id,
		},
	}
end

local function maceGate(id: string, angle: number, deckY: number, source: string, pieceId: string)
	local pieces = windmillGate(id, angle, deckY, source, pieceId)
	pieces[1].Preset = "Mace" :: any
	pieces[1].SweepHalfWidth = MACE_SWEEP
	return pieces
end

-- A bumper gate is the same enclosure with a bumper in the passage instead of a
-- sweep. It declares no SweepHalfWidth, because a bumper is NOT meant to seal the
-- passage: the walls close both edge strips and the bumper leaves one measured slot
-- to swerve through, which is 8.4's "cannot avoid all contacts without ... the
-- required precision manoeuvre" rather than an unavoidable wall of mesh.
local function bumperGate(id: string, angle: number, deckY: number, source: string, pieceId: string, radius: number)
	return {
		{
			Id = pieceId,
			Kind = "Retain" :: "Retain",
			Preset = "Bumper" :: "Bumper",
			SourceInstance = source,
			-- The only retained hazards this patch MOVES. A bumper's authored mounting
			-- is its bounding-box bottom on the deck, which is exactly how
			-- relocateAssembly re-seats it, so moving one loses nothing; the windmills
			-- and maces are left where the authored course put them, because their
			-- mounting heights are not their bounding-box bottoms.
			Relocate = true,
			AngleDegrees = angle,
			Radius = radius,
			DeckY = deckY,
			GateId = id,
		},
		{
			Id = id .. "_WallInner",
			Kind = "Mount" :: "Mount",
			Preset = "Prop" :: "Prop",
			Source = "wall_001",
			Scale = WALL,
			AngleDegrees = angle,
			Radius = GATE_INNER_R,
			DeckY = deckY,
			OffsetUp = WALL_BED,
			GuardWall = true,
			GateId = id,
		},
		{
			Id = id .. "_WallOuter",
			Kind = "Mount" :: "Mount",
			Preset = "Prop" :: "Prop",
			Source = "wall_002",
			Scale = WALL,
			AngleDegrees = angle,
			Radius = GATE_OUTER_R,
			DeckY = deckY,
			OffsetUp = WALL_BED,
			GuardWall = true,
			GateId = id,
		},
	}
end

local function seesawGate(id: string, angle: number, deckY: number, pieceId: string)
	local walls = {}
	for index, radius in { SEESAW_INNER_A, SEESAW_INNER_B, SEESAW_OUTER_A, SEESAW_OUTER_B } do
		table.insert(walls, {
			Id = string.format("%s_Wall%02d", id, index),
			Kind = "Mount" :: "Mount",
			Preset = "Prop" :: "Prop",
			Source = if index <= 2 then "wall_001" else "wall_002",
			Scale = WALL,
			AngleDegrees = angle,
			Radius = radius,
			DeckY = deckY,
			OffsetUp = WALL_BED,
			GuardWall = true,
			GateId = id,
		})
	end
	local pieces = {
		{
			Id = pieceId,
			Kind = "Chain" :: "Chain",
			Preset = "Seesaw" :: "Seesaw",
			Source = "obstacle_25_001",
			Scale = SEESAW,
			MaxTiltDegrees = 18,
			AngleDegrees = angle - SEESAW_ENTRY_OFFSET,
			Radius = ROUTE_RADIUS,
			DeckY = deckY,
			OffsetUp = SEESAW_BOARD_TOP,
			GateId = id,
			SweepHalfWidth = SEESAW_HALF,
		},
	}
	for _, wall in walls do
		table.insert(pieces, wall :: any)
	end
	return pieces
end

local function concat(...)
	local out = {}
	for _, list in { ... } do
		for _, item in list do
			table.insert(out, item)
		end
	end
	return out
end

return {
	Version = 1,
	Id = "SummitSplash",
	DisplayName = "SUMMIT SPLASH",
	-- Override 2 scores the headline at whichever granularity it names. Summit's is
	-- the sliding wall across the narrowed inward bridge: Ball Barrage is the only
	-- other course that places one and it is not the dominant preset of any of its
	-- beats, so neither dominance rule is touched.
	Headline = "Sweeper",
	-- Preserved from src/config/Gameplay/Splashdown.luau's existing Courses entry,
	-- which HANDOFF 3.1 freezes.
	Difficulty = 3,
	ParSeconds = 115,
	CapSeconds = 210,
	CloseWindowSeconds = 45,
	Layout = {
		Kind = "SourcePatch",
		BoundsRadius = 200,
		LiquidY = -50,
		SourcePatch = {
			SourceName = "SummitSource",
			ExpectedBaseParts = 258,
			SectorStartDegrees = 180,
			Sectors = {
				{ SpanDegrees = 90, TopY = -20 },
				{ SpanDegrees = 45, TopY = -15 },
				{ SpanDegrees = 56, TopY = -10 },
				{ SpanDegrees = 56, TopY = -5 },
				{ SpanDegrees = 90, TopY = 0 },
				{ SpanDegrees = 45, TopY = 5 },
				{ SpanDegrees = 56, TopY = 10 },
				{ SpanDegrees = 45, TopY = 15 },
			},
			-- The 30 start pads sit on angle 195, not on the first sector's own edge.
			RouteStartDegrees = 195,
			RouteRadius = ROUTE_RADIUS,
			InnerRadius = INNER_RADIUS,
			OuterRadius = OUTER_RADIUS,
			SampleDegrees = 3,
			GuardWallMinAboveDeck = 14,
			StackedClearanceStuds = 19.4,
			-- Measured character envelope: anything under this cannot be walked
			-- through, anything over it is an inside shortcut.
			MaxUnsealedStuds = 1.9,
			BridgeAngleDegrees = 295,
			BridgeOuterRadius = 162.8,
			BridgeInnerRadius = 85.2,
			BridgeDeckY = 17.5,
			-- One 16.25-stud road column instead of three: 7.7.6's narrowing, on the
			-- original centreline.
			BridgeHalfWidth = 8.125,
			PlazaRadius = 85.2,
			PlazaTopY = 20,
			LiquidRiseStuds = 60,
			LiquidRiseDelaySeconds = 20,
			LiquidRiseSeconds = 140,
			-- 7.7.2: every hazard here was measured redundant, purely avoidable, or
			-- surplus to 7.7.3's cap of 5 RotorBumps and 5 Bumpers. The nine chicane
			-- walls go because their tops stand 11.57 studs over the deck against a
			-- measured 11.5-stud step-up. The six road slabs go because 7.7.6 narrows
			-- the bridge on its own centreline.
			Remove = {
				"sd_obstacle_25.002",
				"sd_obstacle_25.003",
				"sd_obstacle_25.005",
				"sd_obstacle_25.006",
				"sd_obstacle_25.007",
				"sd_obstacle_5_001.001",
				"sd_obstacle_5_001.002",
				"sd_obstacle_5_001.004",
				"sd_obstacle_5_001.006",
				"sd_obstacle_5_001.007",
				"sd_obstacle_5_001.008",
				"sd_obstacle_5_001.009",
				"sd_obstacle_19_001.002",
				"sd_obstacle_19_001.004",
				"sd_obstacle_19_001.005",
				"sd_obstacle_19_001.006",
				"sd_obstacle_19_001.010",
				"sd_obstacle_19_001.011",
				"sd_obstacle_19_001.012",
				"sd_obstacle_19_001.013",
				"sd_obstacle_19_001.014",
				"sd_obstacle_19_001.015",
				"sd_obstacle_19_001.016",
				"sd_arc_chicane.001",
				"sd_arc_chicane.002",
				"sd_arc_chicane.003",
				"sd_arc_chicane.004",
				"sd_arc_chicane.005",
				"sd_arc_chicane.006",
				"sd_arc_chicane.007",
				"sd_arc_chicane.008",
				"sd_arc_chicane.009",
				"sd_road.001",
				"sd_road.003",
				"sd_road.004",
				"sd_road.006",
				"sd_road.007",
				"sd_road.009",
			},
		},
	},
	Beats = {
		{
			Id = "01_OpeningClimb",
			Family = "Climb/Descend",
			Mechanic = "SummitArcOpening",
			LengthTarget = 377,
			Segment = "Arc",
			EndAngleDegrees = 315,
			Pieces = concat(
				windmillGate("Gate01", 236.25, -20, "sd_obstacle_25.001", "Windmill01"),
				bumperGate("Gate02", 266.75, -20, "sd_obstacle_19_001.001", "Bumper01", 176.5)
			),
		},
		{
			Id = "02_SweepTiming",
			Family = "Timing",
			Mechanic = "SummitBoardAndPendulum",
			LengthTarget = 176,
			Segment = "Arc",
			EndAngleDegrees = 371,
			Pieces = concat(
				seesawGate("Gate03", 330.0, -10, "Seesaw01"),
				maceGate("Gate04", 351.0, -10, "sd_obstacle_5_001.003", "Mace01"),
				bumperGate("Gate05", 361.67, -10, "sd_obstacle_19_001.003", "Bumper02", 179.06)
			),
		},
		{
			Id = "03_BumperChicane",
			Family = "Precision",
			Mechanic = "SummitStaggeredChicane",
			LengthTarget = 176,
			Segment = "Arc",
			EndAngleDegrees = 427,
			Pieces = concat(
				windmillGate("Gate06", 399.0, -5, "sd_obstacle_25.004", "Windmill02"),
				bumperGate("Gate07", 406.0, -5, "sd_obstacle_19_001.007", "Bumper03", 174.5),
				bumperGate("Gate08", 414.0, -5, "sd_obstacle_19_001.008", "Bumper04", 185.5)
			),
		},
		{
			Id = "04_BalanceRise",
			Family = "Ride",
			Mechanic = "SummitBoardOverRisingLava",
			LengthTarget = 424,
			Segment = "Arc",
			EndAngleDegrees = 562,
			Pieces = concat(
				seesawGate("Gate09", 445.0, 0, "Seesaw02"),
				maceGate("Gate10", 468.75, 0, "sd_obstacle_5_001.005", "Mace02"),
				bumperGate("Gate11", 480.0, 0, "sd_obstacle_19_001.009", "Bumper05", 179.06)
			),
		},
		{
			Id = "05_AirGate",
			Family = "Launch",
			Mechanic = "SummitOutdraftAndFoamLedge",
			LengthTarget = 317,
			Segment = "Arc",
			EndAngleDegrees = 663,
			Pieces = concat({
				-- The fan stands on the inner lane boundary and blows radially OUTWARD
				-- across the lane, toward the outer ledge; the pad there is the
				-- marked, slow way back.
				{
					Id = "Fan01",
					Kind = "Mount" :: "Mount",
					Preset = "Fan" :: "Fan",
					Source = "propeller_trampoline_1_001",
					Scale = 0.5,
					AngleDegrees = 582.0,
					Radius = 171.0,
					DeckY = 10,
					FanAxis = "X" :: "X",
					FanDirection = 1,
					FanColumnHeight = 34,
					LaunchSpeed = 40,
					FloatFactor = 0.2,
					GateId = "Gate12",
				},
				{
					Id = "Gate12_WallInner",
					Kind = "Mount" :: "Mount",
					Preset = "Prop" :: "Prop",
					Source = "wall_001",
					Scale = WALL,
					AngleDegrees = 582.0,
					Radius = GATE_INNER_R,
					DeckY = 10,
					OffsetUp = WALL_BED,
					GuardWall = true,
					GateId = "Gate12",
				},
				{
					Id = "JumpPad01",
					Kind = "Mount" :: "Mount",
					Preset = "JumpPad" :: "JumpPad",
					Source = "trampoline_1_001",
					Scale = 0.6,
					AngleDegrees = 592.0,
					Radius = 196.0,
					DeckY = 10,
					LaunchSpeed = 48,
					FloatFactor = 0.2,
				},
			}, windmillGate("Gate13", 608.67, 10, "sd_obstacle_25.008", "Windmill03")),
		},
		{
			Id = "06_FinalFooting",
			Family = "Timing",
			Mechanic = "SummitSweptBridge",
			LengthTarget = 107,
			Segment = "Bridge",
			Pieces = {
				{
					Id = "Sweeper01",
					Kind = "Mount" :: "Mount",
					Preset = "Sweeper" :: "Sweeper",
					Source = "obstacle_2_001",
					Scale = 0.55,
					Facing = "Radial" :: "Radial",
					AngleDegrees = 295.0,
					Radius = 128.0,
					DeckY = 17.5,
					-- A slide's amplitude is studs: 27.20 of frame plus 2 x 8 sweeps
					-- 43.2 studs across a 16.25-stud bridge, so there is nowhere on it
					-- the wall does not reach.
					RotorAmplitude = 8,
					RotorPeriod = 3.2,
					RotorPhase = 0,
				},
			},
		},
		{
			Id = "07_SummitSprint",
			Family = "Climb/Descend",
			Mechanic = "SummitPlazaApproach",
			LengthTarget = 85,
			Segment = "Plaza",
			Pieces = {},
		},
	},
}
