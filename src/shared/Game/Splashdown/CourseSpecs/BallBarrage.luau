-- Name: BallBarrage.luau
-- Author: Jack C.
-- Description: Declarative spec for the Ball Barrage pilot course (HANDOFF.md section 7.1): serpentine layout on the section 5.2 guide polyline, six beats, three Big Balls over liquid as the exclusive headline. Piece scales are chosen so each beat's measured socket arclength lands inside its section 7.1 target; those targets are design seeds, not measured timing evidence, and the Gate 3 playtest pace is what fixes the set-wide route-length target per section 5.2.
-- Created: 2026-09-15

--!strict

local CourseBuilder = require(script.Parent.Parent.CourseBuilder)

-- HANDOFF 5.2 guide: "Start at local (-180, startY, 168), facing +X. Guide
-- polyline in X/Z: (-180,168) -> (60,168) -> (60,56) -> (-180,56) -> (-180,-56)
-- -> (60,-56) -> (60,-168) -> (-180,-168). Adjacent parallel runs are separated
-- 112 studs." The route consumes the first five segments and finishes partway
-- along the third parallel run; the builder rejects any piece that would leave
-- the polyline, which is what keeps every corner inside the bounds envelope.
local GUIDE = {
	Vector3.new(-180, 0, 168),
	Vector3.new(60, 0, 168),
	Vector3.new(60, 0, 56),
	Vector3.new(-180, 0, 56),
	Vector3.new(-180, 0, -56),
	Vector3.new(60, 0, -56),
	Vector3.new(60, 0, -168),
	Vector3.new(-180, 0, -168),
}

-- The kit has no ascending ramp mesh and arc_004 was measured and rejected as a
-- turn piece (course-sockets-ballbarrage.json). Every climb is therefore a
-- measured descending ramp entered from its low end (Reversed), and every turn
-- is a platform slab entered at Entry and left through its measured side socket.
-- box_011 at 0.2105 moves 29.05 studs and 6.0 of elevation; 0.4211 doubles both.
local RAMP_6 = 0.2105
local RAMP_12 = 0.4211

