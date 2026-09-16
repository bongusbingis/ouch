-- Name: CourseBuilder.luau
-- Author: Jack C.
-- Description: Assembles one declarative CourseSpec into a complete course Model: the Origin/Geometry/Beats/Hazards/Start/Checkpoints/Finish/Scriptables/Boundary/QA top-level contract every course template needs. Beats are packed along the spec's own Layout.Guide polyline (HANDOFF 5.2) by measured socket arclength, corners are real slabs entered and left through measured sockets, and the build fails rather than leaving the guide. Pure function of (spec, sources); never touches Workspace.battle_stadium or any global state, and performs no CollectionService tagging or registration.
-- Created: 2026-09-15

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetManifest = require(script.Parent.AssetManifest)
local CoursePresets = require(script.Parent.CoursePresets)
local AttributeAudit = require(ReplicatedStorage.Shared.Game.MapFeatures.AttributeAudit)

local CourseBuilder = {}

export type Cursor = CoursePresets.Cursor

-- HANDOFF 3.3: the finite metadata allowlist. Anything outside this set and the
-- audit's own kit vocabulary is a build failure, not a silently tolerated
-- attribute.
local METADATA_ALLOWLIST = {
	CourseId = true,
	BeatId = true,
	PieceId = true,
	GateId = true,
	SupportId = true,
	BuildVersion = true,
	SpecHash = true,
	SourceHash = true,
	QAOnly = true,
}

export type PieceSpec = {
	Id: string,
	-- "Chain" places a walkable piece nose-to-tail on the route cursor.
	-- "Corner" turns the route 90 degrees across one slab's measured side socket.
	-- "Mount" places a hazard at an offset from the cursor without advancing it.
	-- "Advance" moves the cursor with no geometry: the intended route crosses
	-- open air/liquid here (e.g. between BigBalls, which must sit over liquid
	-- with no walkable bypass slab underneath per HANDOFF 5.1/7.1).
	-- "Ride" places a rotating round ride platform the route crosses: the cursor
	-- enters at the rim, the centre sits one radius along, and it leaves at the
	-- opposite rim. Only a Spiral layout uses it, because a round deck is what
	-- absorbs a heading change without an illegal wedge seam (HANDOFF 5.2).
	-- "Flank" places a chained-preset piece beside, behind or above the cursor
	-- WITHOUT advancing it: the side tiles that widen a lane into a door-row
	-- corridor, and visible stock enclosure. It is listed before the Chain piece
	-- it sits beside, so both share the same entry line.
	-- "Island" is an Archipelago layout's only way between two islands: it moves the
	-- cursor onto the declared anchor of the next island, keeping the heading it
	-- arrived with, and the distance it crossed is MEASURED and classified as the
	-- beat's launch or its tile group -- never assumed.
	Kind: "Chain" | "Corner" | "Mount" | "Advance" | "Ride" | "Flank" | "Island",
	Preset: CoursePresets.PresetName?,
	Source: string?,
	Scale: number?,
	Reversed: boolean?,
	Direction: ("Left" | "Right")?,
	ConveyorSpeed: number?,
	OffsetAlong: number?,
	OffsetSide: number?,
	OffsetUp: number?,
	-- "Liquid" drops the mount's Support socket to the course liquid surface so a
	-- pole stands in the water instead of on an invented recovery slab
	-- (HANDOFF 7.1: "Mount poles on a submerged support ... supports cannot
	-- create a recovery walkway").
	MountTo: ("Cursor" | "Liquid")?,
	FacingOffsetDegrees: number?,
	-- Mount pieces only: an extra rotation about the piece's own local X axis,
	-- applied after the yaw, so a mounted asset can be laid on its side. The one
	-- thing in the kit that needs it is a fan: 02-kits.md requires "Rotate the fan
	-- so the visual grate faces the same direction", and a horizontal airflow
	-- column means the grate has to face along the route rather than at the sky.
	-- The piece still mounts by its Support socket, so the rotation happens about
	-- that socket and the caller lifts it back onto the deck with OffsetUp.
	PitchDegrees: number?,
	-- Pieces sharing a group are ONE encounter for section 7's counting rule
	-- ("Bumper: each chicane, or each isolated forced bumper"), because the runner
	-- solves them as a unit. Per-instance counts are reported separately and are
	-- never scored.
	EncounterGroup: string?,
	RotorAmplitude: number?,
	RotorPeriod: number?,
	RotorPhase: number?,
	ShoveSpeed: number?,
	LaunchSpeed: number?,
	FloatFactor: number?,
	FanAxis: ("X" | "Y" | "Z")?,
	FanDirection: number?,
	FanColumnHeight: number?,
	RotorSpeed: number?,
	DoorRow: number?,
	DoorIndex: number?,
	VolumeSize: Vector3?,
	SpeedMultiplier: number?,
	MaxTiltDegrees: number?,
	WindupSeconds: number?,
	StrikeSeconds: number?,
	FanBallSpeed: number?,
	DropDelaySeconds: number?,
	RespawnSeconds: number?,
	-- Island pieces only: which declared island this arrival lands on, and what the
	-- beat uses to get there. HANDOFF 5.2 allows exactly two links between
	-- consecutive islands -- "the beat's launch or tile group" -- so a third kind of
	-- crossing cannot be spelled at all. "Start" is the first island, walked onto
	-- from the start plaza.
	Island: number?,
	Link: ("Start" | "Launch" | "Tiles")?,
	-- Ride pieces only, on an Archipelago: the heading change the route makes across
	-- this round deck. A Spiral reads the same turn off its parametric guide.
	TurnDegrees: number?,
}

export type BeatSpec = {
	Id: string,
	Family: string,
	Mechanic: string,
	LengthTarget: number,
	Pieces: { PieceSpec },
}

export type StartSpec = {
	Rows: number,
	Columns: number,
	Spacing: number,
	Heading: number,
	Position: Vector3,
}

-- HANDOFF 5.2's other permitted guide form: "a parametric curve in local X/Z
-- with a Y profile". Angles are degrees measured so that a point sits at
-- (Radius * cos(angle), Radius * sin(angle)) in local X/Z, and the radius
-- interpolates linearly in angle. FinishRadius appends the section 5.2 "radial
-- finish to the hub" as a straight run inward from the spiral's last point, so
-- one arclength parametrization covers the whole route.
export type SpiralSpec = {
	AngleStartDegrees: number,
	AngleEndDegrees: number,
	RadiusStart: number,
	RadiusEnd: number,
	Samples: number,
	FinishRadius: number?,
}

-- HANDOFF 5.2's Chute: "One wide straight run, one hairpin, a second wide
-- straight run ... The hairpin sits at roughly 55-60% of the route (between beats
-- 03 and 04)." The guide is an ordinary three-segment polyline -- run, cross,
-- run -- and these are the invariants that make it a chute rather than a
-- serpentine: the second run doubles back on the first, the cross segment IS the
-- lane pitch that separates them, and the turn lands in the declared window of
-- the finished route. The window is checked at the hairpin's MIDDLE -- the point
-- the route actually reverses -- because the cross segment is a lane pitch long
-- and the entry and exit fractions straddle it; all three are reported.
export type ChuteSpec = {
	HairpinFractionMin: number,
	HairpinFractionMax: number,
	-- Both runs must be at least this multiple of the cross segment, which is what
	-- keeps the shape two long straights joined by one short turn.
	MinRunToPitchRatio: number,
}

-- HANDOFF 5.2's Loop: "A closed circuit around a central tunnel spine (arch_004
-- outbound, arch_006 return) that the route crosses twice. Start and finish sit
-- near each other on the outside of the loop but are separated by enclosure so the
-- finish is unreachable from the start plaza."
--
-- The guide is a five-segment polyline -- run, cross, run, cross, stub -- and these
-- are the invariants that make it a circuit rather than another chute:
--   1. five segments, with 1/3/5 parallel (3 reversed) and 2/4 exactly LanePitch;
--   2. four turns of the SAME handedness summing to exactly +-360 degrees, which is
--      what closes the circuit; a chute's two turns sum to 180 and double back;
--   3. the finish lands Closure{Min,Max}Studs from the start plaza, so the two
--      really are adjacent on the outside of the loop without overlapping;
--   4. the two long runs sit within SpineHalfWidth of the circuit's own centre
--      line, so the spine is central rather than a wide perimeter ring;
--   5. the declared outbound and return tunnels are placed, one on each long run,
--      which is what "the route crosses [the spine] twice" means in geometry.
export type LoopSpec = {
	ClosureMinStuds: number,
	ClosureMaxStuds: number,
	SpineHalfWidth: number,
	OutboundTunnelPieceId: string,
	ReturnTunnelPieceId: string,
}

