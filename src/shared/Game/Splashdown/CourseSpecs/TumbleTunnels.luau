-- Name: TumbleTunnels.luau
-- Author: Jack C.
-- Description: Declarative spec for Tumble Tunnels (HANDOFF.md section 7.4): a Loop layout -- a closed circuit whose two long runs straddle the map's centre line and form the tunnel spine, crossed outbound through arch_004 and on the return through arch_006 -- carrying two real server-owned beach balls behind a horizontal opposing fan, two rider-weighted seesaw boards that ARE the route's floor, a single mallet at an arch-ramp crest, a forced bumper chicane, a fan gate, and a paddle wheel and swing panel inside the return tunnel. Beat length targets are the scaled section 7.4 targets recorded in docs/splashdown/03-overrides.md. Every scale, speed and socket figure traces to AssetManifest or to the measured evidence cited in docs/splashdown/courses/tumble-tunnels.md.
-- Created: 2026-09-16

--!strict

local CourseBuilder = require(script.Parent.Parent.CourseBuilder)

-- HANDOFF 5.2 guide: "A closed circuit around a central tunnel spine (arch_004
-- outbound, arch_006 return) that the route crosses twice. Start and finish sit
-- near each other on the outside of the loop but are separated by enclosure so the
-- finish is unreachable from the start plaza. Ball paths stay inside the 380
-- radius."
--
-- The circuit is run / cross / run / cross / stub, four right turns, -360 degrees.
-- The two long runs sit at z = -+RUN_Z, so the whole middle of the course is the
-- two tunnel corridors and the circuit wraps around them. Segment lengths are not
-- round numbers by choice: they put one corner in each of beats 02, 03, 06 and 07,
-- leave every corner's approach fill a clean slab rather than a sliver, and land
-- the finish 69.27 studs from the start plaza -- 25.84 studs of open water between
-- the two plaza edges, past the measured 22-stud maximum jump.
local RUN_1 = 277
local RUN_2 = 377
local STUB = 31
local LANE_PITCH = 98
local RUN_Z = 49
local X_A = -88.5
local X_E = X_A + RUN_1
local X_W = X_E - RUN_2

-- box_011 is a measured descending ramp: at scale s it travels 138 * s studs and
-- drops 28.5 * s. Entered from its low end (Reversed) it is the only climb the kit
-- can make. slide_001 drops 51.8 * s over 25 * s of travel.
local RAMP_3 = 0.1053
local RAMP_6 = 0.2105
local RAMP_12 = 0.4211
local SLIDE_12 = 0.2317

-- The outbound tunnel. arch_004's measured bore is 43.2 studs wide at deck level
-- with 7.6 studs of solid skirt each side, so at 0.58 the bore is 25.06 studs and
-- the skirts are 4.41 -- taller than a 4.66-stud beach ball, which is what pens the
-- balls in the corridor. The deck inside is deliberately narrower again (18.22) so
-- it cannot hold a 24 x 24 breather square and the 3.4-stud gap to each skirt is
-- narrower than a ball. TUNNEL_04_SINK drops the arch by its own threshold height
-- so the mouth's threshold slab finishes flush with the deck instead of standing
-- 3.5 studs proud of it.
local TUNNEL_04 = 0.58
local TUNNEL_04_SINK = -(20.3889 - 14.43) * TUNNEL_04

-- The landing gate in beat 05. It has to fit inside the 25.22-stud landing deck, so
-- it is small: a 12.1-stud bore a launched racer has to come down through, with
-- 7.43 studs of headroom on the centre line -- above the flight's measured 8.4-stud
-- apex over the launch deck, and below a standing jump.
local ARCH_05 = 0.28
local ARCH_05_SINK = -(20.3889 - 14.43) * ARCH_05

-- The return tunnel. Sized by what lives inside it rather than by taste: a 0.5
-- paddle wheel is 29.91 studs across its axle, so the bore has to clear 30, and at
-- 0.78 it clears 33.7 with 17.71 to 20.66 studs of headroom. 70.09 studs long,
-- which fits the 78.22 studs of straight run this beat has before its corner.
local TUNNEL_06 = 0.78
local TUNNEL_06_SINK = -(20.3889 - 14.43) * TUNNEL_06