local BallBarrage: CourseBuilder.CourseSpec = {
	Version = 1,
	Id = "BallBarrage",
	DisplayName = "Ball Barrage",
	Difficulty = 3,
	ParSeconds = 75,
	CapSeconds = 180,
	CloseWindowSeconds = 60,
	Layout = {
		Kind = "Serpentine",
		LanePitch = 112,
		BoundsRadius = 300,
		LiquidY = -20,
		Guide = GUIDE,
		Corner = { Source = "platform_002", Scale = 0.3 },
		Fill = { Source = "platform_002", Scale = 0.3 },
	},
	Start = { Rows = 5, Columns = 6, Spacing = 6, Heading = -90, Position = Vector3.new(-180, 0, 168) },
	Beats = {
		{
			Id = "01_Countercurrent",
			Family = "Ride",
			Mechanic = "Counterbelt",
			LengthTarget = 150,
			Pieces = {
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
					ConveyorSpeed = -18.2,
				},
				{
					Id = "Sweeper01",
					Kind = "Mount",
					Preset = "Sweeper",
					Source = "obstacle_2_001",
					Scale = 0.5,
					OffsetAlong = -14,
					RotorPhase = 0,
				},
				{ Id = "Ramp01", Kind = "Chain", Preset = "Ramp", Source = "box_013", Scale = RAMP_6, Reversed = true },
				-- Three narrow lane slabs rather than one wide one: any single slab
				-- over 24 studs across reads as a breather square to the coverage audit
				-- (HANDOFF 8.4), and platform_00x at 0.3 is 21 studs wide.
				{ Id = "Floor01", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.3 },
				{ Id = "Floor02", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.3 },
				{ Id = "Floor03", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.3 },
				-- Section 7.1's "1 forced cube+triangle chicane": two slabs, but one
				-- encounter, so they share an EncounterGroup and are scored once.
				{
					Id = "Bumper01",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_18_001",
					Scale = 0.5,
					OffsetAlong = -22,
					OffsetSide = -6,
					EncounterGroup = "Chicane01",
				},
				{
					Id = "Bumper02",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_19_001",
					Scale = 0.5,
					OffsetAlong = -10,
					OffsetSide = 6,
					EncounterGroup = "Chicane01",
				},
			},
		},
		{
			Id = "02_RedRebound",
			Family = "Precision",
			Mechanic = "BigBallChain",
			LengthTarget = 140,
			Pieces = {
				{ Id = "Ramp02", Kind = "Chain", Preset = "Ramp", Source = "box_013", Scale = RAMP_6, Reversed = true },
				-- First half of the serpentine fold: the route turns onto the
				-- 112-stud connector run that carries the whole ball chain.
				{ Id = "CornerA", Kind = "Corner", Direction = "Left" },
				{ Id = "Gap01", Kind = "Advance", OffsetAlong = 16 },
				{
					Id = "Ball01",
					Kind = "Mount",
					Preset = "BigBall",
					Source = "obstacle_23_001",
					Scale = 1,
					OffsetAlong = -8,
					OffsetSide = 0,
					MountTo = "Liquid",
				},
				{ Id = "Step01", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.15 },
				{ Id = "Gap02", Kind = "Advance", OffsetAlong = 16 },
				{
					Id = "Ball02",
					Kind = "Mount",
					Preset = "BigBall",
					Source = "obstacle_23_001",
					Scale = 1,
					OffsetAlong = -8,
					OffsetSide = 4,
					MountTo = "Liquid",
					RotorAmplitude = 5,
					RotorPeriod = 3.4,
					RotorPhase = 0.6,
				},
				{ Id = "Ramp03", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6 },
				{ Id = "Gap03", Kind = "Advance", OffsetAlong = 14 },
				{
					Id = "Ball03",
					Kind = "Mount",
					Preset = "BigBall",
					Source = "obstacle_23_001",
					Scale = 1,
					OffsetAlong = -7,
					OffsetSide = -4,
					MountTo = "Liquid",
					RotorAmplitude = 8,
					RotorPeriod = 2.8,
					RotorPhase = 1.3,
				},
			},
		},
		{
			Id = "03_PunchPass",
			Family = "Timing",
			Mechanic = "PistonLedge",
			LengthTarget = 130,
			Pieces = {
				-- Second half of the fold: back onto a full-length parallel run.
				{ Id = "CornerB", Kind = "Corner", Direction = "Left" },
				{ Id = "Ramp04", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6, Reversed = true },
				{ Id = "Floor04", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.3 },
				{
					Id = "Piston01",
					Kind = "Mount",
					Preset = "Piston",
					Source = "obstacle_22_001",
					Scale = 0.5,
					OffsetAlong = -30,
					OffsetSide = -7,
					FacingOffsetDegrees = 90,
					RotorPhase = 0,
				},
				{
					Id = "Piston02",
					Kind = "Mount",
					Preset = "Piston",
					Source = "obstacle_22_001",
					Scale = 0.5,
					OffsetAlong = -14,
					OffsetSide = 7,
					FacingOffsetDegrees = -90,
					RotorPhase = 1.6,
				},
				{ Id = "Floor05", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.3 },
				{ Id = "Floor06", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.3 },
			},
		},
		{
			Id = "04_SkyThread",
			Family = "Launch",
			Mechanic = "GuidedLaunch",
			LengthTarget = 150,
			Pieces = {
				{
					Id = "Ramp05",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_12,
					Reversed = true,
				},
				{
					Id = "Pad01",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_1_001",
					Scale = 0.6,
					OffsetAlong = -6,
					LaunchSpeed = 51,
				},
				{
					Id = "Fan01",
					Kind = "Mount",
					Preset = "Fan",
					Source = "propeller_trampoline_1_001",
					Scale = 0.5,
					OffsetAlong = 8,
					OffsetUp = -12,
					FanAxis = "Y",
					FanDirection = 1,
				},
				{ Id = "Gap04", Kind = "Advance", OffsetAlong = 18 },
				{ Id = "Land01", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.15 },
				{
					Id = "Pad02",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_1_001",
					Scale = 0.6,
					OffsetAlong = -6,
					LaunchSpeed = 54,
				},
				{ Id = "Gap05", Kind = "Advance", OffsetAlong = 18 },
				-- The landing gate is the corner slab itself: the launch has to
				-- carry the runner onto the turn, where the bumper is waiting.
				{ Id = "CornerC", Kind = "Corner", Direction = "Right" },
				{
					Id = "Bumper03",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_18_001",
					Scale = 0.5,
					OffsetAlong = -4,
				},
				{ Id = "Ramp06", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6 },
			},
		},
		{
			Id = "05_HammerHour",
			Family = "Timing",
			Mechanic = "AsymmetricStrikes",
			LengthTarget = 150,
			Pieces = {
				{ Id = "Floor07", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.3 },
				{ Id = "CornerD", Kind = "Corner", Direction = "Right" },
				{ Id = "Ramp07", Kind = "Chain", Preset = "Ramp", Source = "box_013", Scale = RAMP_6, Reversed = true },
				{ Id = "Floor08", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.3 },
				{ Id = "Floor09", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.3 },
				{
					Id = "HammerLarge",
					Kind = "Mount",
					Preset = "Hammer",
					Source = "obstacle_3_001",
					Scale = 0.6,
					OffsetAlong = -26,
					RotorAmplitude = 55,
					RotorPhase = 0,
				},
				{
					Id = "HammerSmall",
					Kind = "Mount",
					Preset = "Hammer",
					Source = "obstacle_4_001",
					Scale = 0.6,
					OffsetAlong = -8,
					RotorAmplitude = 55,
					RotorPhase = 0.7,
				},
			},
		},
		{
			Id = "06_SplashSprint",
			Family = "ClimbDescend",
			Mechanic = "FinishSlide",
			LengthTarget = 80,
			Pieces = {
				{ Id = "Floor10", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = 0.3 },
				-- slide_001 drops 51.8 studs at scale 1; 0.2317 is the -12 the
				-- section 7.1 table asks for.
				{ Id = "Slide01", Kind = "Chain", Preset = "Slide", Source = "slide_001", Scale = 0.2317 },
				-- The slide only travels 5.79 studs horizontally for its -12 drop, so the
				-- finish would otherwise sit within jump reach of the deck above it. The
				-- run-out puts the finish plaza out of that reach; the cut-set audit
				-- rejected the build without it.
				{ Id = "RunOut01", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = 0.3 },
				{ Id = "RunOut02", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = 0.3 },
				{
					Id = "Bumper04",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_19_001",
					Scale = 0.4,
					OffsetAlong = -5,
				},
			},
		},
	},
}

return BallBarrage
