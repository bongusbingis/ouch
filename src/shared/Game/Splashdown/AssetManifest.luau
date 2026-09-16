-- Name: AssetManifest.luau
-- Author: Jack C.
-- Description: Versioned, measured facts about the ServerStorage.SplashdownAuthoringSources.Kit source assets that CourseBuilder places: per-source role, size, mechanical pivots for multi-part hazard assemblies, and Entry/Exit/Support sockets in each root part's own local (CFrame-relative) space. Every socket and surface figure here traces to a real Studio measurement recorded under docs/splashdown/evidence/; nothing is estimated.
-- Created: 2026-09-15

--!strict

local AssetManifest = {}

AssetManifest.Version = 3
AssetManifest.SourceHash = "e9e69d1defddda53ba439cf78660d1b668c489913c309b771cda7fcb7d9f7eec"
AssetManifest.SourcePath = { "ServerStorage", "SplashdownAuthoringSources", "Kit" }

export type Socket = { Position: Vector3, Axis: Vector3 }
export type SubPart = { Name: string, RelativeCFrame: CFrame, Size: Vector3 }
export type Sockets = {
	Entry: Socket?,
	Exit: Socket?,
	Support: Socket,
	Axle: Socket?,
	-- Lateral walkable edge centres, used only by corner pieces: a corner slab is
	-- entered at Entry and left through the side socket on the turn's inside, so
	-- the walkable top carries the route around the bend with no seam. Both are
	-- the measured footprint extremes, not half of Size.
	SidePositiveX: Socket?,
	SideNegativeX: Socket?,
}
-- A rotating deck the route crosses. Plate is the SubPart path of the walkable
-- plate, or nil when the root itself is the plate. PlateTopLocalY is the
-- measured walkable surface in the PLATE's own local frame. Radius is the
-- conservative usable crossing radius about the hub's rotation axis: the
-- smallest measured half-extent, reduced by any measured plate eccentricity, so
-- the entry and exit rim points are on real plate at every rotation.
export type RideDeck = {
	Plate: string?,
	PlateTopLocalY: number,
	Radius: number,
}

export type AssetEntry = {
	Role: string,
	Kind: "Surface" | "Mount",
	Size: Vector3,
	ForwardAxis: ("X" | "Z")?,
	Ride: RideDeck?,
	-- Measured distance from a spin hazard's axis to the surface a runner
	-- actually crosses, at scale 1. The section 6 spin-speed formula is computed
	-- at this radius, never at a decorative tip.
	ContactRadius: number?,
	-- Heading (old-script convention: yaw 0 faces world -Z, matching
	-- CFrame.Angles identity) that a Surface piece's own Entry->Exit local
	-- forward direction represents. CoursePresets uses this scalar instead of
	-- socket Axis vectors to orient chained pieces, sidestepping Roblox's
	-- "-Z is forward" sign convention entirely. Socket.Axis below is
	-- documentation only (the measured local direction each socket faces);
	-- it is not used in placement math.
	ForwardHeadingDegrees: number?,
	Sockets: Sockets,
	SubParts: { SubPart }?,
	Measurement: { RayStep: number, Hits: number, Misses: number, EvidencePath: string }?,
}

local function socket(px: number, py: number, pz: number, axisX: number?, axisY: number?, axisZ: number?): Socket
	return {
		Position = Vector3.new(px, py, pz),
		Axis = Vector3.new(axisX or 0, axisY or 0, axisZ or 1),
	}
end