-- The paddle wheel hangs 8 studs below its own deck. AssetManifest's Support socket
-- is the lowest point the cradles sweep, so mounting at 0 puts the blades at deck
-- level and the wheel's 24.02-stud frame needs a near-full-size arch over it. Hung
-- at -8 the lower cradles pass beneath the bridge and the upper ones sweep from 4.8
-- studs below the deck to 13.9 above it -- straight through rider height, which is
-- the point of the encounter.
local WHEEL_HANG = -8

-- Seesaw geometry, measured: the board's walkable top is 17.7227 studs above the
-- pedestal's own centre and the pedestal's lowest collision point is -9.3184, so at
-- 0.6 the board top sits 16.2247 studs above the pedestal's base. Each pedestal
-- therefore needs a plinth reaching from the liquid plane up to exactly that point;
-- platform_002 stands 28.575 * s studs above its Support socket.
local SEESAW = 0.6
local SEESAW_DROP = (17.7227 + 9.3184) * SEESAW
local LIQUID_Y = -20
local function plinthScale(boardTopY: number): number
	return (boardTopY - SEESAW_DROP - LIQUID_Y) / 28.575
end

-- Foam channel decking. Section 7.4 fixes the centreline at 112 studs; six
-- uniformly scaled slabs make exactly 111.99 studs of 14.86-stud-wide channel.
local FOAM_SLAB = 0.2121
local FOAM_STEP = 88 * FOAM_SLAB

local function foamDecks(idPrefix: string, firstOffsetAlong: number, side: number, up: number): { any }
	local pieces = {}
	for index = 1, 6 do
		table.insert(pieces, {
			Id = string.format("%s%02d", idPrefix, index),
			Kind = "Flank",
			Preset = "Platform",
			Source = "platform_002",
			Scale = FOAM_SLAB,
			OffsetAlong = firstOffsetAlong + (index - 1) * FOAM_STEP,
			OffsetSide = side,
			OffsetUp = up,
		})
	end
	return pieces
end

-- The enclosure between the start plaza and the finish deck: ONE door panel stood
-- on end in the water, mid-gap, uniformly scaled to 1.2 so it is 90.2 studs across,
-- 7.5 thick and 54.9 tall -- 34.9 studs above the start plaza and 22.9 above the
-- finish deck, both past the 14-stud anti-skip minimum, and wider than the start
-- plaza is round.
--
-- It is one piece on purpose. The first build stacked six platform slabs here and
-- the cut-set audit rejected it: a platform's top is a broad bevelled face, so each
-- slab left a standable rim proud of the one above, and the graph found a 21-stud
-- hop from the start plaza onto the third rim and a second hop from there straight
-- onto the finish deck -- 30 of 30 spawn cells bypassing all seven gates. Two
-- thinner door panels failed the same way for the same reason: the lower panel's
-- rim was still standable. This is the staircase failure Door Dash's roof hit three
-- times, and the only reliable fix is geometry with no intermediate top at all.
-- The panel carries no Door attributes: it is a Prop in Geometry, invisible to
-- DoorRows and to MapFeatureService.
local WALL = 1.2

local function enclosure(): { any }
	return {
		{
			Id = "Wall01",
			Kind = "Mount",
			Preset = "Prop",
			Source = "door_002",
			Scale = WALL,
			MountTo = "Liquid",
			-- Mid-gap: the plaza edges are 25.84 studs apart and the panel is 7.5
			-- thick, so it stands clear of both.
			OffsetAlong = 29.9,
		},
	}
end

local function concat(...: { any }): { any }
	local out = {}
	for _, list in { ... } do
		for _, value in list do
			table.insert(out, value)
		end
	end
	return out
end

