-- Name: WhirlpoolWaltz.luau
-- Author: Jack C.
-- Description: Declarative spec for Whirlpool Waltz (HANDOFF.md section 7.2): a clockwise descending spiral of tangent slabs and rotating ride decks over open water, with real gaps between them, one door row and no rising liquid. Beat length targets are the section 7.2 targets, kept as written because the pilot's measured pace fixed the set-wide route length at 880 measured studs and the pilot produced 881.05 measured studs from the same 800 of beat targets (docs/splashdown/03-overrides.md). Every scale, speed and socket figure traces to AssetManifest or to the measured evidence files cited in docs/splashdown/courses/whirlpool-waltz.md.
-- Created: 2026-09-15

--!strict

local CourseBuilder = require(script.Parent.Parent.CourseBuilder)

-- HANDOFF 5.2 guide: "clockwise descending guide: angle 180 -> 660 degrees,
-- radius 190 -> 65 linearly, Y 36 -> 0 linearly, then a radial finish to the
-- hub." The 480-degree sweep, the 2.92:1 radius ratio, the sense, the descent
-- and the radial finish are all kept exactly; the radii alone are scaled so the
-- guide's own arclength matches the route instead of running a third longer and
-- stranding the finish at radius 88 instead of on the hub. That is the
-- proportional scaling override 4 asks for, and the number of turns -- which is
-- what makes a spiral read as a whirlpool -- is untouched.
--
-- Measured guide arclength at these radii: about 896 studs (845 of spiral plus a
-- 51.0-stud radial run in), against a route that consumes about 885, so the
-- finish deck lands about 11 studs from the hub centre and its 34-stud plaza
-- covers it.
local RADIUS_START = 149.2
local RADIUS_END = 51.04

-- box_011 is a measured descending ramp: at scale s it travels 138 * s studs and
-- drops 28.5 * s. slide_001 drops 51.8 * s over only 25 * s of travel, which is
-- how beat 05 buys a 10-stud drop without spending 48 studs of its length
-- budget on the ramp.
local RAMP_4 = 0.1404
local RAMP_6 = 0.2105
local SLIDE_10 = 0.1931

-- Ride-only decks use the section 6 ladder (+-45, +-60, +-75 degrees/s),
-- alternating, and carry riders without shoving: their hazard is lost support
-- and the plate's real holes.
local PIZZA_A_SPEED = 45
local PIZZA_B_SPEED = -45
local CAROUSEL_SPEED = 60
local DISC_A_SPEED = -60
local DISC_B_SPEED = 75
local DISC_C_SPEED = -75

