-- Name: PistonPeak.luau
-- Author: Jack C.
-- Description: Declarative spec for Piston Peak (HANDOFF.md section 7.6): a StackedSwitchback layout -- five short runs stacked over two centrelines forty studs apart, joined by four switchback landings and climbing sixty-six studs -- and the only new course that reuses section 6's rising liquid. It carries three slope counterbelts, two fixed-frame log-rolls, an obstacle_11 seesaw spanning a switchback, a three-slab chicane, two stacked pad launches and a three-piston cascade across the highest ledge. Beat length targets are the scaled section 7.6 targets recorded in docs/splashdown/03-overrides.md. Every scale, gap, speed and offset traces to AssetManifest or to the measured evidence cited in docs/splashdown/courses/piston-peak.md.
-- Created: 2026-09-16

--!strict

local CourseBuilder = require(script.Parent.Parent.CourseBuilder)

-- HANDOFF 5.2's StackedSwitchback: "Short runs stacked above each other with a
-- small horizontal pitch (30-40 studs between run centrelines) so the course reads
-- as a climbing tower that the rising liquid follows."
--
-- A switchback staircase in plan view is a rectangle walked in one rotational
-- direction, so the guide is an ordinary polyline that deliberately retraces
-- itself: runs 1/3/5 share the Z -20 centreline, runs 2/4 share Z +20, and every
-- turn is a right angle turned the same way. The X extents are COMPUTED from the
-- beats at the bottom of this block rather than drawn, so the route closes on 880
-- measured studs and no corner can overrun its vertex; the builder then re-derives
-- every one of those numbers from the built geometry and fails if they move.
local LANE_PITCH = 40

local LIQUID_Y = -30

-- Measured socket travels at scale 1, straight out of AssetManifest, so every
-- length below is derived rather than transcribed.
local WP_TRAVEL = 37 -- water_platform_001 Entry -18.6366 -> Exit 18.3634
local BELT_TRAVEL = 55.90972137451172 -- obstacle_9_001 Entry -27.95 -> Exit 27.95
local RAMP_TRAVEL = 138 -- box_011 Entry -69 -> Exit 69
local PLATFORM_TRAVEL = 88 -- platform_00x Entry -43.926 -> Exit 44.074
local SEESAW_TRAVEL = 75 -- obstacle_11_001 Entry -37.5 -> Exit 37.5

-- box_011 is the measured descending ramp: 138 * s of travel for 28.5 * s of drop,
-- entered from its low end (Reversed) because the kit has no ascending ramp mesh.
-- Every climb on this tower is one of these, so they all share one scale.
local RAMP_6 = 6 / 28.5
local RAMP_6_TRAVEL = RAMP_TRAVEL * RAMP_6

-- water_platform_001 is the only stock piece square enough to turn a 40-stud pitch
-- on. Every turn here is a RIGHT turn, so the route leaves through the measured
-- SideNegativeX socket at -18.6361, not SidePositiveX: one corner spends
-- 18.6366 * scale along its incoming run and 18.6361 * scale across the cross. The
-- first build of this course used the positive socket by mistake and put the second
-- hairpin 0.11 studs past its own vertex, which is why both numbers are spelled out
-- here. The slot the two corners leave between them is what beat 03's seesaw plank
-- fills exactly, so the plank's scale is derived from it rather than chosen.
local CORNER = 0.4
local CORNER_ALONG = 18.6366 * CORNER
local CORNER_LATERAL = 18.6361 * CORNER
local CROSS_SLOT = LANE_PITCH - CORNER_ALONG - CORNER_LATERAL
local SEESAW = CROSS_SLOT / SEESAW_TRAVEL

-- Section 7.6's "3 slope conveyors -13/-15.6/-18.2". obstacle_9_001 is 27.9549
-- across and 55.9097 of travel, so at 0.32 each belt is an 8.946-stud bridge with
-- open liquid on both sides: the belt IS the lane there, which is what leaves no
-- lateral escape strip beside it.
local BELT = 0.32

