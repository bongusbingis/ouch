-- Name: AssetManifest.luau
-- Author: Jack C.
-- Description: Versioned, measured facts about the ServerStorage.SplashdownAuthoringSources.Kit source assets that CourseBuilder places: per-source role, size, mechanical pivots for multi-part hazard assemblies, and Entry/Exit/Support sockets in each root part's own local (CFrame-relative) space. Every socket and surface figure here traces to a real Studio measurement recorded under docs/splashdown/evidence/; nothing is estimated.
-- Created: 2026-09-15

--!strict

local AssetManifest = {}

AssetManifest.Version = 1
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
export type AssetEntry = {
	Role: string,
	Kind: "Surface" | "Mount",
	Size: Vector3,
	ForwardAxis: ("X" | "Z")?,
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
	} :: any
) :: { [string]: AssetEntry }

function AssetManifest.get(id: string): AssetEntry
	local entry = AssetManifest.Assets[id]
	assert(entry ~= nil, `[AssetManifest] unknown source id "{id}"`)
	return entry
end

return AssetManifest