local WhirlpoolWaltz: CourseBuilder.CourseSpec = {
	Version = 1,
	Id = "WhirlpoolWaltz",
	DisplayName = "Whirlpool Waltz",
	-- HANDOFF 7.2: "Headline: descending ride platforms with real gaps."
	Headline = "RotatingPlatforms",
	Difficulty = 3,
	ParSeconds = 75,
	CapSeconds = 180,
	CloseWindowSeconds = 60,
	Layout = {
		Kind = "Spiral",
		-- Radial distance between successive turns of the spiral, which is what
		-- the lane-envelope separation is measured against.
		LanePitch = 73.62,
		BoundsRadius = 300,
		LiquidY = -20,
		-- A straight slab is a chord of the arc it approximates, so a collinear
		-- run always finishes a little outside the guide. 12 studs is the budget
		-- for that; past it the build fails rather than quietly drifting. It caps
		-- a collinear run at about sqrt(2 * radius * 12) studs, which is why every
		-- beat below breaks its runs with declared gaps -- including across beat
		-- boundaries, where two floors chained either side of the boundary would
		-- otherwise make one long straight run.
		GuideTolerance = 12,
		Spiral = {
			AngleStartDegrees = 180,
			AngleEndDegrees = 660,
			RadiusStart = RADIUS_START,
			RadiusEnd = RADIUS_END,
			Samples = 480,
			FinishRadius = 0,
		},
		-- A Spiral never places a Corner or a Fill run (it turns on its guide, at
		-- declared gaps and across round decks), but the layout contract carries
		-- both; these are the sources it would use if it did.
		Corner = { Source = "platform_002", Scale = 0.25 },
		Fill = { Source = "platform_002", Scale = 0.25 },
	},
	-- The start plaza sits on the guide's first point, facing its tangent there.
	Start = { Rows = 5, Columns = 6, Spacing = 6, Heading = -5, Position = Vector3.new(-RADIUS_START, 36, 0) },
	Beats = {
		{
			Id = "01_ArchDrop",
			Family = "ClimbDescend",
			Mechanic = "ArchedDescent",
			LengthTarget = 120,
			Pieces = {
				{ Id = "Floor01", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.22 },
				{ Id = "Gap01", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Ramp01", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6 },
				-- Section 7.2 calls this an "enclosed landing mouth" and the first
				-- draft framed it with two arch_003 props. They are NOT here,
				-- because the measurement says they cannot be: a raycast section
				-- through arch_003 (29.51 x 12.85 x 7.79) shows its passage is only
				-- about 4 studs of headroom at scale 1, so it has to be scaled to
				-- roughly 1.8 to clear a 5-stud character -- at which size its legs
				-- land about 23 studs off the lane centreline, over open water with
				-- nothing under them, which 5.1.7 forbids. Flanking two smaller
				-- copies instead left a measured 2.3-stud channel between them,
				-- narrower than a character, and sealed the route outright. The
				-- landing is therefore framed by the ramp and the lane edges alone,
				-- and this course does not claim an arch gateway it cannot build
				-- from measured stock geometry.
				{ Id = "Gap02", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Floor02", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.22 },
				{
					Id = "TwoArm01",
					Kind = "Mount",
					Preset = "Spinner",
					Source = "obstacle_27_001",
					Scale = 0.5,
					OffsetAlong = -10,
					RotorPhase = 0,
				},
				{ Id = "Gap03", Kind = "Advance", OffsetAlong = 14 },
				-- Deliberately shorter than the other floors: this slab and the
				-- next beat's ramp are separated by a gap, but the slab still has
				-- to carry the chicane and the foam basin's rejoin.
				{ Id = "Floor03", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = 0.18 },
				-- Section 7.2's "1 forced cube+triangle chicane": two slabs, one
				-- encounter, so they share an EncounterGroup and score once.
				{
					Id = "Bumper01",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_18_001",
					Scale = 0.5,
					OffsetAlong = -12,
					OffsetSide = -4,
					EncounterGroup = "Chicane01",
				},
				{
					Id = "Bumper02",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_19_001",
					Scale = 0.5,
					OffsetAlong = -5,
					OffsetSide = 4,
					EncounterGroup = "Chicane01",
				},
				-- The foam basin catches a sideways knock off the chicane. It is
				-- outboard: on this spiral a positive OffsetSide points at the hub,
				-- so a negative one is the side with no neighbouring turn.
				{
					Id = "Foam01",
					Kind = "Mount",
					Preset = "FoamPit",
					Scale = 1,
					OffsetAlong = -9,
					OffsetSide = -15,
					OffsetUp = -3,
					VolumeSize = Vector3.new(24, 10, 20),
				},
			},
		},
		{
			Id = "02_WedgeWake",
			Family = "Ride",
			Mechanic = "WedgePlatforms",
			LengthTarget = 180,
			Pieces = {
				{ Id = "Ramp02", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6 },
				{ Id = "Gap04", Kind = "Advance", OffsetAlong = 14 },
				{
					Id = "Pizza01",
					Kind = "Ride",
					Preset = "RidePlatform",
					Source = "obstacle_16_001",
					Scale = 0.4,
					RotorSpeed = PIZZA_A_SPEED,
					RotorPhase = 0,
				},
				{ Id = "Gap05", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Floor04", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.15 },
				{ Id = "Gap06", Kind = "Advance", OffsetAlong = 14 },
				{
					Id = "Carousel01",
					Kind = "Ride",
					Preset = "RidePlatform",
					Source = "obstacle_13_001",
					Scale = 0.4,
					RotorSpeed = CAROUSEL_SPEED,
					RotorPhase = 0.9,
				},
				{ Id = "Gap07", Kind = "Advance", OffsetAlong = 14 },
				{
					Id = "Pizza02",
					Kind = "Ride",
					Preset = "RidePlatform",
					Source = "obstacle_16_001",
					Scale = 0.4,
					RotorSpeed = PIZZA_B_SPEED,
					RotorPhase = 1.7,
				},
				{ Id = "Gap08", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Floor05", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.15 },
			},
		},
		{
			Id = "03_DoorDock",
			Family = "Crowd",
			Mechanic = "DoorChoke",
			LengthTarget = 90,
			Pieces = {
				{ Id = "Ramp03", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_4 },
				{ Id = "Gap09", Kind = "Advance", OffsetAlong = 14 },
				-- The corridor is five 14.71-stud tiles abreast, 73.56 studs wide,
				-- and only 18.48 deep on each side of the row: wide enough for
				-- three framed channels, too shallow for a 24x24 breather square.
				{
					Id = "ApproachL2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_001",
					Scale = 0.21,
					OffsetSide = -29.42,
				},
				{
					Id = "ApproachL1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = 0.21,
					OffsetSide = -14.71,
				},
				{
					Id = "ApproachR1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = 0.21,
					OffsetSide = 14.71,
				},
				{
					Id = "ApproachR2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_003",
					Scale = 0.21,
					OffsetSide = 29.42,
				},
				{ Id = "Floor06", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.21 },
				-- door_00x at 0.32 is 24.05 x 14.65 x 2.01. Three of them tile edge
				-- to edge across the corridor and stand 14.65 studs tall, above the
				-- measured 11.5-stud step, so the row cannot be jumped and needs no
				-- roof. The 0.2 of section 6 would be 9.16 tall, which the measured
				-- 10-stud JumpHeight clears; section 6's own fallback is to raise
				-- the uniform scale, which is what this is.
				{
					Id = "Door01",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_002",
					Scale = 0.32,
					OffsetSide = -24.05,
					DoorRow = 1,
					DoorIndex = 1,
					EncounterGroup = "DoorRow01",
				},
				{
					Id = "Door02",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_003",
					Scale = 0.32,
					OffsetSide = 0,
					DoorRow = 1,
					DoorIndex = 2,
					EncounterGroup = "DoorRow01",
				},
				{
					Id = "Door03",
					Kind = "Mount",
					Preset = "Door",
					Source = "door_004",
					Scale = 0.32,
					OffsetSide = 24.05,
					DoorRow = 1,
					DoorIndex = 3,
					EncounterGroup = "DoorRow01",
				},
				{
					Id = "ExitL2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_003",
					Scale = 0.21,
					OffsetSide = -29.42,
				},
				{
					Id = "ExitL1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_001",
					Scale = 0.21,
					OffsetSide = -14.71,
				},
				{
					Id = "ExitR1",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_001",
					Scale = 0.21,
					OffsetSide = 14.71,
				},
				{
					Id = "ExitR2",
					Kind = "Flank",
					Preset = "Platform",
					Source = "platform_002",
					Scale = 0.21,
					OffsetSide = 29.42,
				},
				{ Id = "Floor07", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.21 },
				{ Id = "Gap10", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Floor08", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = 0.15 },
			},
		},
		{
			Id = "04_SpinSpan",
			Family = "Timing",
			Mechanic = "SpinBridges",
			LengthTarget = 150,
			Pieces = {
				-- Beats 04, 05 and 06 each open with a gap rather than chaining
				-- straight on from the previous beat's last slab. Two collinear
				-- floors either side of a beat boundary is one long straight run,
				-- which on this guide drifts far enough that the following gap
				-- measures past the 19.8-stud ceiling. The checkpoint pad still
				-- lands on the previous beat's solid slab, because it is placed 4
				-- studs back from the beat entrance.
				{ Id = "Gap11", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Floor09", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.18 },
				{
					Id = "Dumbbell01",
					Kind = "Mount",
					Preset = "Spinner",
					Source = "obstacle_6_001",
					Scale = 0.5,
					OffsetAlong = -8,
					RotorPhase = 0,
				},
				{ Id = "Gap12", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Floor10", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = 0.18 },
				{
					Id = "Dumbbell02",
					Kind = "Mount",
					Preset = "Spinner",
					Source = "obstacle_6_001",
					Scale = 0.5,
					OffsetAlong = -8,
					-- The measured formula speed for this radius is 205; the sign is
					-- what section 7.2's "opposite spin" and section 6's
					-- alternating-signs rule ask for.
					RotorSpeed = -205,
					RotorPhase = 1.1,
				},
				{ Id = "Gap13", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Ramp04", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_6 },
				{ Id = "Gap14", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Floor11", Kind = "Chain", Preset = "Platform", Source = "platform_003", Scale = 0.18 },
				{
					Id = "SwingPanel01",
					Kind = "Mount",
					Preset = "SwingPanel",
					Source = "obstacle_8_001",
					Scale = 0.5,
					OffsetAlong = -8,
					RotorAmplitude = 28,
					RotorPeriod = 2.8,
					RotorPhase = 0.6,
				},
				{ Id = "Gap15", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Floor12", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.15 },
			},
		},
		{
			Id = "05_DiscDive",
			Family = "Precision",
			Mechanic = "DiscLandingChain",
			LengthTarget = 180,
			Pieces = {
				-- The approach floor comes BEFORE the slide, and that ordering is
				-- load-bearing. slide_001 drops 10 studs in only 4.83 studs of
				-- forward travel, so with the slide first its exit sat almost
				-- directly beneath this beat's QA gate: a runner could step off the
				-- side of the previous beat's last slab, fall ten studs past the
				-- gate plane and land on the post-slide floor. The cut-set audit
				-- caught it -- all 30 spawn cells reached Finish with gate
				-- 05_DiscDive removed. Putting 13.2 studs of floor in front of the
				-- slide moves its exit about 18 studs past the gate, beyond the
				-- 10.6 studs a runner covers while falling ten, and any jump that
				-- could still reach it arcs up through the gate volume.
				{ Id = "Floor13", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.15 },
				{
					Id = "Bumper03",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_19_001",
					Scale = 0.5,
					OffsetAlong = -5,
				},
				{ Id = "Slide01", Kind = "Chain", Preset = "Slide", Source = "slide_001", Scale = SLIDE_10 },
				{ Id = "Gap17", Kind = "Advance", OffsetAlong = 14 },
				{
					Id = "Disc01",
					Kind = "Ride",
					Preset = "RidePlatform",
					Source = "obstacle_14_001",
					Scale = 0.5,
					RotorSpeed = DISC_A_SPEED,
					RotorPhase = 0.4,
				},
				{ Id = "Gap18", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Landing01", Kind = "Chain", Preset = "Platform", Source = "water_platform_001", Scale = 0.28 },
				{
					Id = "Pad01",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_3_001",
					Scale = 0.3,
					OffsetAlong = -5,
					LaunchSpeed = 51,
				},
				{ Id = "Gap19", Kind = "Advance", OffsetAlong = 14 },
				{
					Id = "Disc02",
					Kind = "Ride",
					Preset = "RidePlatform",
					Source = "obstacle_15_001",
					Scale = 0.45,
					RotorSpeed = DISC_B_SPEED,
					RotorPhase = 1.2,
				},
				{ Id = "Gap20", Kind = "Advance", OffsetAlong = 14 },
				{ Id = "Landing02", Kind = "Chain", Preset = "Platform", Source = "water_platform_001", Scale = 0.28 },
				{
					Id = "Pad02",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_3_001",
					Scale = 0.3,
					OffsetAlong = -5,
					LaunchSpeed = 54,
				},
				{ Id = "Gap21", Kind = "Advance", OffsetAlong = 14 },
				{
					Id = "Disc03",
					Kind = "Ride",
					Preset = "RidePlatform",
					Source = "obstacle_26_001",
					Scale = 0.6,
					RotorSpeed = DISC_C_SPEED,
					RotorPhase = 2.0,
				},
			},
		},
		{
			Id = "06_HubHurry",
			Family = "Timing",
			Mechanic = "HubSweep",
			LengthTarget = 80,
			Pieces = {
				{ Id = "Ramp05", Kind = "Chain", Preset = "Ramp", Source = "box_011", Scale = RAMP_4 },
				{ Id = "Gap22", Kind = "Advance", OffsetAlong = 15 },
				-- The guide's spiral-to-radial transition is a 77-degree corner:
				-- the spiral's tangent at radius 51 is still mostly
				-- circumferential, and the radial finish turns straight in at the
				-- hub. Stepping across that corner at a gap measured only 11.4
				-- studs, below the 13.5 floor section 9 allows, because the corner
				-- folds the two anchors together. A round deck has no preferred
				-- heading, so the turn is absorbed by one instead: the route enters
				-- at its rim on the spiral's tangent and leaves at the opposite rim
				-- on the radial, and both neighbouring gaps stay ordinary.
				{
					Id = "Corner01",
					Kind = "Ride",
					Preset = "RoundLanding",
					Source = "water_platform_001",
					Scale = 0.45,
				},
				{ Id = "Gap23", Kind = "Advance", OffsetAlong = 14 },
				-- The widest lane in the course, carrying the single readable sweep
				-- the finish is supposed to be. The finish plaza is then built at
				-- this slab's exit and overlaps it, the same way Ball Barrage's
				-- does.
				{ Id = "Floor14", Kind = "Chain", Preset = "Platform", Source = "platform_001", Scale = 0.2 },
				{
					Id = "Cross01",
					Kind = "Mount",
					Preset = "Spinner",
					Source = "obstacle_12_001",
					Scale = 0.5,
					OffsetAlong = -8,
					RotorSpeed = -135,
					RotorPhase = 0,
				},
			},
		},
	},
}

return WhirlpoolWaltz