AssetManifest.Assets = (
	{
		obstacle_9_001 = {
			Role = "Conveyor",
			Kind = "Surface",
			Size = Vector3.new(27.95486068725586, 1.7447575330734253, 55.90972137451172),
			ForwardAxis = "Z",
			ForwardHeadingDegrees = 180,
			Sockets = {
				Entry = socket(0, 0.87, -27.95, 0, 0, -1),
				Exit = socket(0, 0.87, 27.95, 0, 0, 1),
				Support = socket(0, -0.87, 0, 0, -1, 0),
			},
			Measurement = {
				RayStep = 0.5,
				Hits = 6182,
				Misses = 90,
				EvidencePath = "docs/splashdown/evidence/course-sockets-ballbarrage.json",
			},
		} :: AssetEntry,

		platform_001 = {
			Role = "StraightLaneFloor",
			Kind = "Surface",
			Size = Vector3.new(70.06987762451172, 28.54939079284668, 89.851806640625),
			ForwardAxis = "Z",
			ForwardHeadingDegrees = 180,
			Sockets = {
				Entry = socket(0, 14.275, -43.926, 0, 0, -1),
				Exit = socket(0, 14.275, 44.074, 0, 0, 1),
				Support = socket(0, -14.3, 0, 0, -1, 0),
				-- course-sockets-ballbarrage.json footprintX = [-34.035, 34.965]
				-- (the measured walkable extremes; the slab's rounded bevel makes
				-- them slightly asymmetric about the mesh origin).
				SidePositiveX = socket(34.965, 14.275, 0, 1, 0, 0),
				SideNegativeX = socket(-34.035, 14.275, 0, -1, 0, 0),
			},
			Measurement = {
				RayStep = 1.0,
				Hits = 6052,
				Misses = 338,
				EvidencePath = "docs/splashdown/evidence/course-sockets-ballbarrage.json",
			},
		} :: AssetEntry,
		platform_002 = {
			Role = "StraightLaneFloor",
			Kind = "Surface",
			Size = Vector3.new(70.06987762451172, 28.54939079284668, 89.851806640625),
			ForwardAxis = "Z",
			ForwardHeadingDegrees = 180,
			Sockets = {
				Entry = socket(0, 14.275, -43.926, 0, 0, -1),
				Exit = socket(0, 14.275, 44.074, 0, 0, 1),
				Support = socket(0, -14.3, 0, 0, -1, 0),
				-- course-sockets-ballbarrage.json footprintX = [-34.035, 34.965]
				-- (the measured walkable extremes; the slab's rounded bevel makes
				-- them slightly asymmetric about the mesh origin).
				SidePositiveX = socket(34.965, 14.275, 0, 1, 0, 0),
				SideNegativeX = socket(-34.035, 14.275, 0, -1, 0, 0),
			},
			Measurement = {
				RayStep = 1.0,
				Hits = 6052,
				Misses = 338,
				EvidencePath = "docs/splashdown/evidence/course-sockets-ballbarrage.json",
			},
		} :: AssetEntry,
		platform_003 = {
			Role = "StraightLaneFloor",
			Kind = "Surface",
			Size = Vector3.new(70.06987762451172, 28.54939079284668, 89.851806640625),
			ForwardAxis = "Z",
			ForwardHeadingDegrees = 180,
			Sockets = {
				Entry = socket(0, 14.275, -43.926, 0, 0, -1),
				Exit = socket(0, 14.275, 44.074, 0, 0, 1),
				Support = socket(0, -14.3, 0, 0, -1, 0),
				-- course-sockets-ballbarrage.json footprintX = [-34.035, 34.965]
				-- (the measured walkable extremes; the slab's rounded bevel makes
				-- them slightly asymmetric about the mesh origin).
				SidePositiveX = socket(34.965, 14.275, 0, 1, 0, 0),
				SideNegativeX = socket(-34.035, 14.275, 0, -1, 0, 0),
			},
			Measurement = {
				RayStep = 1.0,
				Hits = 6052,
				Misses = 338,
				EvidencePath = "docs/splashdown/evidence/course-sockets-ballbarrage.json",
			},
		} :: AssetEntry,

		box_011 = {
			Role = "RampDescendingPositiveX",
			Kind = "Surface",
			Size = Vector3.new(153.06268310546875, 53.853248596191406, 60.27421188354492),
			ForwardAxis = "X",
			ForwardHeadingDegrees = -90,
			Sockets = {
				Entry = socket(-69, 26.9, 0, -1, 0, 0),
				Exit = socket(69, -1.6, 0, 1, 0, 0),
				Support = socket(0, -26.9, 0, 0, -1, 0),
			},
			Measurement = {
				RayStep = 0.5,
				Hits = 32287,
				Misses = 4860,
				EvidencePath = "docs/splashdown/evidence/course-sockets-ballbarrage.json",
			},
		} :: AssetEntry,
		box_013 = {
			Role = "RampDescendingNegativeX",
			Kind = "Surface",
			Size = Vector3.new(153.06268310546875, 53.853248596191406, 60.27421188354492),
			ForwardAxis = "X",
			ForwardHeadingDegrees = 90,
			Sockets = {
				Entry = socket(69, 26.9, 0, 1, 0, 0),
				Exit = socket(-69, -1.6, 0, -1, 0, 0),
				Support = socket(0, -26.9, 0, 0, -1, 0),
			},
			Measurement = {
				RayStep = 0.5,
				Hits = 32264,
				Misses = 4883,
				EvidencePath = "docs/splashdown/evidence/course-sockets-ballbarrage.json",
			},
		} :: AssetEntry,

		slide_001 = {
			Role = "FinishSlide",
			Kind = "Surface",
			Size = Vector3.new(33.97971725463867, 56.8065185546875, 89.7237319946289),
			ForwardAxis = "Z",
			ForwardHeadingDegrees = 180,
			Sockets = {
				Entry = socket(0, 28.3, 13, 0, 0, 1),
				Exit = socket(0, -23.5, 38, 0, 0, 1),
				Support = socket(0, -28.4, 0, 0, -1, 0),
			},
			Measurement = {
				RayStep = 0.5,
				Hits = 12166,
				Misses = 74,
				EvidencePath = "docs/splashdown/evidence/course-sockets-ballbarrage.json",
			},
		} :: AssetEntry,

		obstacle_2_001 = {
			Role = "SweeperFrame",
			Kind = "Mount",
			Size = Vector3.new(49.456443786621094, 32.287994384765625, 7.025842666625977),
			Sockets = { Support = socket(0, -16.14, 0, 0, -1, 0) },
			SubParts = {
				{
					Name = "obstacle_2_002",
					RelativeCFrame = CFrame.new(-0.001, -14.090, 0.000),
					Size = Vector3.new(40.8177375793457, 12.25576400756836, 12.255731582641602),
				},
			},
		} :: AssetEntry,

		obstacle_18_001 = {
			Role = "BumperCube",
			Kind = "Mount",
			Size = Vector3.new(14.347249984741211, 13.403928756713867, 14.347522735595703),
			Sockets = { Support = socket(0, -6.70, 0, 0, -1, 0) },
		} :: AssetEntry,
		obstacle_19_001 = {
			Role = "BumperTriangle",
			Kind = "Mount",
			Size = Vector3.new(19.872339248657227, 12.832365036010742, 21.228904724121094),
			Sockets = { Support = socket(0, -6.42, 0, 0, -1, 0) },
		} :: AssetEntry,

		obstacle_23_001 = {
			Role = "BigBallPole",
			Kind = "Mount",
			Size = Vector3.new(5.494877338409424, 34.845821380615234, 5.494786262512207),
			Sockets = { Support = socket(0, -17.42, 0, 0, -1, 0) },
			SubParts = {
				{
					Name = "obstacle_23_002",
					RelativeCFrame = CFrame.new(0.000, 21.784, -0.000),
					Size = Vector3.new(13.71717357635498, 12.981073379516602, 13.717082977294922),
				},
			},
		} :: AssetEntry,

		obstacle_22_001 = {
			Role = "PistonBase",
			Kind = "Mount",
			Size = Vector3.new(16.51, 16.51, 20.32),
			Sockets = { Support = socket(0, -10.16, 0, 0, -1, 0) },
			SubParts = {
				{
					Name = "obstacle_22_002",
					RelativeCFrame = CFrame.new(0, 0, -10.36),
					Size = Vector3.new(5.95, 5.66, 21.90),
				},
				{
					Name = "obstacle_22_002.obstacle_22_003",
					RelativeCFrame = CFrame.new(0, 0, -10.36) * CFrame.new(0.195, -0.769, -17.258),
					Size = Vector3.new(10.890019416809082, 9.318285942077637, 15.42877197265625),
				},
			},
		} :: AssetEntry,

		obstacle_3_001 = {
			Role = "LargeHammerPillar",
			Kind = "Mount",
			Size = Vector3.new(4.6067280769348145, 3.933828353881836, 4.355025291442871),
			Sockets = {
				Support = socket(0, -1.97, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 1, 0),
			},
			SubParts = {
				{
					Name = "obstacle_3_002",
					RelativeCFrame = CFrame.new(0.000, -16.846, 0.000),
					Size = Vector3.new(18.525554656982422, 31.26760482788086, 3.193833827972412),
				},
			},
		} :: AssetEntry,
		obstacle_4_001 = {
			Role = "SmallHammerPillar",
			Kind = "Mount",
			Size = Vector3.new(4.648951530456543, 4.649102210998535, 5.4834113121032715),
			Sockets = {
				Support = socket(0, -2.32, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 1, 0),
			},
			SubParts = {
				{
					Name = "obstacle_4_002",
					RelativeCFrame = CFrame.new(0.000, -16.353, 0.000),
					Size = Vector3.new(13.721905708312988, 32.58733367919922, 9.827880859375),
				},
			},
		} :: AssetEntry,

		propeller_trampoline_1_001 = {
			Role = "FanCage",
			Kind = "Mount",
			Size = Vector3.new(35.38692092895508, 22.642114639282227, 35.38701248168945),
			Sockets = { Support = socket(0, -11.32, 0, 0, -1, 0) },
			SubParts = {
				{
					Name = "propeller_trampoline_2_001",
					RelativeCFrame = CFrame.new(0.000, 7.602, 0.000),
					Size = Vector3.new(29.059223175048828, 1.9473934173583984, 29.05949592590332),
				},
			},
		} :: AssetEntry,

		trampoline_1_001 = {
			Role = "JumpPadOuter",
			Kind = "Mount",
			Size = Vector3.new(11.609274864196777, 3.1249582767486572, 11.609457015991211),
			Sockets = { Support = socket(0, -1.56, 0, 0, -1, 0) },
			SubParts = {
				{
					Name = "trampoline_1_002",
					RelativeCFrame = CFrame.new(0.000, 1.825, 0.000),
					Size = Vector3.new(7.510320663452148, 1.0670387744903564, 7.510275363922125),
				},
			},
		} :: AssetEntry,

		-- Whirlpool Waltz sources. Walkable ride plates are raycast-measured in
		-- course-sockets-whirlpoolwaltz.json; mounted mechanisms take their
		-- Support contact and sub-part poses from inventory.json exactly as the
		-- pilot's hazards did (see that file's hazardPieceSupportSource note).
		obstacle_16_001 = {
			Role = "PizzaHub",
			Kind = "Mount",
			Size = Vector3.new(28.005094528198242, 6.287460803985596, 28.004690170288086),
			Sockets = {
				Support = socket(0, -3.1437, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 1, 0),
			},
			SubParts = {
				{
					Name = "obstacle_16_002",
					RelativeCFrame = CFrame.new(0.0000, -0.4916, 2.7767),
					Size = Vector3.new(77.84992218017578, 2.7612698078155519, 72.43607330322266),
				},
			},
			-- Measured half-extents 38.42/38.58/36.22/35.78 give a 35.78 minimum;
			-- the plate's own mesh origin sits 2.7767 off the hub axis in Z, so the
			-- usable radius about the axis is 35.78 - 2.78 = 33.0.
			Ride = { Plate = "obstacle_16_002", PlateTopLocalY = 1.380859375, Radius = 33.0 },
			Measurement = {
				RayStep = 0.5,
				Hits = 8507,
				Misses = 14581,
				EvidencePath = "docs/splashdown/evidence/course-sockets-whirlpoolwaltz.json",
			},
		} :: AssetEntry,
		obstacle_13_001 = {
			Role = "CarouselDeck",
			Kind = "Mount",
			Size = Vector3.new(52.55149841308594, 11.25034236907959, 52.55122375488281),
			Sockets = {
				Support = socket(0, -5.6252, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 1, 0),
			},
			SubParts = {
				{
					Name = "obstacle_13_002",
					RelativeCFrame = CFrame.new(0.0000, 16.1007, 3.2943),
					Size = Vector3.new(48.798709869384766, 29.75558090209961, 42.21034240722656),
				},
			},
			-- The deck IS the root here and the canopy is the sub-part, so Plate is
			-- nil. Solid measured top at 5.625; smallest half-extent 25.78.
			Ride = { PlateTopLocalY = 5.625, Radius = 25.5 },
			Measurement = {
				RayStep = 0.5,
				Hits = 8890,
				Misses = 2664,
				EvidencePath = "docs/splashdown/evidence/course-sockets-whirlpoolwaltz.json",
			},
		} :: AssetEntry,
		obstacle_14_001 = {
			Role = "DiscHubSmall",
			Kind = "Mount",
			Size = Vector3.new(9.857699394226074, 5.109390258789063, 9.857500076293945),
			Sockets = {
				Support = socket(0, -2.5547, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 1, 0),
			},
			SubParts = {
				{
					Name = "obstacle_14_002",
					RelativeCFrame = CFrame.new(0.0000, 0.5598, 0.0000),
					Size = Vector3.new(39.61509704589844, 2.339428663253784, 39.61509704589844),
				},
			},
			Ride = { Plate = "obstacle_14_002", PlateTopLocalY = 1.169921875, Radius = 19.3 },
			Measurement = {
				RayStep = 0.5,
				Hits = 4801,
				Misses = 1839,
				EvidencePath = "docs/splashdown/evidence/course-sockets-whirlpoolwaltz.json",
			},
		} :: AssetEntry,
		obstacle_15_001 = {
			Role = "DiscHubLarge",
			Kind = "Mount",
			Size = Vector3.new(14.441194534301758, 14.440902709960938, 14.441002845764161),
			Sockets = {
				Support = socket(0, -7.2205, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 1, 0),
			},
			SubParts = {
				{
					Name = "obstacle_15_002",
					RelativeCFrame = CFrame.new(0.0000, 0.0000, 0.0000),
					Size = Vector3.new(66.49325561523438, 4.039005756378174, 66.49325561523438),
				},
			},
			Ride = { Plate = "obstacle_15_002", PlateTopLocalY = 2.01953125, Radius = 32.7 },
			Measurement = {
				RayStep = 0.5,
				Hits = 13703,
				Misses = 4385,
				EvidencePath = "docs/splashdown/evidence/course-sockets-whirlpoolwaltz.json",
			},
		} :: AssetEntry,
		obstacle_26_001 = {
			Role = "DiscHubLargeVariant",
			Kind = "Mount",
			Size = Vector3.new(14.441194534301758, 14.440902709960938, 14.441002845764161),
			Sockets = {
				Support = socket(0, -7.2205, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 1, 0),
			},
			SubParts = {
				{
					Name = "obstacle_26_002",
					RelativeCFrame = CFrame.new(0.0000, 0.0000, 0.0000),
					Size = Vector3.new(66.49325561523438, 4.039005756378174, 66.49325561523438),
				},
			},
			Ride = { Plate = "obstacle_26_002", PlateTopLocalY = 2.01953125, Radius = 32.7 },
			Measurement = {
				RayStep = 0.5,
				Hits = 13703,
				Misses = 4385,
				EvidencePath = "docs/splashdown/evidence/course-sockets-whirlpoolwaltz.json",
			},
		} :: AssetEntry,
		obstacle_8_001 = {
			Role = "SwingPanelAxle",
			Kind = "Mount",
			Size = Vector3.new(41.12499618530273, 5.523500919342041, 5.523500919342041),
			Sockets = {
				Support = socket(0, -2.7617, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 1, 0, 0),
			},
			SubParts = {
				{
					Name = "obstacle_8_002",
					RelativeCFrame = CFrame.new(0.0000, 0.0000, -17.5898),
					Size = Vector3.new(39.25255584716797, 4.186964988708496, 39.36662292480469),
				},
			},
		} :: AssetEntry,
		obstacle_27_001 = {
			Role = "TwoArmCross",
			Kind = "Mount",
			Size = Vector3.new(6.2458, 12.349800109863281, 58.07600021362305),
			Sockets = {
				Support = socket(0, -6.1749, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 1, 0),
			},
			ContactRadius = 29.038,
		} :: AssetEntry,
		obstacle_12_001 = {
			Role = "CrossSpinner",
			Kind = "Mount",
			Size = Vector3.new(58.075901031494144, 12.349800109863281, 58.07600021362305),
			Sockets = {
				Support = socket(0, -6.1749, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 1, 0),
			},
			ContactRadius = 29.038,
		} :: AssetEntry,
		obstacle_6_001 = {
			Role = "Dumbbell",
			Kind = "Mount",
			Size = Vector3.new(38.35390090942383, 11.098400115966797, 4.976399898529053),
			Sockets = {
				Support = socket(0, -5.5492, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 1, 0),
			},
			ContactRadius = 19.177,
		} :: AssetEntry,
		trampoline_3_001 = {
			Role = "JumpPadOuterStriped",
			Kind = "Mount",
			Size = Vector3.new(27.002599716186523, 4.770599842071533, 27.002300262451172),
			Sockets = { Support = socket(0, -2.3853, 0, 0, -1, 0) },
			SubParts = {
				{
					Name = "trampoline_3_002",
					RelativeCFrame = CFrame.new(0.0000, 2.2315, 0.0001),
					Size = Vector3.new(18.082199096679688, 0.788900017738342, 18.082300186157227),
				},
			},
		} :: AssetEntry,
		arch_003 = {
			Role = "ArchFrame",
			Kind = "Mount",
			Size = Vector3.new(29.510601043701172, 12.846099853515625, 7.790400028228760),
			Sockets = { Support = socket(0, -6.4230, 0, 0, -1, 0) },
		} :: AssetEntry,
		water_platform_001 = {
			Role = "RoundLanding",
			Kind = "Surface",
			Size = Vector3.new(37.27314758300781, 9.406586647033692, 37.27314758300781),
			ForwardAxis = "Z",
			ForwardHeadingDegrees = 180,
			Sockets = {
				Entry = socket(0, 4.703125, -18.6366, 0, 0, -1),
				Exit = socket(0, 4.703125, 18.3634, 0, 0, 1),
				Support = socket(0, -4.7033, 0, 0, -1, 0),
				SidePositiveX = socket(18.3634, 4.703125, 0, 1, 0, 0),
				SideNegativeX = socket(-18.6361, 4.703125, 0, -1, 0, 0),
			},
			-- Also usable as a static round deck the route turns across: the
			-- measured top is solid (84 misses in 5,850 rays, all bevel) and the
			-- smallest measured half-extent is 18.36.
			Ride = { PlateTopLocalY = 4.703125, Radius = 18.36 },
			Measurement = {
				RayStep = 0.5,
				Hits = 5766,
				Misses = 84,
				EvidencePath = "docs/splashdown/evidence/course-sockets-whirlpoolwaltz.json",
			},
		} :: AssetEntry,

		-- Door Dash sources. Poses come from the live Kit hierarchy dump recorded in
		-- docs/splashdown/evidence/course-sockets-doordash.json, which agrees with
		-- evidence/inventory.json to the fourth decimal; RelativeCFrame is measured
		-- against each root part's own frame, exactly as the Whirlpool Waltz mounts
		-- were.
		obstacle_5_001 = {
			Role = "MaceTopLink",
			Kind = "Mount",
			Size = Vector3.new(1.7010, 3.8185, 2.4847),
			Sockets = {
				-- A mace hangs: HANDOFF 8.3 is explicit that "suspended mace links are
				-- supported by their chain and axle, not required to touch a floor", so
				-- the Support socket IS the axle at the top link's centre and the mount
				-- offset places the axle above the lane rather than a pole on it.
				Support = socket(0, 0, 0, 0, -1, 0),
				Axle = socket(0, 0, 0, 0, 0, 1),
			},
			-- The nine links and the ball are nested one inside the next in the source,
			-- so cloning the first brings the whole chain; every path below is still
			-- declared so each link is renamed, attributed and measured rather than
			-- surviving as an original source name (HANDOFF 3.3).
			SubParts = {
				{
					Name = "obstacle_5_002",
					RelativeCFrame = CFrame.new(0.0195, -2.0121, 0.0001),
					Size = Vector3.new(2.1468, 3.1170, 0.6931),
				},
				{
					Name = "obstacle_5_002.obstacle_5_003",
					RelativeCFrame = CFrame.new(0.0195, -3.6956, 0.0001),
					Size = Vector3.new(0.6930, 3.1170, 2.1467),
				},
				{
					Name = "obstacle_5_002.obstacle_5_003.obstacle_5_004",
					RelativeCFrame = CFrame.new(0.0195, -5.3569, 0.0001),
					Size = Vector3.new(2.1468, 3.1170, 0.6931),
				},
				{
					Name = "obstacle_5_002.obstacle_5_003.obstacle_5_004.obstacle_5_005",
					RelativeCFrame = CFrame.new(0.0195, -7.0404, 0.0001),
					Size = Vector3.new(0.6930, 3.1170, 2.1467),
				},
				{
					Name = "obstacle_5_002.obstacle_5_003.obstacle_5_004.obstacle_5_005.obstacle_5_006",
					RelativeCFrame = CFrame.new(0.0195, -8.7018, 0.0001),
					Size = Vector3.new(2.1468, 3.1170, 0.6931),
				},
				{
					Name = "obstacle_5_002.obstacle_5_003.obstacle_5_004.obstacle_5_005.obstacle_5_006.obstacle_5_007",
					RelativeCFrame = CFrame.new(0.0195, -10.3853, 0.0001),
					Size = Vector3.new(0.6930, 3.1170, 2.1467),
				},
				{
					Name = "obstacle_5_002.obstacle_5_003.obstacle_5_004.obstacle_5_005.obstacle_5_006.obstacle_5_007.obstacle_5_008",
					RelativeCFrame = CFrame.new(0.0195, -12.0466, 0.0001),
					Size = Vector3.new(2.1468, 3.1170, 0.6931),
				},
				{
					Name = "obstacle_5_002.obstacle_5_003.obstacle_5_004.obstacle_5_005.obstacle_5_006.obstacle_5_007.obstacle_5_008.obstacle_5_009",
					RelativeCFrame = CFrame.new(0.0195, -13.7301, 0.0001),
					Size = Vector3.new(0.6930, 3.1170, 2.1467),
				},
				{
					Name = "obstacle_5_002.obstacle_5_003.obstacle_5_004.obstacle_5_005.obstacle_5_006.obstacle_5_007.obstacle_5_008.obstacle_5_009.obstacle_5_010",
					RelativeCFrame = CFrame.new(0.0195, -15.3915, 0.0001),
					Size = Vector3.new(2.1468, 3.1170, 0.6931),
				},
				{
					Name = "obstacle_5_002.obstacle_5_003.obstacle_5_004.obstacle_5_005.obstacle_5_006.obstacle_5_007.obstacle_5_008.obstacle_5_009.obstacle_5_010.obstacle_5_011",
					RelativeCFrame = CFrame.new(0.0000, -20.7559, 0.0000),
					Size = Vector3.new(9.9658, 10.2346, 11.5074),
				},
			},
			-- The ball centre hangs 20.7559 below the axle at scale 1; that is the
			-- swing radius the course doc quotes, not a spin contact radius, because a
			-- mace is a rock profile and takes its speed from section 6's fixed
			-- amplitude/period rather than the spin formula.
			ContactRadius = 20.7559,
		} :: AssetEntry,
		obstacle_24_001 = {
			Role = "PaddleWheel",
			Kind = "Mount",
			Size = Vector3.new(59.8161, 43.8710, 43.8710),
			Sockets = {
				-- The four cradles orbit a point 4.2481 BELOW the root mesh's own
				-- centre (measured: the four relative Y/Z poses are symmetric about
				-- (-4.2481, 0.0665) at a common 15.4862 radius), so the wheel's real
				-- axle is not its display pivot. Support is the lowest point the
				-- cradles sweep through -- axle minus the orbit radius minus the
				-- cradle's own half height -- so mounting at a deck puts the blades
				-- exactly at deck level and a positive OffsetUp lifts them clear.
				Support = socket(0, -26.1015, 0.0665, 0, -1, 0),
				Axle = socket(0, -4.2481, 0.0665, 1, 0, 0),
			},
			SubParts = {
				{
					Name = "obstacle_24_002",
					RelativeCFrame = CFrame.new(0.0000, 11.2381, 0.0665),
					Size = Vector3.new(33.2637, 12.7341, 11.2431),
				},
				{
					Name = "obstacle_24_003",
					RelativeCFrame = CFrame.new(0.0000, -4.2481, 15.5527),
					Size = Vector3.new(33.2637, 12.7341, 11.2431),
				},
				{
					Name = "obstacle_24_004",
					RelativeCFrame = CFrame.new(0.0000, -4.2481, -15.4198),
					Size = Vector3.new(33.2637, 12.7341, 11.2431),
				},
				{
					Name = "obstacle_24_005",
					RelativeCFrame = CFrame.new(0.0000, -19.7344, 0.0665),
					Size = Vector3.new(33.2637, 12.7341, 11.2431),
				},
			},
			ContactRadius = 15.4862,
		} :: AssetEntry,
		trampoline_4_001 = {
			Role = "JumpPadOuterRibbed",
			Kind = "Mount",
			Size = Vector3.new(14.8598, 12.7562, 14.8595),
			Sockets = { Support = socket(0, -6.3781, 0, 0, -1, 0) },
			SubParts = {
				{
					Name = "trampoline_4_002",
					RelativeCFrame = CFrame.new(0.0000, 6.2757, 0.0000),
					Size = Vector3.new(9.0125, 1.2804, 9.0123),
				},
			},
		} :: AssetEntry,

		door_002 = {
			Role = "DoorSlab",
			Kind = "Mount",
			Size = Vector3.new(75.15200042724609, 45.78950119018555, 6.276500225067139),
			Sockets = { Support = socket(0, -22.8948, 0, 0, -1, 0) },
		} :: AssetEntry,
		door_003 = {
			Role = "DoorSlab",
			Kind = "Mount",
			Size = Vector3.new(75.15200042724609, 45.78950119018555, 6.276500225067139),
			Sockets = { Support = socket(0, -22.8948, 0, 0, -1, 0) },
		} :: AssetEntry,
		door_004 = {
			Role = "DoorSlab",
			Kind = "Mount",
			Size = Vector3.new(75.15200042724609, 45.78950119018555, 6.276500225067139),
			Sockets = { Support = socket(0, -22.8948, 0, 0, -1, 0) },
		} :: AssetEntry,
		door_005 = {
			Role = "DoorSlab",
			Kind = "Mount",
			Size = Vector3.new(75.15200042724609, 45.78950119018555, 6.276500225067139),
			Sockets = { Support = socket(0, -22.8948, 0, 0, -1, 0) },
		} :: AssetEntry,
		door_006 = {
			Role = "DoorSlab",
			Kind = "Mount",
			Size = Vector3.new(75.15200042724609, 45.78950119018555, 6.276500225067139),
			Sockets = { Support = socket(0, -22.8948, 0, 0, -1, 0) },
		} :: AssetEntry,
		door_007 = {
			Role = "DoorSlab",
			Kind = "Mount",
			Size = Vector3.new(75.15200042724609, 45.78950119018555, 6.276500225067139),
			Sockets = { Support = socket(0, -22.8948, 0, 0, -1, 0) },
		} :: AssetEntry,
	} :: any
) :: { [string]: AssetEntry }

function AssetManifest.get(id: string): AssetEntry
	local entry = AssetManifest.Assets[id]
	assert(entry ~= nil, `[AssetManifest] unknown source id "{id}"`)
	return entry
end

return AssetManifest