-- Deck scales. Widths are 37.2731 * scale for a round deck and 70.0699 * scale for a
-- platform slab; the two widest decks either column carries are held under 17.4 so
-- the tightest cross-run edge gap the tower can ever present stays past the measured
-- 22-stud flat jump.
local TREAD_ENTRY = 0.4668 -- 17.272 travel, 17.399 wide: the funnel off the plaza
local TREAD_ROLL = 0.28734 -- 10.632 travel, 10.710 wide: run 2's roller treads
local TREAD_SLOPE = 0.4668 -- 17.272 travel, 17.399 wide: run 3's chicane treads
local TREAD_LAUNCH = 0.3917 -- 14.493 travel, 14.600 wide: run 4's pad landings
local LEDGE = 0.1250895 -- 11.008 travel, 8.765 wide: the piston ledge
local LANE_FINISH = 0.1759182 -- 15.481 travel, 12.327 wide

-- The approach deck the builder's own Fill lays down before each corner. 14 studs is
-- comfortably inside one 14.8-stud fill unit, so it is always a single round deck
-- rather than two half-width ones.
local APPROACH_FILL = 14
-- buildStartPads walks the route this far forward off a five-row grid at 6-stud
-- spacing before beat 01 begins.
local START_OFFSET = 24

-- Pad hop gaps. Over the +6 each hop climbs, an ordinary jump reaches 18.099 studs
-- and the pads reach 22.963 and 25.524; both pads sit centred on their deck's exit
-- edge, so the worst launch point is half a pad (3.096 studs) back.
local HOP_1 = 19
local HOP_2 = 20.5

-- How far off the ledge centreline a piston base stands. Derived: the head's inner
-- face sits at side - 17.019 at rest and side - 23.019 fully extended, so this is
-- the smallest mount distance that leaves a corridor wider than the 3.06-stud
-- precision minimum at rest while still sealing the whole 8.765-stud ledge on the
-- punch.
local PISTON_SIDE = 19.5