-- HANDOFF 5.2's Archipelago: "Islands placed radially around the origin; start at
-- the perimeter and finish at the centre island (or the reverse if the measured
-- launch envelopes fit better); consecutive islands are linked only by the beat's
-- launch or tile group; non-consecutive islands are separated by more than the
-- maximum measured launch reach."
--
-- There is no polyline guide, because an archipelago's guide IS its island list:
-- every island declares its own polar anchor, and the route is required to arrive
-- exactly there. That is a strictly stronger statement than "stay under a
-- polyline's length", which is why an Archipelago does not cap segment travel the
-- way a Serpentine or a Spiral does. The enforced invariants are:
--   1. at least five islands, entered once each in declared order;
--   2. anchor radii strictly monotone, from PerimeterRadius out at the start to
--      CentreRadius in at the finish (or the reverse);
--   3. every island after the first is entered by a measured crossing that is
--      either a LAUNCH (longer than the measured ordinary jump, no longer than the
--      measured launch reach, and preceded by this beat's own fan or pad) or a TILE
--      GROUP (a flush arrival at the far end of at least two chained falling tiles);
--   4. every island after the first begins on a round landing deck, because a round
--      deck is what absorbs a heading change without a wedge seam;
--   5. every heading change happens on such a deck and is no larger than
--      MaxTurnDegrees; and
--   6. the route on any two NON-consecutive islands stays further apart than the
--      measured launch reach, measured polyline to polyline and reduced by both
--      islands' half-widths -- so no launch anywhere can skip the chain.
export type ArchipelagoIsland = {
	Id: string,
	AngleDegrees: number,
	Radius: number,
	Y: number,
}

export type ArchipelagoSpec = {
	Islands: { ArchipelagoIsland },
	-- The measured movement constants from HANDOFF 3.2, so every reach in this
	-- layout is DERIVED from them rather than declared per crossing: gravity 120,
	-- WalkSpeed 26, JumpHeight 10 with UseJumpPower=false. JumpReachCalibration is
	-- the measured 22-stud flat gap minus this model's own flat prediction, which is
	-- the avatar's body extent; it is added to every reach.
	Gravity: number,
	WalkSpeed: number,
	JumpHeight: number,
	JumpReachCalibration: number,
	MaxTurnDegrees: number,
	-- How far a launch's flight may point away from the heading it took off on.
	MaxFlightDeviationDegrees: number,
	PerimeterRadius: number,
	CentreRadius: number,
}

export type LayoutSpec = {
	Kind: string,
	LanePitch: number,
	BoundsRadius: number,
	LiquidY: number,
	-- HANDOFF 5.2 guide polyline in local X/Z. The route never leaves it: every
	-- straight run is capped by its segment length and every turn happens at a
	-- vertex, which is what bounds the course rather than trusting the spec.
	-- Serpentine uses Guide; Spiral uses Spiral instead. Exactly one is required.
	Guide: { Vector3 }?,
	Spiral: SpiralSpec?,
	Chute: ChuteSpec?,
	Loop: LoopSpec?,
	Archipelago: ArchipelagoSpec?,
	-- Spiral only: how far a chained run may drift from the parametric guide
	-- before the build fails. A straight slab chord always sits slightly outside
	-- the arc it approximates; this is the measured budget for that, not licence
	-- to wander.
	GuideTolerance: number?,
	Corner: { Source: string, Scale: number },
	Fill: { Source: string, Scale: number },
}

export type CourseSpec = {
	Version: number,
	Id: string,
	DisplayName: string,
	-- The encounter type section 7 names as this course's headline. It is
	-- declared rather than inferred, because the most frequent encounter in a
	-- course is usually its glue, not the thing the course is about; the
	-- cross-course rules in override 2 are scored against this.
	Headline: string,
	Difficulty: number,
	ParSeconds: number,
	CapSeconds: number,
	CloseWindowSeconds: number,
	Layout: LayoutSpec,
	Start: StartSpec,
	Beats: { BeatSpec },
}

export type Sources = {
	Kit: Instance,
	BoundaryWall: BasePart,
}

export type RouteStep = {
	BeatId: string,
	PieceId: string,
	Kind: string,
	Position: Vector3,
	Yaw: number,
	Segment: number,
	SegmentTravel: number,
	ArcLength: number,
	-- Archipelago only: which island this step stands on. Zero means the step is part
	-- of a LINK between two islands -- a tile group bridging open water -- and is
	-- therefore excluded from the island separation audit, which is about the islands
	-- themselves.
	Island: number,
	-- The piece's MEASURED lateral half-extent about the route line: the oriented
	-- support width of every part it placed, projected onto the route's own right
	-- vector. The island separation audit subtracts this rather than a declared
	-- budget, so "these islands are 45 studs apart" is a statement about real
	-- geometry.
	HalfWidth: number,
}

export type BeatMeasure = {
	Id: string,
	ArcLength: number,
	LengthTarget: number,
	Ratio: number,
	ElevationChange: number,
}

export type BoundsReport = {
	MaxCornerDistance: number,
	MaxGeometryCenterRadius: number,
	MaxRouteRadius: number,
	-- HANDOFF 5.1.10 scopes the -30..90 band to the static ROUTE envelope and
	-- separately extends only the 600 rule to "every part corner, liquid and
	-- boundary included", so the perimeter ring and the liquid plane are measured
	-- and reported but not held to the route band.
	RouteMinY: number,
	RouteMaxY: number,
	MinY: number,
	MaxY: number,
	Violations: { string },
}

export type BuildReport = {
	Ok: boolean,
	Id: string,
	PartCount: number,
	BuildSeconds: number,
	AttributeErrors: { string },
	RouteErrors: { string },
	SpecHash: string,
	RouteLength: number,
	Beats: { BeatMeasure },
	Route: { RouteStep },
	Bounds: BoundsReport,
	CheckpointCount: number,
	-- Spiral only: the worst measured distance between the built route and the
	-- parametric guide, and the guide's own total arclength.
	GuideDeviation: number,
	GuideLength: number,
	-- Chute only: the route fractions at which the route leaves the first run,
	-- turns, and lands on the second. Zero for every other layout.
	HairpinFraction: number,
	HairpinMidFraction: number,
	HairpinExitFraction: number,
	-- Loop only: the horizontal distance between the start plaza and the finish,
	-- and the total signed heading change the route turned through. Zero for every
	-- other layout.
	LoopClosureStuds: number,
	LoopTotalTurnDegrees: number,
	-- Archipelago only. Every measured island crossing, and the worst measured
	-- separation between two non-consecutive islands. Empty/zero elsewhere.
	IslandLinks: {
		{
			Island: number,
			Link: string,
			GapStuds: number,
			RiseStuds: number,
			FlightDeviationDegrees: number,
		}
	},
	WorstIslandSeparation: number,
	WorstIslandSeparationPair: string,
	-- The worst horizontal reach any launch tool this course places can achieve over
	-- the largest drop between any two of its islands: the number the separation rule
	-- is scored against, derived rather than declared.
	MaxLaunchReach: number,
}

local function forward(headingDegrees: number): Vector3
	local radians = math.rad(headingDegrees)
	return Vector3.new(-math.sin(radians), 0, -math.cos(radians))
end

local function right(headingDegrees: number): Vector3
	return forward(headingDegrees - 90)
end

local function normalizeDegrees(value: number): number
	return (value % 360 + 360) % 360
end

local function marker(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- octagon_002 (01-asset-inventory.md line 168): 309.8 x 11.2 x 309.8 flat plaza
-- slab, uniformly scaled down. Start/Finish are the only unrestricted plazas
-- (HANDOFF 5.1.9); this is real supported floor, not a reference marker.
-- `diameterStuds` is the finished circular footprint's diameter: callers pick
-- it so the inscribed rectangle they actually need (grid extent, or finish
-- deck) clears comfortably, not the raw grid spacing.
local function buildPlaza(sources: Sources, courseId: string, center: Vector3, diameterStuds: number): BasePart
	local source = sources.Kit:FindFirstChild("octagon_002")
	assert(source and source:IsA("BasePart"), "[CourseBuilder] octagon_002 missing from injected Kit sources")
	local plaza = (source :: BasePart):Clone()
	local scale = diameterStuds / 309.8
	plaza.Size = plaza.Size * scale
	plaza.PivotOffset = CFrame.identity
	plaza.Anchored = true
	plaza.CanCollide = true
	plaza.CanTouch = false
	plaza.CanQuery = true
	plaza:SetAttribute("SourceAsset", "octagon_002")
	plaza:SetAttribute("CourseId", courseId)
	plaza.CFrame = CFrame.new(center.X, center.Y - plaza.Size.Y / 2, center.Z)
	return plaza
end

local function buildStartPads(spec: CourseSpec, sources: Sources, startFolder: Folder, geometry: Folder): Cursor
	local start = spec.Start
	-- Grid footprint is (columns-1)*spacing by (rows-1)*spacing; HANDOFF 5.1.9
	-- requires at least 36x30 clear, so the inscribed rectangle must clear that
	-- with margin. Diameter = diagonal of the required rectangle plus a
	-- generous margin so the circle is never the binding constraint.
	local requiredWidth = math.max(36, (start.Columns - 1) * start.Spacing + 6)
	local requiredDepth = math.max(30, (start.Rows - 1) * start.Spacing + 6)
	local diameter = math.sqrt(requiredWidth ^ 2 + requiredDepth ^ 2) + 6
	local plaza = buildPlaza(sources, spec.Id, start.Position, diameter)
	plaza.Name = string.format("sd_%s_00_startplaza_1", spec.Id)
	plaza.Parent = geometry

	local pads = Instance.new("Folder")
	pads.Name = "Pads"
	pads.Parent = startFolder
	local count = 0
	local halfCols = (start.Columns - 1) / 2
	local halfRows = (start.Rows - 1) / 2
	for row = 0, start.Rows - 1 do
		for column = 0, start.Columns - 1 do
			count += 1
			local across = (column - halfCols) * start.Spacing
			local along = (row - halfRows) * start.Spacing
			local position = start.Position + right(start.Heading) * across + forward(start.Heading) * along
			marker(string.format("Pad%02d", count), Vector3.new(5, 1, 5), CFrame.new(position), pads)
		end
	end
	assert(count == 30, `[CourseBuilder] start grid produced {count} pads, expected 30`)
	local exitPosition = start.Position + forward(start.Heading) * (halfRows * start.Spacing + start.Spacing * 2)
	return { Position = exitPosition, Yaw = start.Heading }
end

-- Checkpoint pads sit BEFORE the beat's first hazard (HANDOFF 5.1.8), so the pad
-- is pulled back onto the previous beat's last stable slab rather than balanced
-- on its exit edge.
local function buildCheckpoint(index: number, cursor: Cursor, checkpointsFolder: Folder)
	local checkpoint = Instance.new("Model")
	checkpoint.Name = string.format("Checkpoint%02d", index)
	checkpoint.Parent = checkpointsFolder
	local padDepth = 8
	local center = cursor.Position - forward(cursor.Yaw) * (padDepth / 2)
	local cframe = CFrame.new(center) * CFrame.Angles(0, math.rad(cursor.Yaw), 0)
	marker("Pad", Vector3.new(12, 1, padDepth), cframe, checkpoint)
	marker("Trigger", Vector3.new(12, 8, 2), cframe * CFrame.new(0, 4, 0), checkpoint)
end

local function buildFinish(sources: Sources, courseId: string, cursor: Cursor, finishFolder: Folder, geometry: Folder)
	-- Deck marker is 24x20; diagonal ~31.2, so 34 clears it. Kept tight on purpose:
	-- a wider finish plaza reaches back under the last beat and lets a racer drop
	-- straight onto the deck instead of running the beat (the cut-set audit caught
	-- exactly that at diameter 40).
	local plaza = buildPlaza(sources, courseId, cursor.Position, 34)
	plaza.Name = string.format("sd_%s_99_finishplaza_1", courseId)
	plaza.Parent = geometry
	local cframe = CFrame.new(cursor.Position) * CFrame.Angles(0, math.rad(cursor.Yaw), 0)
	marker("Deck", Vector3.new(24, 1, 20), cframe, finishFolder)
	marker("Trigger", Vector3.new(24, 8, 2), cframe * CFrame.new(0, 4, 0), finishFolder)
end

-- 24 invisible colliding walls at radius 390, the existing boundary contract
-- (HANDOFF 8.1 and author-splashdown-courses.luau's boundary()). The ring is
-- based at the course liquid surface exactly as the original is based at its
-- lava plane, so the wall spans the whole reachable column instead of being
-- centred on an arbitrary origin.
local function buildBoundary(
	radius: number,
	segments: number,
	baseY: number,
	wallTemplate: BasePart,
	boundaryFolder: Folder
)
	local height = wallTemplate.Size.Y
	for index = 1, segments do
		local angle = (index - 1) / segments * 2 * math.pi
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local wall = wallTemplate:Clone()
		wall.Name = string.format("Wall%02d", index)
		wall.Anchored = true
		wall.CanCollide = true
		wall.CanTouch = false
		wall.CanQuery = true
		wall.Transparency = 1
		wall.CFrame = CFrame.lookAt(
			outward * radius + Vector3.new(0, baseY + height / 2, 0),
			Vector3.new(0, baseY + height / 2, 0)
		)
		wall.Parent = boundaryFolder
	end
end

local function buildHazardLiquid(boundsRadius: number, liquidY: number, hazardsFolder: Folder)
	local liquid = Instance.new("Part")
	liquid.Name = "Liquid"
	liquid.Shape = Enum.PartType.Block
	liquid.Size = Vector3.new(boundsRadius * 2 + 40, 1, boundsRadius * 2 + 40)
	liquid.CFrame = CFrame.new(0, liquidY - 0.5, 0)
	liquid.Anchored = true
	liquid.CanCollide = false
	liquid.CanTouch = true
	liquid.CanQuery = true
	liquid.Transparency = 0.3
	liquid.Color = Color3.fromRGB(60, 140, 220)
	liquid.Parent = hazardsFolder
end

local function offsetCFrame(cursor: Cursor, piece: PieceSpec, liquidY: number): CFrame
	local along = piece.OffsetAlong or 0
	local side = piece.OffsetSide or 0
	local up = piece.OffsetUp or 0
	local position = cursor.Position + forward(cursor.Yaw) * along + right(cursor.Yaw) * side + Vector3.new(0, up, 0)
	if piece.MountTo == "Liquid" then
		position = Vector3.new(position.X, liquidY + up, position.Z)
	end
	local yaw = cursor.Yaw + (piece.FacingOffsetDegrees or 0)
	local frame = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
	if piece.PitchDegrees then
		frame *= CFrame.Angles(math.rad(piece.PitchDegrees), 0, 0)
	end
	return frame
end

local function countParts(model: Model): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

-- HANDOFF 8.1/5.1.10: every transformed corner within 600 of Origin, geometry
-- centres within 380, new route design within a 300 horizontal radius, Y between
-- -30 and 90. Pivots alone are not enough, so all eight corners are enumerated.
local function auditBounds(
	model: Model,
	geometry: Folder,
	perimeter: { Instance },
	route: { RouteStep },
	boundsRadius: number
): BoundsReport
	local report: BoundsReport = {
		MaxCornerDistance = 0,
		MaxGeometryCenterRadius = 0,
		MaxRouteRadius = 0,
		RouteMinY = math.huge,
		RouteMaxY = -math.huge,
		MinY = math.huge,
		MaxY = -math.huge,
		Violations = {},
	}
	local worstCorner: BasePart? = nil
	local worstCenter: BasePart? = nil
	local worstRoute: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local isPerimeter = false
			for _, container in perimeter do
				if descendant:IsDescendantOf(container) then
					isPerimeter = true
					break
				end
			end
			local half = descendant.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner =
							descendant.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						if corner.Magnitude > report.MaxCornerDistance then
							report.MaxCornerDistance = corner.Magnitude
							worstCorner = descendant
						end
						report.MinY = math.min(report.MinY, corner.Y)
						report.MaxY = math.max(report.MaxY, corner.Y)
						if not isPerimeter then
							if corner.Y < report.RouteMinY or corner.Y > report.RouteMaxY then
								worstRoute = descendant
							end
							report.RouteMinY = math.min(report.RouteMinY, corner.Y)
							report.RouteMaxY = math.max(report.RouteMaxY, corner.Y)
						end
					end
				end
			end
			if descendant:IsDescendantOf(geometry) then
				local center = descendant.Position
				local radius = Vector3.new(center.X, 0, center.Z).Magnitude
				if radius > report.MaxGeometryCenterRadius then
					report.MaxGeometryCenterRadius = radius
					worstCenter = descendant
				end
			end
		end
	end
	for _, step in route do
		report.MaxRouteRadius =
			math.max(report.MaxRouteRadius, Vector3.new(step.Position.X, 0, step.Position.Z).Magnitude)
	end
	if report.MaxCornerDistance > 600 then
		table.insert(
			report.Violations,
			string.format(
				"part corner %.1f > 600 of Origin (%s)",
				report.MaxCornerDistance,
				if worstCorner then worstCorner:GetFullName() else "?"
			)
		)
	end
	if report.MaxGeometryCenterRadius > 380 then
		table.insert(
			report.Violations,
			string.format(
				"geometry centre radius %.1f > 380 (%s)",
				report.MaxGeometryCenterRadius,
				if worstCenter then worstCenter:GetFullName() else "?"
			)
		)
	end
	if report.MaxRouteRadius > boundsRadius then
		table.insert(
			report.Violations,
			string.format("route radius %.1f > BoundsRadius %d", report.MaxRouteRadius, boundsRadius)
		)
	end
	if report.RouteMinY < -30 or report.RouteMaxY > 90 then
		table.insert(
			report.Violations,
			string.format(
				"static route envelope Y %.1f..%.1f leaves the -30..90 band (%s)",
				report.RouteMinY,
				report.RouteMaxY,
				if worstRoute then worstRoute:GetFullName() else "?"
			)
		)
	end
	return report
end

-- Non-cryptographic order-sensitive hash: sufficient to detect a non-deterministic
-- rebuild (section 5.1.12 compares two builds against each other, not a security
-- boundary), computed from sorted class/name/attribute/mesh/scale/CFrame text.
local function fnv1a(text: string): number
	local hash = 2166136261
	for index = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, index))
		hash = (hash * 16777619) % 4294967296
	end
	return hash
end

local function computeSpecHash(model: Model): string
	local descendants = model:GetDescendants()
	table.sort(descendants, function(left, right2)
		return left:GetFullName() < right2:GetFullName()
	end)
	local lines = {}
	for _, instance in descendants do
		if instance:IsA("BasePart") then
			local attributeParts = {}
			for key, value in instance:GetAttributes() do
				table.insert(attributeParts, string.format("%s=%s", key, tostring(value)))
			end
			table.sort(attributeParts)
			local meshId = if instance:IsA("MeshPart") then instance.MeshId else ""
			table.insert(
				lines,
				string.format(
					"%s|%s|%s|%s|%s|%s",
					instance:GetFullName(),
					instance.ClassName,
					tostring(instance.Size),
					meshId,
					tostring(instance.CFrame),
					table.concat(attributeParts, ",")
				)
			)
		end
	end
	return string.format("%08x", fnv1a(table.concat(lines, "\n")))
end

type Segment = { Length: number, Heading: number }

local function buildSegments(guide: { Vector3 }): { Segment }
	assert(#guide >= 2, "[CourseBuilder] Layout.Guide needs at least two points")
	local segments: { Segment } = {}
	for index = 2, #guide do
		local delta = guide[index] - guide[index - 1]
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local length = flat.Magnitude
		assert(length > 0, `[CourseBuilder] Layout.Guide point {index} repeats point {index - 1}`)
		local direction = flat / length
		local heading = math.deg(math.atan2(-direction.X, -direction.Z))
		table.insert(segments, { Length = length, Heading = heading })
	end
	return segments
end

-- A guide sampled densely enough that arclength, position and tangent can all be
-- read at any distance along it. Serpentine does not use this: its straight runs
-- and 90-degree corner slabs already bound the route exactly, and reusing this
-- for it would change the pilot's build.
type GuideCurve = {
	Length: number,
	Points: { Vector3 },
	Cumulative: { number },
	PointAt: (number) -> Vector3,
	YawAt: (number) -> number,
}

local function headingOf(direction: Vector3): number
	return math.deg(math.atan2(-direction.X, -direction.Z))
end

-- Shortest horizontal distance from a point to a segment, and between two
-- segments. Used only by the Archipelago separation audit, where "how far apart are
-- these two islands" has to mean the closest approach of the route on each of them,
-- not the distance between two chosen anchors.
local function pointToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(point.X - a.X, 0, point.Z - a.Z)
	local lengthSquared = ab:Dot(ab)
	local t = if lengthSquared > 1e-9 then math.clamp(ap:Dot(ab) / lengthSquared, 0, 1) else 0
	return (ap - ab * t).Magnitude
end

local function segmentDistance(a1: Vector3, a2: Vector3, b1: Vector3, b2: Vector3): number
	return math.min(
		pointToSegment(a1, b1, b2),
		pointToSegment(a2, b1, b2),
		pointToSegment(b1, a1, a2),
		pointToSegment(b2, a1, a2)
	)
end

-- Horizontal reach of a ballistic hop that leaves at `launchSpeed` straight up,
-- falls under `gravity` (reduced by a kit float factor), steers at `walkSpeed` for
-- the whole flight, and has to land `rise` studs above its takeoff. It is the
-- LATER root of rise = v*t - g*t^2/2, because that is the descending crossing; a
-- negative discriminant means the landing is simply out of reach. HANDOFF 3.2's
-- measured numbers feed it, and the measured 22-stud flat gap calibrates it: the
-- model predicts 21.23 for an ordinary jump, so the difference is the avatar's own
-- body extent and is added back.
local function ballisticReach(
	launchSpeed: number,
	gravity: number,
	walkSpeed: number,
	rise: number,
	calibration: number
): number
	local discriminant = launchSpeed * launchSpeed - 2 * gravity * rise
	if discriminant < 0 then
		return 0
	end
	local seconds = (launchSpeed + math.sqrt(discriminant)) / gravity
	return walkSpeed * seconds + calibration
end

local function jumpReach(archipelago: ArchipelagoSpec, rise: number): number
	local velocity = math.sqrt(2 * archipelago.Gravity * archipelago.JumpHeight)
	return ballisticReach(velocity, archipelago.Gravity, archipelago.WalkSpeed, rise, archipelago.JumpReachCalibration)
end

local function launchReach(archipelago: ArchipelagoSpec, rise: number, speed: number, floatFactor: number): number
	return ballisticReach(
		speed,
		archipelago.Gravity * (1 - floatFactor),
		archipelago.WalkSpeed,
		rise,
		archipelago.JumpReachCalibration
	)
end

local function islandAnchor(island: ArchipelagoIsland): Vector3
	local radians = math.rad(island.AngleDegrees)
	return Vector3.new(island.Radius * math.cos(radians), island.Y, island.Radius * math.sin(radians))
end

-- How far a placed piece really reaches sideways from the route line, measured as
-- the oriented-bounding-box support width of each of its parts along the route's own
-- right vector, plus that part's own sideways offset. This is the standard OBB
-- support function, so a slab rotated against the route is measured at its true
-- extent rather than at half of one named dimension.
local function lateralHalfWidth(model: Instance, origin: Vector3, yaw: number): number
	local side = right(yaw)
	local widest = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local frame = descendant.CFrame
			local size = descendant.Size
			local support = 0.5
				* (
					math.abs(size.X * frame.RightVector:Dot(side))
					+ math.abs(size.Y * frame.UpVector:Dot(side))
					+ math.abs(size.Z * frame.LookVector:Dot(side))
				)
			widest = math.max(widest, math.abs((descendant.Position - origin):Dot(side)) + support)
		end
	end
	if model:IsA("BasePart") then
		local frame = (model :: BasePart).CFrame
		local size = (model :: BasePart).Size
		local support = 0.5
			* (
				math.abs(size.X * frame.RightVector:Dot(side))
				+ math.abs(size.Y * frame.UpVector:Dot(side))
				+ math.abs(size.Z * frame.LookVector:Dot(side))
			)
		widest = math.max(widest, math.abs(((model :: BasePart).Position - origin):Dot(side)) + support)
	end
	return widest
end

local function buildSpiralGuide(spiral: SpiralSpec): GuideCurve
	local samples = math.max(16, math.floor(spiral.Samples))
	local points: { Vector3 } = {}
	for index = 0, samples do
		local t = index / samples
		local angle = math.rad(spiral.AngleStartDegrees + (spiral.AngleEndDegrees - spiral.AngleStartDegrees) * t)
		local radius = spiral.RadiusStart + (spiral.RadiusEnd - spiral.RadiusStart) * t
		table.insert(points, Vector3.new(radius * math.cos(angle), 0, radius * math.sin(angle)))
	end

	local finishRadius = spiral.FinishRadius
	if finishRadius ~= nil then
		assert(finishRadius < spiral.RadiusEnd, "[CourseBuilder] Spiral.FinishRadius must be inside RadiusEnd")
		local endAngle = math.rad(spiral.AngleEndDegrees)
		local outward = Vector3.new(math.cos(endAngle), 0, math.sin(endAngle))
		local steps = math.max(2, math.ceil((spiral.RadiusEnd - finishRadius) / 8))
		for index = 1, steps do
			local radius = spiral.RadiusEnd + (finishRadius - spiral.RadiusEnd) * (index / steps)
			table.insert(points, outward * radius)
		end
	end

	local cumulative: { number } = { 0 }
	for index = 2, #points do
		local delta = points[index] - points[index - 1]
		cumulative[index] = cumulative[index - 1] + Vector3.new(delta.X, 0, delta.Z).Magnitude
	end
	local length = cumulative[#cumulative]

	local function locate(distance: number): (number, number)
		local clamped = math.clamp(distance, 0, length)
		local low, high = 1, #cumulative
		while low < high do
			local middle = (low + high + 1) // 2
			if cumulative[middle] <= clamped then
				low = middle
			else
				high = middle - 1
			end
		end
		local index = math.min(low, #points - 1)
		local span = cumulative[index + 1] - cumulative[index]
		local fraction = if span > 1e-9 then (clamped - cumulative[index]) / span else 0
		return index, fraction
	end

	local curve = {
		Length = length,
		Points = points,
		Cumulative = cumulative,
		PointAt = function(distance: number): Vector3
			local index, fraction = locate(distance)
			return points[index]:Lerp(points[index + 1], fraction)
		end,
		YawAt = function(distance: number): number
			local index = locate(distance)
			local delta = points[index + 1] - points[index]
			return headingOf(Vector3.new(delta.X, 0, delta.Z).Unit)
		end,
	}
	return curve :: GuideCurve
end

function CourseBuilder.build(spec: CourseSpec, sources: Sources): (Model, BuildReport)
	local startClock = os.clock()
	local layout = spec.Layout
	local liquidY = layout.LiquidY
	assert(
		layout.Kind == "Serpentine"
			or layout.Kind == "Spiral"
			or layout.Kind == "Chute"
			or layout.Kind == "Loop"
			or layout.Kind == "Archipelago",
		`[CourseBuilder] unknown Layout.Kind "{layout.Kind}"`
	)
	local isSpiral = layout.Kind == "Spiral"
	local isChute = layout.Kind == "Chute"
	local isLoop = layout.Kind == "Loop"
	local isArchipelago = layout.Kind == "Archipelago"
	local curve: GuideCurve? = if isSpiral
		then buildSpiralGuide(assert(layout.Spiral, "[CourseBuilder] a Spiral layout needs Layout.Spiral"))
		else nil
	local segments = if isSpiral or isArchipelago
		then {} :: { Segment }
		else buildSegments(assert(layout.Guide, `[CourseBuilder] a {layout.Kind} layout needs Layout.Guide`))
	local guideTolerance = layout.GuideTolerance or 12
	local routeErrors: { string } = {}
	local chute = if isChute then assert(layout.Chute, "[CourseBuilder] a Chute layout needs Layout.Chute") else nil
	if chute then
		assert(
			#segments == 3,
			`[CourseBuilder] a Chute guide is run/cross/run: 3 segments, not {#segments} (HANDOFF 5.2)`
		)
		local doubleBack = normalizeDegrees(segments[3].Heading - segments[1].Heading)
		assert(
			math.abs(doubleBack - 180) < 1e-3,
			string.format(
				"[CourseBuilder] a Chute's second run must double back on the first: runs head %.1f and %.1f",
				segments[1].Heading,
				segments[3].Heading
			)
		)
		assert(
			math.abs(segments[2].Length - layout.LanePitch) < 1e-3,
			string.format(
				"[CourseBuilder] the Chute's cross segment is %.2f studs but LanePitch is %.2f; the pitch IS the separation between the two runs",
				segments[2].Length,
				layout.LanePitch
			)
		)
		local ratio = chute.MinRunToPitchRatio
		assert(
			segments[1].Length >= layout.LanePitch * ratio and segments[3].Length >= layout.LanePitch * ratio,
			string.format(
				"[CourseBuilder] a Chute's runs must each be at least %.1f x its %.1f-stud pitch; they are %.2f and %.2f",
				ratio,
				layout.LanePitch,
				segments[1].Length,
				segments[3].Length
			)
		)
	end
	local loop = if isLoop then assert(layout.Loop, "[CourseBuilder] a Loop layout needs Layout.Loop") else nil
	local loopTotalTurn = 0
	if loop then
		assert(
			#segments == 5,
			`[CourseBuilder] a Loop guide is run/cross/run/cross/stub: 5 segments, not {#segments} (HANDOFF 5.2)`
		)
		for index, expected in { [3] = 180, [5] = 0 } do
			local drift = normalizeDegrees(segments[index].Heading - segments[1].Heading - expected)
			assert(
				math.min(drift, 360 - drift) < 1e-3,
				string.format(
					"[CourseBuilder] a Loop's segment %d must run %d degrees off segment 1; it heads %.1f against %.1f",
					index,
					expected,
					segments[index].Heading,
					segments[1].Heading
				)
			)
		end
		for _, index in { 2, 4 } do
			assert(
				math.abs(segments[index].Length - layout.LanePitch) < 1e-3,
				string.format(
					"[CourseBuilder] a Loop's cross segment %d is %.2f studs but LanePitch is %.2f; the pitch IS the separation between the two runs",
					index,
					segments[index].Length,
					layout.LanePitch
				)
			)
		end
		-- Four turns of one handedness, summing to a full circle. A chute's two turns
		-- sum to 180 and reverse the route onto itself; only a closed circuit comes
		-- back round to its own start.
		local firstSign = 0
		for index = 2, #segments do
			local delta = normalizeDegrees(segments[index].Heading - segments[index - 1].Heading)
			local signed = if delta > 180 then delta - 360 else delta
			assert(
				math.abs(math.abs(signed) - 90) < 1e-3,
				string.format(
					"[CourseBuilder] a Loop turns in right angles; turn %d is %.1f degrees",
					index - 1,
					signed
				)
			)
			local sign = if signed > 0 then 1 else -1
			if firstSign == 0 then
				firstSign = sign
			end
			assert(
				sign == firstSign,
				string.format("[CourseBuilder] a Loop's turns must all go the same way; turn %d reverses", index - 1)
			)
			loopTotalTurn += signed
		end
		assert(
			math.abs(math.abs(loopTotalTurn) - 360) < 1e-3,
			string.format(
				"[CourseBuilder] a Loop must close a full circuit: its turns sum to %.1f degrees, not 360",
				loopTotalTurn
			)
		)
		-- The spine is central when both long runs sit within the declared band of the
		-- circuit's own centre line, which for a run/cross/run guide is exactly half
		-- the lane pitch away from it.
		assert(
			layout.LanePitch / 2 <= loop.SpineHalfWidth,
			string.format(
				"[CourseBuilder] a Loop's runs sit %.2f studs off its centre line, outside the declared %.2f-stud spine (HANDOFF 5.2 wants a CENTRAL tunnel spine)",
				layout.LanePitch / 2,
				loop.SpineHalfWidth
			)
		)
	end
	local archipelago = if isArchipelago
		then assert(layout.Archipelago, "[CourseBuilder] an Archipelago layout needs Layout.Archipelago")
		else nil
	local islandLinks: { { Island: number, Link: string, GapStuds: number, RiseStuds: number, FlightDeviationDegrees: number } } =
		{}
	local islandPolylines: { { { Position: Vector3, HalfWidth: number } } } = {}
	local currentIsland = 0
	local tilesSinceIsland = 0
	local launchToolsSinceIsland = 0
	local landingDeckDue = false
	local lastLaunchSpeed = 0
	local lastLaunchFloat = 0
	-- The worst launch reach this course can produce anywhere, derived from the
	-- launch tools it actually places and the largest drop between any two of its
	-- islands. This is the "maximum measured launch reach" HANDOFF 5.2's separation
	-- rule is written against, so it is computed rather than declared.
	local worstDrop = 0
	local maxLaunchReach = 0
	if archipelago then
		for _, left in archipelago.Islands do
			for _, rightIsland in archipelago.Islands do
				worstDrop = math.min(worstDrop, rightIsland.Y - left.Y)
			end
		end
	end
	if archipelago then
		local islands = archipelago.Islands
		assert(
			#islands >= 5,
			`[CourseBuilder] an Archipelago needs at least five islands, not {#islands} (HANDOFF 5.2)`
		)
		local inward = islands[#islands].Radius < islands[1].Radius
		for index = 2, #islands do
			local previous, island = islands[index - 1], islands[index]
			assert(
				(inward and island.Radius < previous.Radius) or (not inward and island.Radius > previous.Radius),
				string.format(
					"[CourseBuilder] Archipelago island radii must run monotonically from the perimeter to the centre; %s sits at %.2f against %s's %.2f (HANDOFF 5.2)",
					island.Id,
					island.Radius,
					previous.Id,
					previous.Radius
				)
			)
		end
		local outer = if inward then islands[1] else islands[#islands]
		local inner = if inward then islands[#islands] else islands[1]
		assert(
			outer.Radius >= archipelago.PerimeterRadius,
			string.format(
				"[CourseBuilder] the Archipelago's outer island sits at radius %.2f, inside its declared %.2f perimeter",
				outer.Radius,
				archipelago.PerimeterRadius
			)
		)
		assert(
			inner.Radius <= archipelago.CentreRadius,
			string.format(
				"[CourseBuilder] the Archipelago's inner island sits at radius %.2f, outside its declared %.2f centre",
				inner.Radius,
				archipelago.CentreRadius
			)
		)
		for _ in islands do
			table.insert(islandPolylines, {})
		end
	end
	local hairpinEnterLength = 0
	local hairpinExitLength = 0

	local model = Instance.new("Model")
	model.Name = spec.Id
	model:SetAttribute("DisplayName", spec.DisplayName)
	model:SetAttribute("Difficulty", spec.Difficulty)
	model:SetAttribute("ParSeconds", spec.ParSeconds)
	model:SetAttribute("CapSeconds", spec.CapSeconds)
	model:SetAttribute("CloseWindowSeconds", spec.CloseWindowSeconds)
	model:SetAttribute("BuildVersion", 1)

	local origin = Instance.new("Part")
	origin.Name = "Origin"
	origin.Size = Vector3.one
	origin.Anchored = true
	origin.CanCollide = false
	origin.CanTouch = false
	origin.CanQuery = false
	origin.Transparency = 1
	origin.CFrame = CFrame.new(0, 0, 0)
	origin.Parent = model
	model.PrimaryPart = origin

	local function folder(name: string, parent: Instance): Folder
		local created = Instance.new("Folder")
		created.Name = name
		created.Parent = parent
		return created
	end

	local geometry = folder("Geometry", model)
	local beatsFolder = folder("Beats", model)
	local hazards = folder("Hazards", model)
	local startFolder = folder("Start", model)
	local checkpointsFolder = folder("Checkpoints", model)
	local finishFolder = folder("Finish", model)
	local scriptables = folder("Scriptables", model)
	local rotating = folder("Rotating", scriptables)
	local jumpPadsFolder = folder("JumpPads", scriptables)
	local doorsFolder = folder("Doors", scriptables)
	local foamPitsFolder = folder("FoamPits", scriptables)
	local boundaryFolder = folder("Boundary", model)
	local qaGates = folder("Gates", folder("QA", model))

	local cursor = buildStartPads(spec, sources, startFolder, geometry)
	-- The route starts on the guide's first vertex, so the start plaza's exit
	-- offset is already travel along segment 1 (Serpentine) or arclength along
	-- the parametric curve (Spiral).
	local segmentIndex = 1
	-- An Archipelago has no polyline: its first island's own Island piece measures
	-- the walk off the start plaza, so the route's arclength starts at zero and the
	-- plaza-to-shore distance is counted there rather than assumed here.
	local guideStart = if isArchipelago
		then cursor.Position
		elseif curve then (curve :: GuideCurve).Points[1]
		else (assert(layout.Guide, "[CourseBuilder] a Serpentine layout needs Layout.Guide"))[1]
	-- Guide travel is horizontal arclength, so the start plaza's own height above
	-- the guide plane must not count towards it. Ball Barrage starts at Y 0 on a
	-- Y 0 guide and is unaffected; a course that starts elevated (Whirlpool Waltz
	-- starts at 36) would otherwise begin the route tens of studs further along
	-- its own guide than it really is.
	local startDelta = cursor.Position - guideStart
	local segmentTravel = Vector3.new(startDelta.X, 0, startDelta.Z).Magnitude
	local route: { RouteStep } = {}
	local beatMeasures: { BeatMeasure } = {}
	local routeLength = segmentTravel
	local pieceIndex = 0
	local maxGuideDeviation = 0

	local function fail(message: string)
		table.insert(routeErrors, message)
	end

	local function advanceTravel(beatId: string, pieceId: string, distance: number)
		segmentTravel += distance
		routeLength += distance
		-- An Archipelago is bounded by its declared island anchors instead: every
		-- island states where it is in polar coordinates and the route has to arrive
		-- exactly there, which constrains the route far more tightly than a length cap
		-- along a polyline would.
		local cap = if isArchipelago
			then math.huge
			elseif curve then (curve :: GuideCurve).Length
			else segments[segmentIndex].Length
		if segmentTravel > cap + 1e-3 then
			fail(
				string.format(
					"%s/%s: guide %s travel %.2f exceeds its %.2f length",
					beatId,
					pieceId,
					if curve then "curve" else string.format("segment %d", segmentIndex),
					segmentTravel,
					cap
				)
			)
		end
	end

	-- Spiral only. A chained straight slab is a chord of the arc it approximates,
	-- so its exit always sits a little outside the guide. This measures that
	-- offset after every chained piece and fails the build when the run has
	-- wandered further than the declared tolerance, which is what keeps the
	-- spiral a spiral rather than a drifting polygon.
	local function checkGuideDeviation(beatId: string, pieceId: string)
		if not curve then
			return
		end
		local expected = (curve :: GuideCurve).PointAt(segmentTravel)
		local delta = cursor.Position - expected
		local deviation = Vector3.new(delta.X, 0, delta.Z).Magnitude
		maxGuideDeviation = math.max(maxGuideDeviation, deviation)
		if deviation > guideTolerance then
			fail(
				string.format(
					"%s/%s: route sits %.2f studs off the spiral guide at arclength %.2f (tolerance %.2f)",
					beatId,
					pieceId,
					deviation,
					segmentTravel,
					guideTolerance
				)
			)
		end
	end

	-- Spiral only. Re-anchors the cursor onto the guide: X/Z come from the curve
	-- at the current arclength and the heading from its tangent there, while Y
	-- stays whatever the ramps have built. Every heading change on a spiral
	-- happens here -- across a declared gap or a round ride deck -- so chained
	-- slabs stay collinear and no joint opens a wedge seam.
	local function anchorToGuide()
		if not curve then
			return
		end
		local point = (curve :: GuideCurve).PointAt(segmentTravel)
		cursor = {
			Position = Vector3.new(point.X, cursor.Position.Y, point.Z),
			Yaw = (curve :: GuideCurve).YawAt(segmentTravel),
		}
	end

	-- `spine` marks the pieces the route actually travels along. A Mount or a Flank
	-- sits beside the route instead, so it never adds a polyline vertex -- it only
	-- widens the vertex it stands next to, which is what stops a hazard that
	-- overhangs the water from being invisible to the island separation audit.
	local function record(
		beatId: string,
		pieceId: string,
		kind: string,
		arcLength: number,
		halfWidth: number?,
		spine: boolean?
	)
		local island = currentIsland
		local step: RouteStep = {
			BeatId = beatId,
			PieceId = pieceId,
			Kind = kind,
			Position = cursor.Position,
			Yaw = cursor.Yaw,
			Segment = segmentIndex,
			SegmentTravel = segmentTravel,
			ArcLength = arcLength,
			Island = island,
			HalfWidth = halfWidth or 0,
		}
		table.insert(route, step)
		local polyline = if island > 0 then islandPolylines[island] else nil
		if polyline == nil then
			return
		end
		if spine == false then
			local last = polyline[#polyline]
			if last then
				last.HalfWidth = math.max(last.HalfWidth, step.HalfWidth)
			end
			return
		end
		table.insert(polyline, { Position = cursor.Position, HalfWidth = step.HalfWidth })
	end

	for beatIndex, beat in spec.Beats do
		local beatGroup = Instance.new("Model")
		beatGroup.Name = "Assembly"
		local rotatingGroup = folder(string.format("%s__hazards", beat.Id), rotating)
		local groupOrigin = Instance.new("Part")
		groupOrigin.Name = "Origin"
		groupOrigin.Size = Vector3.new(4, 1, 2)
		groupOrigin.Anchored = true
		groupOrigin.CanCollide = false
		groupOrigin.CanTouch = false
		groupOrigin.CanQuery = false
		groupOrigin.Transparency = 1
		groupOrigin.CFrame = CFrame.new(cursor.Position)
		groupOrigin:SetAttribute("RotationSpeed", 0)
		groupOrigin.Parent = rotatingGroup
		beatGroup.Parent = rotatingGroup

		local context: CoursePresets.BuildContext = {
			Sources = sources.Kit,
			Assembly = beatGroup,
			JumpPadsFolder = jumpPadsFolder,
			DoorsFolder = doorsFolder,
			FoamPitsFolder = foamPitsFolder,
			Geometry = geometry,
			CourseId = spec.Id,
			BeatId = beat.Id,
			BeatIndex = beatIndex,
			NextIndex = function()
				pieceIndex += 1
				return pieceIndex
			end,
		}

		if beatIndex > 1 then
			buildCheckpoint(beatIndex - 1, cursor, checkpointsFolder)
		end
		-- QA gate volume at every beat entrance: an invisible, noncolliding but
		-- queryable/touchable plane the cut-set audit uses to prove the route
		-- actually passes through this beat (HANDOFF 3.3 QA/Gates, 8.2).
		-- The gate must catch every legal way INTO the beat, including a runner who
		-- arrives low. A gate reaching only 2 studs below the entrance was measured
		-- being passed underneath on Whirlpool Waltz: a 22-stud jump off the
		-- previous beat's last slab crossed the gate plane at 7 studs below the
		-- entrance and landed past it, and all 30 spawn cells still reached Finish
		-- with the gate removed. It now spans 22 studs below the entrance to 38
		-- above, still only 2 studs thick along the route and 60 wide, which stays
		-- well inside both the serpentine lane pitch and the spiral's radial pitch.
		local gate = marker(
			beat.Id,
			Vector3.new(60, 60, 2),
			CFrame.new(cursor.Position + Vector3.new(0, 8, 0)) * CFrame.Angles(0, math.rad(cursor.Yaw), 0),
			qaGates
		)
		gate.CanTouch = true
		gate.CanQuery = true
		gate:SetAttribute("GateId", beat.Id)
		gate:SetAttribute("QAOnly", true)
		gate:SetAttribute("CourseId", spec.Id)
		gate:SetAttribute("BeatId", beat.Id)

		local beatIndexFolder = folder(beat.Id, beatsFolder)
		local beatStartLength = routeLength
		local beatStartY = cursor.Position.Y

		local function indexPiece(pieceId: string, instance: Instance)
			local value = Instance.new("ObjectValue")
			value.Name = pieceId
			value.Value = instance
			value.Parent = beatIndexFolder
		end

		for _, piece in beat.Pieces do
			-- HANDOFF 5.2: consecutive islands are linked ONLY by the beat's launch or
			-- its tile group. The tiles are therefore not part of either island -- they
			-- are the bridge -- so they are recorded against island 0 and excluded from
			-- the island separation audit.
			local isLinkTile = isArchipelago and piece.Preset == "FallingTile"
			local homeIsland = currentIsland
			if isLinkTile then
				currentIsland = 0
				tilesSinceIsland += 1
			end
			if landingDeckDue and piece.Kind ~= "Ride" then
				fail(
					string.format(
						"%s/%s: an island is entered onto a round landing deck, not a %s piece (HANDOFF 5.2)",
						beat.Id,
						piece.Id,
						piece.Kind
					)
				)
				landingDeckDue = false
			end
			if piece.Preset == "Fan" or piece.Preset == "JumpPad" then
				launchToolsSinceIsland += 1
				lastLaunchSpeed = piece.LaunchSpeed or 48
				lastLaunchFloat = piece.FloatFactor or 0.2
				if archipelago then
					maxLaunchReach = math.max(
						maxLaunchReach,
						launchReach(archipelago :: ArchipelagoSpec, worstDrop, lastLaunchSpeed, lastLaunchFloat)
					)
				end
			end
			if piece.Kind == "Chain" then
				local result = CoursePresets.buildChainPiece(context, piece :: any, cursor)
				cursor = result.ExitCursor
				advanceTravel(beat.Id, piece.Id, result.ArcLength)
				checkGuideDeviation(beat.Id, piece.Id)
				record(
					beat.Id,
					piece.Id,
					piece.Kind,
					result.ArcLength,
					lateralHalfWidth(result.Model, cursor.Position, cursor.Yaw)
				)
				indexPiece(piece.Id, result.Model)
			elseif piece.Kind == "Island" then
				local island = assert(archipelago, `[CourseBuilder] {piece.Id}: Island needs an Archipelago layout`)
				local index = assert(piece.Island, `[CourseBuilder] {piece.Id} needs Island`)
				assert(
					index == currentIsland + 1,
					`[CourseBuilder] {piece.Id}: islands are entered once each in order; expected {currentIsland + 1}, got {index}`
				)
				local declared = assert(island.Islands[index], `[CourseBuilder] {piece.Id}: no island {index} declared`)
				local link = assert(piece.Link, `[CourseBuilder] {piece.Id} needs Link`)
				assert(
					(index == 1) == (link == "Start"),
					`[CourseBuilder] {piece.Id}: only the first island is entered from the start plaza`
				)
				local anchor = islandAnchor(declared)
				local flat = Vector3.new(anchor.X - cursor.Position.X, 0, anchor.Z - cursor.Position.Z)
				local gap = flat.Magnitude
				local rise = anchor.Y - cursor.Position.Y
				local deviation = 0
				if gap > 1 then
					local bearing = normalizeDegrees(headingOf(flat.Unit) - cursor.Yaw)
					deviation = math.abs(if bearing > 180 then bearing - 360 else bearing)
				end
				local walkable = jumpReach(island, rise)
				if link == "Start" then
					if gap > walkable then
						fail(
							string.format(
								"%s/%s: the start plaza is %.2f studs from island %s, past the %.2f-stud ordinary jump for a %.1f-stud rise",
								beat.Id,
								piece.Id,
								gap,
								declared.Id,
								walkable,
								rise
							)
						)
					end
				elseif link == "Launch" then
					local reach = launchReach(island, rise, lastLaunchSpeed, lastLaunchFloat)
					if launchToolsSinceIsland == 0 then
						fail(
							string.format(
								"%s/%s: island %s is declared launch-linked but no fan or pad was placed on the island before it",
								beat.Id,
								piece.Id,
								declared.Id
							)
						)
					end
					if gap <= walkable then
						fail(
							string.format(
								"%s/%s: the %.2f-stud crossing to island %s is inside the %.2f-stud ordinary jump for its %.1f-stud rise, so its launch is decorative (HANDOFF 8.4)",
								beat.Id,
								piece.Id,
								gap,
								declared.Id,
								walkable,
								rise
							)
						)
					end
					if gap > reach then
						fail(
							string.format(
								"%s/%s: the %.2f-stud crossing to island %s is past the %.2f studs a %.1f/%.2f launch reaches over a %.1f-stud rise",
								beat.Id,
								piece.Id,
								gap,
								declared.Id,
								reach,
								lastLaunchSpeed,
								lastLaunchFloat,
								rise
							)
						)
					end
					if deviation > island.MaxFlightDeviationDegrees then
						fail(
							string.format(
								"%s/%s: the flight to island %s leaves %.1f degrees off its own takeoff heading (limit %.1f)",
								beat.Id,
								piece.Id,
								declared.Id,
								deviation,
								island.MaxFlightDeviationDegrees
							)
						)
					end
				else
					if tilesSinceIsland < 2 then
						fail(
							string.format(
								"%s/%s: island %s is declared tile-linked but only %d falling tiles bridge to it",
								beat.Id,
								piece.Id,
								declared.Id,
								tilesSinceIsland
							)
						)
					end
					if gap > 0.1 or math.abs(rise) > 0.1 then
						fail(
							string.format(
								"%s/%s: a tile group lands flush on its island; island %s sits %.3f studs across and %.3f up from the last tile",
								beat.Id,
								piece.Id,
								declared.Id,
								gap,
								rise
							)
						)
					end
				end
				table.insert(islandLinks, {
					Island = index,
					Link = link,
					GapStuds = gap,
					RiseStuds = rise,
					FlightDeviationDegrees = deviation,
				})
				currentIsland = index
				homeIsland = index
				launchToolsSinceIsland = 0
				tilesSinceIsland = 0
				landingDeckDue = index > 1
				cursor = { Position = anchor, Yaw = cursor.Yaw }
				advanceTravel(beat.Id, piece.Id, gap)
				record(beat.Id, piece.Id, piece.Kind, gap, 0)
			elseif piece.Kind == "Ride" then
				assert(
					curve ~= nil or isArchipelago,
					`[CourseBuilder] {piece.Id}: Ride pieces need a Spiral or Archipelago layout`
				)
				local radius = CoursePresets.rideRadius(
					assert(piece.Source, `[CourseBuilder] {piece.Id} needs Source`),
					piece.Scale or 1
				)
				-- Enter at the near rim, centre one radius along, leave at the far
				-- rim: the deck is round, so the heading change across it costs no seam
				-- at all. A Spiral reads the outgoing heading off its parametric guide;
				-- an Archipelago has no guide, so the turn is declared on the piece and
				-- capped at MaxTurnDegrees. The exit cursor is the deck's PHYSICAL rim
				-- in the outgoing direction, so whatever follows chains onto real plate.
				advanceTravel(beat.Id, piece.Id, radius)
				local centre
				if isArchipelago then
					centre = cursor.Position + forward(cursor.Yaw) * radius + Vector3.new(0, piece.OffsetUp or 0, 0)
				else
					anchorToGuide()
					centre = cursor.Position + Vector3.new(0, piece.OffsetUp or 0, 0)
				end
				local entryYaw = cursor.Yaw
				local result = CoursePresets.buildRidePiece(context, piece :: any, centre, entryYaw)
				advanceTravel(beat.Id, piece.Id, radius)
				local exitYaw
				if isArchipelago then
					local turn = piece.TurnDegrees or 0
					local limit = (archipelago :: ArchipelagoSpec).MaxTurnDegrees
					if math.abs(turn) > limit + 1e-6 then
						fail(
							string.format(
								"%s/%s: a %.1f-degree turn across one round deck, past the declared %.1f limit",
								beat.Id,
								piece.Id,
								turn,
								limit
							)
						)
					end
					exitYaw = entryYaw + turn
				else
					exitYaw = (curve :: GuideCurve).YawAt(segmentTravel)
				end
				landingDeckDue = false
				cursor = { Position = centre + forward(exitYaw) * radius, Yaw = exitYaw }
				record(beat.Id, piece.Id, piece.Kind, radius * 2, lateralHalfWidth(result.Model, centre, entryYaw))
				indexPiece(piece.Id, result.Model)
			elseif piece.Kind == "Flank" then
				local flankCursor = {
					Position = cursor.Position
						+ forward(cursor.Yaw) * (piece.OffsetAlong or 0)
						+ right(cursor.Yaw) * (piece.OffsetSide or 0)
						+ Vector3.new(0, piece.OffsetUp or 0, 0),
					Yaw = cursor.Yaw + (piece.FacingOffsetDegrees or 0),
				}
				local result = CoursePresets.buildChainPiece(context, piece :: any, flankCursor)
				record(
					beat.Id,
					piece.Id,
					piece.Kind,
					0,
					lateralHalfWidth(result.Model, cursor.Position, cursor.Yaw),
					false
				)
				indexPiece(piece.Id, result.Model)
			elseif piece.Kind == "Corner" then
				assert(
					not isSpiral and not isArchipelago,
					`[CourseBuilder] {piece.Id}: a {layout.Kind} layout turns on round decks, not on Corner slabs`
				)
				local cornerSource = layout.Corner.Source
				local cornerScale = layout.Corner.Scale
				local direction = assert(piece.Direction, `[CourseBuilder] {piece.Id} corner needs Direction`)
				local along, lateral = CourseBuilder.cornerRun(cornerSource, cornerScale, direction)
				local remaining = segments[segmentIndex].Length - along - segmentTravel
				if remaining < -1e-3 then
					fail(
						string.format(
							"%s/%s: guide segment %d overruns its vertex by %.2f studs",
							beat.Id,
							piece.Id,
							segmentIndex,
							-remaining
						)
					)
					remaining = 0
				end
				-- Tile uniformly scaled slabs so the last straight run reaches the
				-- vertex exactly (HANDOFF 5.1.6). One shared scale per run keeps
				-- every filler slab a uniform scale of the source, never a stretch.
				if remaining > 1e-3 then
					local unit = CoursePresets.travelLength(layout.Fill.Source, layout.Fill.Scale)
					local count = math.max(1, math.ceil(remaining / unit))
					local tileScale = layout.Fill.Scale * remaining / (count * unit)
					for tile = 1, count do
						local fillSpec = {
							Id = string.format("%s_fill%d", piece.Id, tile),
							Preset = "Fill",
							Source = layout.Fill.Source,
							Scale = tileScale,
						}
						local filled = CoursePresets.buildChainPiece(context, fillSpec :: any, cursor)
						cursor = filled.ExitCursor
						advanceTravel(beat.Id, fillSpec.Id, filled.ArcLength)
					end
				end
				-- The last point of the first run: the route has been filled up to the
				-- corner slab's entry and has not yet turned.
				if chute and segmentIndex == 1 then
					hairpinEnterLength = routeLength
				end
				local cornerSpec = {
					Id = piece.Id,
					Preset = "Corner",
					Source = cornerSource,
					Scale = cornerScale,
					Direction = direction,
				}
				local result = CoursePresets.buildCornerPiece(context, cornerSpec :: any, cursor)
				advanceTravel(beat.Id, piece.Id, along)
				if segmentIndex >= #segments then
					fail(string.format("%s/%s: no guide segment after %d", beat.Id, piece.Id, segmentIndex))
				else
					segmentIndex += 1
					local expected = segments[segmentIndex].Heading
					local drift = normalizeDegrees(result.ExitCursor.Yaw - expected)
					if math.min(drift, 360 - drift) > 1e-3 then
						fail(
							string.format(
								"%s/%s: turn leaves heading %.1f but guide segment %d runs %.1f",
								beat.Id,
								piece.Id,
								result.ExitCursor.Yaw,
								segmentIndex,
								expected
							)
						)
					end
					segmentTravel = 0
				end
				cursor = result.ExitCursor
				advanceTravel(beat.Id, piece.Id, lateral)
				-- The first point of the second run, once the hairpin's second turn is
				-- complete.
				if chute and segmentIndex == 3 then
					hairpinExitLength = routeLength
				end
				record(beat.Id, piece.Id, piece.Kind, along + lateral)
				indexPiece(piece.Id, result.Model)
			elseif piece.Kind == "Mount" then
				local targetCFrame = offsetCFrame(cursor, piece, liquidY)
				local result = CoursePresets.buildMountPiece(context, piece :: any, targetCFrame)
				record(
					beat.Id,
					piece.Id,
					piece.Kind,
					0,
					lateralHalfWidth(result.Model, cursor.Position, cursor.Yaw),
					false
				)
				indexPiece(piece.Id, result.Model)
			else
				local before = cursor.Position
				local advanced = offsetCFrame(cursor, piece, liquidY)
				cursor = { Position = advanced.Position, Yaw = cursor.Yaw + (piece.FacingOffsetDegrees or 0) }
				local distance = piece.OffsetAlong or 0
				advanceTravel(beat.Id, piece.Id, distance)
				if isSpiral then
					-- On a spiral an Advance is where the route re-anchors: the
					-- declared distance is arclength along the guide, and the
					-- runner's actual gap is the straight line between the two
					-- anchored points, which is what gets measured and reported.
					cursor = { Position = Vector3.new(before.X, cursor.Position.Y, before.Z), Yaw = cursor.Yaw }
					anchorToGuide()
					local gap = cursor.Position - before
					local measuredGap = Vector3.new(gap.X, 0, gap.Z).Magnitude
					if measuredGap > 19.8 then
						fail(
							string.format(
								"%s/%s: the spiral gap measures %.2f studs, past the 19.8 ordinary-jump ceiling (HANDOFF 8.3)",
								beat.Id,
								piece.Id,
								measuredGap
							)
						)
					end
				end
				record(beat.Id, piece.Id, piece.Kind, distance)
			end
			currentIsland = homeIsland
		end

		-- HANDOFF 3.3: "Origin.ServerCarries=true for RotorCarries or Seesaw
		-- rides", which also disables the old client carry solver for the group.
		-- It is set only on beats that actually carry a rider, so a beat of pure
		-- shove hazards keeps exactly the attributes it had.
		for _, descendant in beatGroup:GetDescendants() do
			if descendant:GetAttribute("RotorCarries") == true or descendant:GetAttribute("Seesaw") == true then
				groupOrigin:SetAttribute("ServerCarries", true)
				break
			end
		end

		local measured = routeLength - beatStartLength
		local ratio = measured / beat.LengthTarget
		if ratio < 0.85 or ratio > 1.15 then
			fail(
				string.format(
					"%s: measured arclength %.2f is %.3f of its %d target (HANDOFF 5.2 allows 0.85-1.15)",
					beat.Id,
					measured,
					ratio,
					beat.LengthTarget
				)
			)
		end
		table.insert(beatMeasures, {
			Id = beat.Id,
			ArcLength = measured,
			LengthTarget = beat.LengthTarget,
			Ratio = ratio,
			ElevationChange = cursor.Position.Y - beatStartY,
		})
	end

	buildFinish(sources, spec.Id, cursor, finishFolder, geometry)
	buildHazardLiquid(layout.BoundsRadius, liquidY, hazards)
	buildBoundary(390, 24, liquidY, sources.BoundaryWall, boundaryFolder)

	local checkpointCount = #checkpointsFolder:GetChildren()
	model:SetAttribute("CheckpointCount", checkpointCount)

	local hairpinFraction = if chute and routeLength > 0 then hairpinEnterLength / routeLength else 0
	local hairpinExitFraction = if chute and routeLength > 0 then hairpinExitLength / routeLength else 0
	-- "The hairpin sits at roughly 55-60% of the route" is measured at the turn
	-- itself -- the middle of the cross run, where the route actually reverses --
	-- because the hairpin is a lane pitch long and its entry and exit fractions
	-- straddle that point by design.
	local hairpinMidFraction = (hairpinFraction + hairpinExitFraction) / 2
	if chute then
		if hairpinEnterLength <= 0 or hairpinExitLength <= 0 then
			fail("a Chute needs both hairpin corners on its route; the guide was never turned twice")
		elseif hairpinMidFraction < chute.HairpinFractionMin or hairpinMidFraction > chute.HairpinFractionMax then
			fail(
				string.format(
					"the hairpin turns at %.1f%% of the route (entering at %.1f%%, rejoining at %.1f%%), outside the declared %.1f-%.1f%% window (HANDOFF 5.2)",
					hairpinMidFraction * 100,
					hairpinFraction * 100,
					hairpinExitFraction * 100,
					chute.HairpinFractionMin * 100,
					chute.HairpinFractionMax * 100
				)
			)
		end
	end

	local loopClosure = 0
	if loop then
		local closure = cursor.Position - spec.Start.Position
		loopClosure = Vector3.new(closure.X, 0, closure.Z).Magnitude
		if loopClosure < loop.ClosureMinStuds or loopClosure > loop.ClosureMaxStuds then
			fail(
				string.format(
					"the circuit closes %.2f studs from its start plaza, outside the declared %.1f-%.1f window (HANDOFF 5.2: start and finish sit near each other on the outside of the loop)",
					loopClosure,
					loop.ClosureMinStuds,
					loop.ClosureMaxStuds
				)
			)
		end
		local tunnelSegments: { [string]: number } = {}
		for _, step in route do
			if step.PieceId == loop.OutboundTunnelPieceId or step.PieceId == loop.ReturnTunnelPieceId then
				tunnelSegments[step.PieceId] = step.Segment
			end
		end
		for expectedSegment, pieceId in { [1] = loop.OutboundTunnelPieceId, [3] = loop.ReturnTunnelPieceId } do
			local placed = tunnelSegments[pieceId]
			if placed == nil then
				fail(string.format("the spine tunnel piece %s is not on the route", pieceId))
			elseif placed ~= expectedSegment then
				fail(
					string.format(
						"the spine tunnel %s sits on guide run %d; the route must cross the spine once on run 1 and once on run 3",
						pieceId,
						placed
					)
				)
			end
		end
	end

	local worstIslandSeparation = 0
	local worstIslandSeparationPair = ""
	if archipelago then
		local islands = archipelago.Islands
		if #islandLinks ~= #islands then
			fail(string.format("%d of the %d declared islands are entered by the route", #islandLinks, #islands))
		end
		-- HANDOFF 5.2's separation rule, measured rather than declared: the closest
		-- approach between the ROUTE on two non-consecutive islands, reduced by the
		-- measured lateral half-width of the pieces at that approach, must beat the
		-- launch reach. Tile groups are excluded because they are the links
		-- themselves; the sampled cut-set graph is what proves nothing can be
		-- launched off one of them.
		worstIslandSeparation = math.huge
		for left = 1, #islandPolylines do
			for rightIndex = left + 2, #islandPolylines do
				local a, b = islandPolylines[left], islandPolylines[rightIndex]
				if #a == 0 or #b == 0 then
					continue
				end
				local closest = math.huge
				for i = 1, math.max(#a - 1, 1) do
					local a1 = a[i]
					local a2 = a[math.min(i + 1, #a)]
					for j = 1, math.max(#b - 1, 1) do
						local b1 = b[j]
						local b2 = b[math.min(j + 1, #b)]
						local clear = segmentDistance(a1.Position, a2.Position, b1.Position, b2.Position)
							- math.max(a1.HalfWidth, a2.HalfWidth)
							- math.max(b1.HalfWidth, b2.HalfWidth)
						closest = math.min(closest, clear)
					end
				end
				if closest < worstIslandSeparation then
					worstIslandSeparation = closest
					worstIslandSeparationPair = string.format("%s/%s", islands[left].Id, islands[rightIndex].Id)
				end
				if closest <= maxLaunchReach then
					fail(
						string.format(
							"islands %s and %s are not consecutive but come within %.2f studs of each other, inside the %.2f-stud worst launch reach this course can produce (HANDOFF 5.2)",
							islands[left].Id,
							islands[rightIndex].Id,
							closest,
							maxLaunchReach
						)
					)
				end
			end
		end
		if worstIslandSeparation == math.huge then
			worstIslandSeparation = 0
		end
	end

	if routeLength < 800 or routeLength > 1000 then
		fail(
			string.format(
				"route arclength %.2f is outside the 800-1000 stud window (HANDOFF 3.2 override 4)",
				routeLength
			)
		)
	end

	local bounds = auditBounds(model, geometry, { boundaryFolder, hazards }, route, layout.BoundsRadius)

	local attributeErrors = AttributeAudit.check(scriptables, METADATA_ALLOWLIST)
	for _, message in AttributeAudit.check(geometry, METADATA_ALLOWLIST) do
		table.insert(attributeErrors, message)
	end
	local specHash = computeSpecHash(model)
	model:SetAttribute("SpecHash", specHash)

	local report: BuildReport = {
		Ok = #attributeErrors == 0 and #routeErrors == 0 and #bounds.Violations == 0,
		Id = spec.Id,
		PartCount = countParts(model),
		BuildSeconds = os.clock() - startClock,
		AttributeErrors = attributeErrors,
		RouteErrors = routeErrors,
		SpecHash = specHash,
		RouteLength = routeLength,
		Beats = beatMeasures,
		Route = route,
		Bounds = bounds,
		CheckpointCount = checkpointCount,
		GuideDeviation = maxGuideDeviation,
		GuideLength = if curve then (curve :: GuideCurve).Length else 0,
		HairpinFraction = hairpinFraction,
		HairpinMidFraction = hairpinMidFraction,
		HairpinExitFraction = hairpinExitFraction,
		LoopClosureStuds = loopClosure,
		LoopTotalTurnDegrees = loopTotalTurn,
		IslandLinks = islandLinks,
		WorstIslandSeparation = worstIslandSeparation,
		WorstIslandSeparationPair = worstIslandSeparationPair,
		MaxLaunchReach = maxLaunchReach,
	}
	return model, report
end

-- Arclength a corner slab consumes before and after its vertex: the component of
-- (side socket - entry socket) along the slab's own travel axis, then across it.
function CourseBuilder.cornerRun(sourceId: string, scale: number, direction: "Left" | "Right"): (number, number)
	local manifest = AssetManifest.get(sourceId)
	local entry = assert(manifest.Sockets.Entry, `[CourseBuilder] corner source {sourceId} has no Entry socket`)
	local side = if direction == "Left" then manifest.Sockets.SidePositiveX else manifest.Sockets.SideNegativeX
	assert(side, `[CourseBuilder] corner source {sourceId} has no side socket for a {direction} turn`)
	local delta = side.Position - entry.Position
	if manifest.ForwardAxis == "X" then
		return math.abs(delta.X) * scale, math.abs(delta.Z) * scale
	end
	return math.abs(delta.Z) * scale, math.abs(delta.X) * scale
end

return CourseBuilder