local TumbleTunnels: CourseBuilder.CourseSpec = {
	Version = 1,
	Id = "TumbleTunnels",
	DisplayName = "Tumble Tunnels",
	-- HANDOFF 7.4: "Headline: two physical beach balls pushed toward racers inside
	-- constrained tunnels." Beach balls appear in no other course in the set.
	Headline = "BeachBall",
	Difficulty = 3,
	ParSeconds = 75,
	CapSeconds = 180,
	CloseWindowSeconds = 60,
	Layout = {
		Kind = "Loop",
		LanePitch = LANE_PITCH,
		BoundsRadius = 300,
		LiquidY = LIQUID_Y,
		Guide = {
			Vector3.new(X_A, 0, -RUN_Z),
			Vector3.new(X_E, 0, -RUN_Z),
			Vector3.new(X_E, 0, RUN_Z),
			Vector3.new(X_W, 0, RUN_Z),
			Vector3.new(X_W, 0, -RUN_Z),
			Vector3.new(X_W + STUB, 0, -RUN_Z),
		},
		Loop = {
			-- The finish measures 69.27 studs from the start plaza: near enough to read
			-- as the same corner of the map, far enough that the plaza edges are 25.84
			-- studs apart across open water.
			ClosureMinStuds = 48,
			ClosureMaxStuds = 92,
			-- Half the lane pitch is 49, so the two corridors really are central.
			SpineHalfWidth = 60,
			OutboundTunnelPieceId = "Tunnel04",
			ReturnTunnelPieceId = "Tunnel06",
		},
		Corner = { Source = "platform_002", Scale = 0.3 },
		Fill = { Source = "platform_002", Scale = 0.3 },
	},
	-- HANDOFF 7.4: "StartY 0."
	Start = { Rows = 5, Columns = 6, Spacing = 6, Heading = -90, Position = Vector3.new(X_A, 0, -RUN_Z) },
	Beats = {
		{
			Id = "01_BallBore",
			Family = "Crowd",
			Mechanic = "BallTunnel",
			LengthTarget = 165,
			Pieces = {
				{ Id = "Lane01", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.30 },
				{
					Id = "Climb01",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				-- The spine's outbound crossing. Centred over the three narrow slabs that
				-- follow, with its mouth thresholds flush with their tops.
				{
					Id = "Tunnel04",
					Kind = "Mount",
					Preset = "Prop",
					Source = "arch_004",
					Scale = TUNNEL_04,
					OffsetAlong = 26.055,
					OffsetUp = TUNNEL_04_SINK,
				},
				-- Two real beach balls, on opposite sides of an 18.22-stud lane so between
				-- them they cover it. Section 6 fixes the scale at .5; the kit unanchors
				-- them and takes server ownership at runtime, which is why the template
				-- ships them anchored.
				{
					Id = "Ball01",
					Kind = "Mount",
					Preset = "BeachBall",
					Source = "ball_001",
					Scale = 0.5,
					OffsetAlong = 15,
					OffsetSide = -4.5,
				},
				{
					Id = "Ball02",
					Kind = "Mount",
					Preset = "BeachBall",
					Source = "ball_001",
					Scale = 0.5,
					OffsetAlong = 37,
					OffsetSide = 4.5,
				},
				{ Id = "Lane02", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.26 },
				{ Id = "Lane03", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.26 },
				{ Id = "Lane04", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.328 },
				-- The opposing fan, laid on its side so the visible grate faces back down
				-- the tunnel (02-kits.md: "Rotate the fan so the visual grate faces the
				-- same direction"). It stands just past the tunnel's far mouth because a
				-- 17.69-stud cage on its side does not fit under a 12.93-stud ceiling, and
				-- 2.6 studs off centre so the 5.25-stud passage beside it is the way past.
				-- OffsetUp puts the column's axis 2.4 studs above the deck rather than
				-- 8.85: the measured column is a 6.19-stud-radius cylinder and a ball's
				-- centre is only 2.33 studs up, so mounted flush the balls would have sat
				-- outside their own fan. FanColumnHeight is raised from section 6's seed of
				-- 18 to 55 so the column reaches the length of the tunnel.
				{
					Id = "Fan01",
					Kind = "Mount",
					Preset = "Fan",
					Source = "propeller_trampoline_1_001",
					Scale = 0.5,
					OffsetAlong = -14,
					OffsetSide = 2.6,
					OffsetUp = 2.4,
					PitchDegrees = -90,
					FacingOffsetDegrees = 180,
					FanAxis = "Y",
					FanDirection = 1,
					FanColumnHeight = 55,
					FanBallSpeed = 32,
					LaunchSpeed = 48,
					FloatFactor = 0.2,
				},
				{ Id = "Lane05", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.26 },
			},
		},
		{
			Id = "02_TiltMouth",
			Family = "Ride",
			Mechanic = "SeesawExits",
			LengthTarget = 132,
			Pieces = {
				-- The lane narrows into the boards: a 3-stud ramp is 6.35 studs wide, the
				-- board itself 5.59. That narrowing is the hazard, and both edges are open
				-- water.
				{ Id = "Drop02a", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_3 },
				{
					Id = "Seesaw01",
					Kind = "Chain",
					Preset = "Seesaw",
					Source = "obstacle_25_001",
					Scale = SEESAW,
					MaxTiltDegrees = 18,
				},
				{
					Id = "Plinth01",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_002",
					Scale = plinthScale(2.998),
					MountTo = "Liquid",
					OffsetAlong = -13.8,
				},
				{ Id = "Drop02b", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_3 },
				{ Id = "Corner01", Kind = "Corner", Direction = "Right" },
				{
					Id = "Seesaw02",
					Kind = "Chain",
					Preset = "Seesaw",
					Source = "obstacle_25_001",
					Scale = SEESAW,
					MaxTiltDegrees = 24,
				},
				{
					Id = "Plinth02",
					Kind = "Mount",
					Preset = "Prop",
					Source = "platform_002",
					Scale = plinthScale(-0.003),
					MountTo = "Liquid",
					OffsetAlong = -13.8,
				},
				-- The beat has to end on static floor: CourseBuilder pulls the next beat's
				-- checkpoint pad back onto the last slab, and a checkpoint on a tilting
				-- board is not the "stable static support" HANDOFF 5.1.8 requires.
				{ Id = "Lane06", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.12 },
			},
		},
		{
			Id = "03_ArchAscent",
			Family = "Climb/Descend",
			Mechanic = "ArchRamp",
			LengthTarget = 121,
			Pieces = {
				{ Id = "Lane07", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.20 },
				{ Id = "Corner02", Kind = "Corner", Direction = "Right" },
				{
					Id = "Climb03",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_12,
					Reversed = true,
				},
				{ Id = "Lane08", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.16 },
				-- The single mallet, standing on the right-hand edge of the crest deck. Its
				-- head reaches 7.56 studs from the post, so at rest it covers the lane's
				-- centre line; retuned from the windup/strike hammer profile to a
				-- symmetric rock (period 3.6s) that clears the centre line for roughly
				-- half of each cycle and lets it back down over the other half.
				{
					Id = "Mallet01",
					Kind = "Mount",
					Preset = "Mallet",
					Source = "obstacle_1_001",
					Scale = 0.6,
					OffsetAlong = -7,
					OffsetSide = 4.5,
					RotorAmplitude = 55,
					RotorPeriod = 3.6,
					ShoveSpeed = 58,
				},
			},
		},
		{
			Id = "04_BumperBend",
			Family = "Precision",
			Mechanic = "ForcedChicane",
			LengthTarget = 121,
			Pieces = concat(
				{
					{ Id = "Lane09", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.30 },
					-- The bend is the chicane's own stagger: the cube sits 5.5 studs left and
					-- the triangle 5.5 right and 12 studs further on, and their footprints
					-- overlap in the lane's cross-section, so no straight line clears both.
					{
						Id = "BumpCube",
						Kind = "Mount",
						Preset = "Bumper",
						Source = "obstacle_18_001",
						Scale = 0.5,
						OffsetAlong = -16,
						OffsetSide = -5.5,
						EncounterGroup = "Chicane01",
					},
					{
						Id = "BumpTri",
						Kind = "Mount",
						Preset = "Bumper",
						Source = "obstacle_19_001",
						Scale = 0.5,
						OffsetAlong = -4,
						OffsetSide = 5.5,
						EncounterGroup = "Chicane01",
					},
					{ Id = "Drop04", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6 },
					{ Id = "Lane10", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.30 },
				},
				foamDecks("FoamDeckA", -81.849, -17.94, -6),
				{
					{ Id = "Lane11", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.28 },
				}
			),
		},
		{
			Id = "05_AirArch",
			Family = "Launch",
			Mechanic = "FanGate",
			LengthTarget = 99,
			Pieces = {
				{ Id = "Lane12", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.12 },
				{
					Id = "Climb05",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{ Id = "Lane13", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.20 },
				-- Sunk 12 studs, the pilot's own mounting, so the grate finishes flush with
				-- the launch deck and a runner crossing it is inside the column.
				{
					Id = "Fan02",
					Kind = "Mount",
					Preset = "Fan",
					Source = "propeller_trampoline_1_001",
					Scale = 0.5,
					OffsetAlong = -8,
					OffsetUp = -12,
					FanAxis = "Y",
					FanDirection = 1,
					LaunchSpeed = 48,
					FloatFactor = 0.2,
				},
				{ Id = "Gap05", Kind = "Advance", OffsetAlong = 14, OffsetUp = 6 },
				{ Id = "Lane14", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.2866 },
				-- The landing gate. A 12.1-stud bore inside a 20.08-stud deck, with its
				-- canopy 7.43 studs up: the launch's measured 8.4-stud apex passes under it
				-- and a standing jump does not.
				{
					Id = "Arch05",
					Kind = "Mount",
					Preset = "Prop",
					Source = "arch_005",
					Scale = ARCH_05,
					OffsetAlong = -12.6,
					OffsetUp = ARCH_05_SINK,
				},
				-- The dumbbell guards the landing's exit. Its 19.18-stud bar sweeps the full
				-- width of the deck it stands on, so the gate is guarded rather than
				-- decorated. Speed comes from section 6's formula at the measured contact
				-- radius, not a chosen number.
				{
					Id = "Dumbbell01",
					Kind = "Mount",
					Preset = "Spinner",
					Source = "obstacle_6_001",
					Scale = 0.5,
					OffsetAlong = 6,
				},
			},
		},
		{
			Id = "06_TunnelTug",
			Family = "Timing",
			Mechanic = "ReturnTunnel",
			LengthTarget = 154,
			Pieces = concat(
				{
					-- The spine's second crossing.
					{
						Id = "Tunnel06",
						Kind = "Mount",
						Preset = "Prop",
						Source = "arch_006",
						Scale = TUNNEL_06,
						OffsetAlong = 36.4,
						OffsetUp = TUNNEL_06_SINK,
					},
					{ Id = "Lane15", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.33 },
					{
						Id = "PaddleWheel01",
						Kind = "Mount",
						Preset = "PaddleWheel",
						Source = "obstacle_24_001",
						Scale = 0.5,
						OffsetAlong = -14,
						OffsetUp = WHEEL_HANG,
					},
				},
				foamDecks("FoamDeckB", -49.641, -13.0, -6),
				{
					{ Id = "Lane16", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.33 },
					-- Raised five studs and phased at 1.4, so it is posed differently from
					-- Whirlpool Waltz's panel as override 2 requires.
					{
						Id = "SwingPanel01",
						Kind = "Mount",
						Preset = "SwingPanel",
						Source = "obstacle_8_001",
						Scale = 0.5,
						OffsetAlong = -10,
						OffsetUp = 5,
						RotorAmplitude = 28,
						RotorPeriod = 2.8,
						RotorPhase = 1.4,
					},
					{ Id = "Corner03", Kind = "Corner", Direction = "Right" },
					{
						Id = "Climb06",
						Kind = "Chain",
						Preset = "Ramp",
						Source = "box_011",
						Scale = RAMP_6,
						Reversed = true,
					},
					{ Id = "Lane17", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.12 },
				}
			),
		},
		{
			Id = "07_ExitSlide",
			Family = "Climb/Descend",
			Mechanic = "ShortDescent",
			LengthTarget = 88,
			Pieces = concat({
				{ Id = "Lane18", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.20 },
				{ Id = "Slide01", Kind = "Chain", Preset = "Slide", Source = "slide_001", Scale = SLIDE_12 },
				{ Id = "Corner04", Kind = "Corner", Direction = "Right" },
				{ Id = "Lane19", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.23 },
			}, enclosure()),
		},
	},
}

return TumbleTunnels