-- wall_001 is 18.8965 x 22.9403 x 7.7135, so 0.615 makes an 11.621-stud panel that
-- tops out 14.108 studs above whatever it stands on -- HANDOFF 5.2's measured 14,
-- as one piece rather than a stack of slabs (Tumble Tunnels' lesson 1).
local GUARD = 0.615

-- Each run's explicit piece travel, and from it the guide. A run segment is exactly
-- the lateral its incoming corner spends, plus its own pieces, plus the approach
-- deck, plus the along its outgoing corner spends -- so the guide is COMPUTED from
-- the beats rather than transcribed, and a corner can never overrun its vertex.
local RUN_1 = WP_TRAVEL * TREAD_ENTRY + 3 * BELT_TRAVEL * BELT + 2 * RAMP_6_TRAVEL
local RUN_2 = 3 * WP_TRAVEL * TREAD_ROLL + 2 * RAMP_6_TRAVEL
local RUN_3 = 2 * RAMP_6_TRAVEL + 4 * WP_TRAVEL * TREAD_SLOPE
local RUN_4 = 3 * WP_TRAVEL * TREAD_LAUNCH + HOP_1 + HOP_2 + RAMP_6_TRAVEL
local RUN_5 = 2 * RAMP_6_TRAVEL + 3 * PLATFORM_TRAVEL * LEDGE + 2 * PLATFORM_TRAVEL * LANE_FINISH

local SEG_1 = START_OFFSET + RUN_1 + APPROACH_FILL + CORNER_ALONG
local SEG_2 = CORNER_LATERAL + RUN_2 + APPROACH_FILL + CORNER_ALONG
local SEG_3 = CORNER_LATERAL + RUN_3 + APPROACH_FILL + CORNER_ALONG
local SEG_4 = CORNER_LATERAL + RUN_4 + APPROACH_FILL + CORNER_ALONG
local SEG_5 = CORNER_LATERAL + RUN_5

local COLUMN_A = -LANE_PITCH / 2
local COLUMN_B = LANE_PITCH / 2
local X0 = -120
local X1 = X0 + SEG_1
local X2 = X1 - SEG_2
local X3 = X2 + SEG_3
local X4 = X3 - SEG_4
-- The guide runs a little past the finish so the last segment is never the binding
-- constraint on the run-out.
local X5 = X4 + SEG_5 + 16

local PistonPeak: CourseBuilder.CourseSpec = {
	Version = 1,
	Id = "PistonPeak",
	DisplayName = "Piston Peak",
	-- HANDOFF 7.6: "Headline: zigzag climb with punches." The punches are the beat
	-- 06 piston cascade. This headline names a PRESET rather than a scoring type,
	-- because a piston scores as RotorBump beside every pendulum in the set and
	-- RotorBump is nobody's headline; auditCrossCourse scores a preset headline
	-- against dominant presets, which compares pistons only against pistons.
	Headline = "Piston",
	-- HANDOFF 12.1's difficulty list for the final seven: 3, 3, 2, 3, 3, 4, Summit 3.
	Difficulty = 4,
	ParSeconds = 75,
	CapSeconds = 180,
	CloseWindowSeconds = 60,
	Layout = {
		Kind = "StackedSwitchback",
		LanePitch = LANE_PITCH,
		BoundsRadius = 300,
		LiquidY = LIQUID_Y,
		Guide = {
			Vector3.new(X0, 0, COLUMN_A),
			Vector3.new(X1, 0, COLUMN_A),
			Vector3.new(X1, 0, COLUMN_B),
			Vector3.new(X2, 0, COLUMN_B),
			Vector3.new(X2, 0, COLUMN_A),
			Vector3.new(X3, 0, COLUMN_A),
			Vector3.new(X3, 0, COLUMN_B),
			Vector3.new(X4, 0, COLUMN_B),
			Vector3.new(X4, 0, COLUMN_A),
			Vector3.new(X5, 0, COLUMN_A),
		},
		StackedSwitchback = {
			-- HANDOFF 5.2's 30-40 band.
			MinPitchStuds = 30,
			MaxPitchStuds = 40,
			-- "Guard walls between stacked runs are measured 14 above the lower run's
			-- takeoff surfaces."
			GuardWallStuds = 14,
			-- The measured minimum between two runs sharing a centreline is 23.2 studs
			-- (run 1 against run 3, where run 1's first climb is still under run 3's
			-- entry). Declared at 18 so the build fails long before an upper run
			-- becomes reachable, and 18 already beats the measured 11.5-stud step-up
			-- by a wide margin.
			MinStackClearanceStuds = 18,
			StepLimitStuds = 11.5,
			-- HANDOFF 3.2's measured movement constants, so every reach is derived:
			-- gravity 120, WalkSpeed 26, JumpHeight 10 with UseJumpPower=false. The
			-- calibration is the measured 22-stud flat gap minus this model's own
			-- 21.229 prediction, which is the avatar's body extent.
			Gravity = 120,
			WalkSpeed = 26,
			JumpHeight = 10,
			JumpReachCalibration = 0.7711,
			-- A hop between two runs that saves less than this is the switchback's own
			-- legal crossing at the turn, not a bypass.
			MinBypassStuds = 30,
		},
		-- HANDOFF section 6's rising liquid, which only this course may reuse. The
		-- section 7.6 seed is MaxHeight 60 from baseY -30, which stops the flood at
		-- +30 and drowns the checkpoints at Y 12 and Y 24 -- a racer respawning on a
		-- submerged pad splashes and respawns on it again. 7.6's own remedy is
		-- "lower MaxHeight in 2-stud increments until the flood regression passes";
		-- 60 down to 38 stops the flood at +8, four studs under the lowest checkpoint
		-- pad's walkable top, and the builder measures that clearance rather than
		-- trusting this comment.
		Rise = {
			MaxHeight = 38,
			RiseStudsPerSecond = 0.4,
			StartDelaySeconds = 20,
			CheckpointClearanceStuds = 4,
		},
		Corner = { Source = "water_platform_001", Scale = CORNER },
		Fill = { Source = "water_platform_001", Scale = CORNER },
	},
	-- HANDOFF 7.6: "StartY 0." The plaza sits 120 studs out along the first run's own
	-- centreline so its 52.9-stud footprint clears the tower entirely; buildStartPads
	-- walks the route 24 studs forward off a five-row grid at 6-stud spacing.
	Start = { Rows = 5, Columns = 6, Spacing = 6, Heading = -90, Position = Vector3.new(X0, 0, COLUMN_A) },
	Beats = {
		{
			Id = "01_ZigzagZip",
			Family = "Climb/Descend",
			Mechanic = "SlopeCounterbelt",
			LengthTarget = 154,
			Pieces = {
				{
					Id = "Tread01",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_ENTRY,
				},
				-- The tower's first guard wall, on the wide entry deck where there is
				-- room for it. Nothing is stacked over run 1 this far out, so it is
				-- purely the section 5.2 enclosure between the two columns.
				{
					Id = "GuardWall01",
					Kind = "Mount",
					Preset = "Prop",
					Source = "wall_001",
					Scale = GUARD,
					OffsetAlong = -8.5,
					OffsetSide = 5.6,
					FacingOffsetDegrees = 90,
					GuardWall = true,
				},
				{
					Id = "Belt01",
					Kind = "Chain",
					Preset = "Conveyor",
					Source = "obstacle_9_001",
					Scale = BELT,
					ConveyorSpeed = -13,
				},
				{
					Id = "Climb01",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{
					Id = "Belt02",
					Kind = "Chain",
					Preset = "Conveyor",
					Source = "obstacle_9_001",
					Scale = BELT,
					ConveyorSpeed = -15.6,
				},
				{
					Id = "Climb02",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{
					Id = "Belt03",
					Kind = "Chain",
					Preset = "Conveyor",
					Source = "obstacle_9_001",
					Scale = BELT,
					ConveyorSpeed = -18.2,
				},
				-- Section 7.6's "forced cube+triangle chicane at the first switchback".
				-- Both slabs stand on the 14.1-stud approach deck the corner's own fill
				-- lays down, staggered 7 studs apart along the route on opposite sides,
				-- so a straight line through meets one of them. One EncounterGroup:
				-- section 7 scores a chicane once however many slabs it has.
				{
					Id = "ChicaneCube",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_18_001",
					Scale = 0.5,
					OffsetAlong = 3.5,
					OffsetSide = -2.8,
					EncounterGroup = "SwitchbackChicane",
				},
				{
					Id = "ChicaneWedge",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_19_001",
					Scale = 0.5,
					OffsetAlong = 10.5,
					OffsetSide = 2.8,
					EncounterGroup = "SwitchbackChicane",
				},
				{ Id = "TurnA1", Kind = "Corner", Direction = "Right" },
			},
		},
		{
			Id = "02_LogClimb",
			Family = "Timing",
			Mechanic = "RollingRamp",
			LengthTarget = 143,
			Pieces = {
				{ Id = "TurnB1", Kind = "Corner", Direction = "Right" },
				{
					Id = "Tread02",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_ROLL,
				},
				{
					Id = "GuardWall02",
					Kind = "Mount",
					Preset = "Prop",
					Source = "wall_001",
					Scale = GUARD,
					OffsetAlong = -5.3,
					OffsetSide = 2.6,
					FacingOffsetDegrees = 90,
					GuardWall = true,
				},
				{
					Id = "Climb03",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{
					Id = "Tread03",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_ROLL,
				},
				-- Section 7.6's "2 log-rolls with opposite spin and different diameters
				-- on consecutive switchback ramps". The kit has no sloped mounting frame,
				-- so each roller lies on the flat tread at the head of its own ramp
				-- flight, which is where the climb's momentum carries the runner into it.
				--
				-- obstacle_10_001, NOT the framed spiked roller. The first build used
				-- obstacle_2_001, whose cradle stands 32.284 studs tall above its own
				-- mount, and the cut-set audit measured runners climbing one from run 2
				-- and jumping straight into beat 06 -- three beats skipped. A tall frame
				-- standing on a lower storey of a tower is a ladder. This barrel is a
				-- single mesh with no frame at all: it lies on its side (a quarter turn
				-- about its own X, then a quarter turn of yaw so its long axis crosses
				-- the lane), spins about its own local Y, and stands 13.977 * scale long
				-- against a 10.710-stud tread, so there is no line past it either.
				-- OffsetUp lifts the axle so the barrel breaks the deck by more than the
				-- roughly two studs a runner steps over for free. Speeds are section 6's
				-- formula at the measured crossing radius (3.0594 * scale), signed
				-- opposite.
				{
					Id = "Roll01",
					Kind = "Mount",
					Preset = "LogRoll",
					Source = "obstacle_10_001",
					Scale = 1.2,
					RotorAxis = "Y",
					RotorSpeed = 530,
					PitchDegrees = 90,
					FacingOffsetDegrees = 90,
					OffsetAlong = -5.3,
					OffsetUp = 1,
				},
				{
					Id = "Climb04",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{
					Id = "Tread04",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_ROLL,
				},
				{
					Id = "Roll02",
					Kind = "Mount",
					Preset = "LogRoll",
					Source = "obstacle_10_001",
					Scale = 0.85,
					RotorAxis = "Y",
					RotorSpeed = -745,
					PitchDegrees = 90,
					FacingOffsetDegrees = 90,
					OffsetAlong = -5.3,
					OffsetUp = 1.3,
				},
			},
		},
		{
			Id = "03_TeeterTurn",
			Family = "Ride",
			Mechanic = "SeesawTurn",
			LengthTarget = 99,
			Pieces = {
				{ Id = "TurnA2", Kind = "Corner", Direction = "Right" },
				-- Section 7.6's "1 long obstacle_11 seesaw as the turn platform, max tilt
				-- 20". At 0.336 the plank travels exactly the 25.2-stud slot between the
				-- two switchback decks, so the board IS the crossing: 11.654 studs wide
				-- with open liquid on both sides and no line past it.
				{
					Id = "Seesaw01",
					Kind = "Chain",
					Preset = "Seesaw",
					Source = "obstacle_11_001",
					Scale = SEESAW,
					MaxTiltDegrees = 20,
				},
				{ Id = "TurnB2", Kind = "Corner", Direction = "Right" },
				{
					Id = "Climb05",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
			},
		},
		{
			Id = "04_PinballPass",
			Family = "Precision",
			Mechanic = "SlopeChicane",
			LengthTarget = 121,
			Pieces = {
				{
					Id = "Tread05",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_SLOPE,
				},
				{
					Id = "Climb06",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{
					Id = "Tread06",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_SLOPE,
				},
				-- Section 7.6's "3 alternating bumpers varying shape/height on the slope
				-- (one chicane)". Section 6 fixes the bumper at scale .5; 7.6 asks for
				-- varying height on top of that, so the wedge is taller at 0.6 and the
				-- second cube shorter at 0.42, giving 6.70 / 7.70 / 5.63-stud silhouettes
				-- five studs apart across the head of the slope.
				{
					Id = "Bump01",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_18_001",
					Scale = 0.5,
					OffsetAlong = -13,
					OffsetSide = -4.5,
					EncounterGroup = "SlopeChicane",
				},
				{
					Id = "Bump02",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_19_001",
					Scale = 0.6,
					OffsetAlong = -8,
					OffsetSide = 4,
					EncounterGroup = "SlopeChicane",
				},
				{
					Id = "Bump03",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_18_001",
					Scale = 0.42,
					OffsetAlong = -3,
					OffsetSide = -4,
					EncounterGroup = "SlopeChicane",
				},
				{
					Id = "Tread07",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_SLOPE,
				},
				{
					Id = "Tread08",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_SLOPE,
				},
				{
					Id = "GuardWall03",
					Kind = "Mount",
					Preset = "Prop",
					Source = "wall_001",
					Scale = GUARD,
					OffsetAlong = -8.6,
					OffsetSide = 5.6,
					FacingOffsetDegrees = 90,
					GuardWall = true,
				},
				{ Id = "TurnA3", Kind = "Corner", Direction = "Right" },
			},
		},
		{
			Id = "05_Updraft",
			Family = "Launch",
			Mechanic = "StackedPadAscent",
			LengthTarget = 121,
			Pieces = {
				{ Id = "TurnB3", Kind = "Corner", Direction = "Right" },
				{
					Id = "Tread10",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_LAUNCH,
				},
				{
					Id = "GuardWall04",
					Kind = "Mount",
					Preset = "Prop",
					Source = "wall_001",
					Scale = GUARD,
					-- Back far enough that the 11.621-stud panel ends before Pad01, which
					-- sits centred on this deck's exit edge.
					OffsetAlong = -9.5,
					OffsetSide = 4.6,
					FacingOffsetDegrees = 90,
					GuardWall = true,
				},
				-- Section 7.6's "2 pads 48/52 up the stack". Both pads sit CENTRED on
				-- their deck's exit edge, which is what bounds the flight: the kit
				-- launches wherever the runner steps on, so a pad set back from the edge
				-- silently lengthens the crossing (Tiptoe Trials' lesson 4). Centred, the
				-- worst launch point is half a pad back, so the flight is at most
				-- gap + 3.096. Over the +6 rise each hop climbs, an ordinary jump reaches
				-- 18.099 studs, so both gaps need the pad and neither can overshoot into
				-- the next beat.
				{
					Id = "Pad01",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_2_001",
					Scale = 0.5,
					LaunchSpeed = 48,
					FloatFactor = 0.2,
					OffsetAlong = 0,
				},
				{ Id = "Hop01", Kind = "Advance", OffsetAlong = HOP_1, OffsetUp = 6 },
				{
					Id = "Tread11",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_LAUNCH,
				},
				{
					Id = "Pad02",
					Kind = "Mount",
					Preset = "JumpPad",
					Source = "trampoline_2_001",
					Scale = 0.5,
					LaunchSpeed = 52,
					FloatFactor = 0.2,
					OffsetAlong = 0,
				},
				{ Id = "Hop02", Kind = "Advance", OffsetAlong = HOP_2, OffsetUp = 6 },
				{
					Id = "Tread12",
					Kind = "Chain",
					Preset = "Platform",
					Source = "water_platform_001",
					Scale = TREAD_LAUNCH,
				},
				-- "1 forced bumper at the upper landing": 7.174 studs across an
				-- 11.686-stud deck leaves 2.26 on each shoulder, under the 3.06-stud
				-- precision minimum, so a runner arriving under launch meets it.
				{
					Id = "LandingBumper",
					Kind = "Mount",
					Preset = "Bumper",
					Source = "obstacle_18_001",
					Scale = 0.5,
					OffsetAlong = -9,
				},
			},
		},
		{
			Id = "06_PunchPeak",
			Family = "Timing",
			Mechanic = "PistonCascade",
			LengthTarget = 176,
			Pieces = {
				{
					Id = "Climb07",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{ Id = "TurnA4", Kind = "Corner", Direction = "Right" },
				{ Id = "TurnB4", Kind = "Corner", Direction = "Right" },
				{
					Id = "Climb08",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{ Id = "Ledge01", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = LEDGE },
				-- Section 7.6's "3 pistons phases 0/1.05/2.1 with alternating lateral
				-- punch directions across the highest ledge over the rising liquid".
				--
				-- obstacle_22's arm is long: at 0.5 the head's centre sits 13.159 studs
				-- from the mount with a 3.857-stud half-length and a 6-stud punch, and
				-- its measured local y of -0.109 against a -10.16 Support puts the head
				-- 2.70 to 7.36 studs above the deck -- across a runner whose root is 3.5
				-- up, unlike the hammers whose heads hang beneath their housings.
				--
				-- The mount distance is what decides whether the ledge is a timed squeeze
				-- or a wall. At side 17 every head reached 0.02 studs PAST the centreline
				-- at rest, and because the three alternate sides their rest poses between
				-- them covered the whole corridor: the sampled graph found no standable
				-- cell across the ledge at all and the ordered-route audit failed both of
				-- the last two legs. At side 19.5 each head spans +2.48 to +10.20 at rest,
				-- so a 4.96-stud corridor runs the length of the ledge past all three, and
				-- the same head sweeps -3.52 to +4.20 when it fires, which seals that
				-- corridor edge to edge for the 0.6-second hold. The spring (side +9.49 to
				-- +20.45 at 3.92-6.89 studs up) stands between the ledge and the base, so
				-- the base is never a quiet walk-around.
				{
					Id = "Piston01",
					Kind = "Mount",
					Preset = "Piston",
					Source = "obstacle_22_001",
					Scale = 0.5,
					OffsetAlong = -6.5,
					OffsetSide = PISTON_SIDE,
					FacingOffsetDegrees = 90,
					RotorPhase = 0,
				},
				{ Id = "Ledge02", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = LEDGE },
				{
					Id = "Piston02",
					Kind = "Mount",
					Preset = "Piston",
					Source = "obstacle_22_001",
					Scale = 0.5,
					OffsetAlong = -6.5,
					OffsetSide = -PISTON_SIDE,
					FacingOffsetDegrees = -90,
					RotorPhase = 1.05,
				},
				{ Id = "Ledge03", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = LEDGE },
				{
					Id = "Piston03",
					Kind = "Mount",
					Preset = "Piston",
					Source = "obstacle_22_001",
					Scale = 0.5,
					OffsetAlong = -6.5,
					OffsetSide = PISTON_SIDE,
					FacingOffsetDegrees = 90,
					RotorPhase = 2.1,
				},
				-- No guard wall on the piston ledge: the heads sweep it edge to edge to
				-- side +7.70, so a wall on its inner rim would be struck on every punch.
				-- Run 5's wall stands on the finish lane in beat 07 instead, and the
				-- measured cross-run gap here is 23.8 studs against a 22-stud jump.
			},
		},
		{
			Id = "07_PeakSprint",
			Family = "Climb/Descend",
			Mechanic = "FinalRamp",
			LengthTarget = 66,
			Pieces = {
				{
					Id = "Climb09",
					Kind = "Chain",
					Preset = "Ramp",
					Source = "box_011",
					Scale = RAMP_6,
					Reversed = true,
				},
				{ Id = "Lane01", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = LANE_FINISH },
				{
					Id = "GuardWall05",
					Kind = "Mount",
					Preset = "Prop",
					Source = "wall_001",
					Scale = GUARD,
					OffsetAlong = -8.4,
					OffsetSide = 3.4,
					FacingOffsetDegrees = 90,
					GuardWall = true,
				},
				{ Id = "Lane02", Kind = "Chain", Preset = "Platform", Source = "platform_002", Scale = LANE_FINISH },
				-- Section 7.6's "arch finish". arch_005 is a measured tunnel arch: a
				-- 21.6-stud bore half-width and a threshold 14.43 studs under its own
				-- centre against a -20.3889 Support, so at 0.35 the bore is 15.12 studs
				-- wide and 7.95 tall and the OffsetUp drops its threshold slab flush with
				-- the finish lane instead of standing it 5.96 studs proud.
				{
					Id = "FinishArch",
					Kind = "Mount",
					Preset = "Prop",
					Source = "arch_005",
					Scale = 0.35,
					OffsetAlong = -4,
					OffsetUp = -2.0851,
				},
			},
		},
	},
}

return PistonPeak
