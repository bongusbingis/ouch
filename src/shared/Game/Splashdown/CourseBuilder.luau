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
	Kind: "Chain" | "Corner" | "Mount" | "Advance",
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

export type LayoutSpec = {
	Kind: string,
	LanePitch: number,
	BoundsRadius: number,
	LiquidY: number,
	-- HANDOFF 5.2 guide polyline in local X/Z. The route never leaves it: every
	-- straight run is capped by its segment length and every turn happens at a
	-- vertex, which is what bounds the course rather than trusting the spec.
	Guide: { Vector3 },
	Corner: { Source: string, Scale: number },
	Fill: { Source: string, Scale: number },
}

export type CourseSpec = {
	Version: number,
	Id: string,
	DisplayName: string,
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
	return CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
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

function CourseBuilder.build(spec: CourseSpec, sources: Sources): (Model, BuildReport)
	local startClock = os.clock()
	local layout = spec.Layout
	local liquidY = layout.LiquidY
	local segments = buildSegments(layout.Guide)
	local routeErrors: { string } = {}

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
	folder("Doors", scriptables)
	local boundaryFolder = folder("Boundary", model)
	local qaGates = folder("Gates", folder("QA", model))

	local cursor = buildStartPads(spec, sources, startFolder, geometry)
	-- The route starts on the guide's first vertex, so the start plaza's exit
	-- offset is already travel along segment 1.
	local segmentIndex = 1
	local segmentTravel = (cursor.Position - layout.Guide[1]).Magnitude
	local route: { RouteStep } = {}
	local beatMeasures: { BeatMeasure } = {}
	local routeLength = segmentTravel
	local pieceIndex = 0

	local function fail(message: string)
		table.insert(routeErrors, message)
	end

	local function advanceTravel(beatId: string, pieceId: string, distance: number)
		segmentTravel += distance
		routeLength += distance
		local cap = segments[segmentIndex].Length
		if segmentTravel > cap + 1e-3 then
			fail(
				string.format(
					"%s/%s: guide segment %d travel %.2f exceeds its %.2f length",
					beatId,
					pieceId,
					segmentIndex,
					segmentTravel,
					cap
				)
			)
		end
	end

	local function record(beatId: string, pieceId: string, kind: string, arcLength: number)
		table.insert(route, {
			BeatId = beatId,
			PieceId = pieceId,
			Kind = kind,
			Position = cursor.Position,
			Yaw = cursor.Yaw,
			Segment = segmentIndex,
			SegmentTravel = segmentTravel,
			ArcLength = arcLength,
		})
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
		local gate = marker(
			beat.Id,
			Vector3.new(60, 40, 2),
			CFrame.new(cursor.Position + Vector3.new(0, 18, 0)) * CFrame.Angles(0, math.rad(cursor.Yaw), 0),
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
			if piece.Kind == "Chain" then
				local result = CoursePresets.buildChainPiece(context, piece :: any, cursor)
				cursor = result.ExitCursor
				advanceTravel(beat.Id, piece.Id, result.ArcLength)
				record(beat.Id, piece.Id, piece.Kind, result.ArcLength)
				indexPiece(piece.Id, result.Model)
			elseif piece.Kind == "Corner" then
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
				record(beat.Id, piece.Id, piece.Kind, along + lateral)
				indexPiece(piece.Id, result.Model)
			elseif piece.Kind == "Mount" then
				local targetCFrame = offsetCFrame(cursor, piece, liquidY)
				local result = CoursePresets.buildMountPiece(context, piece :: any, targetCFrame)
				record(beat.Id, piece.Id, piece.Kind, 0)
				indexPiece(piece.Id, result.Model)
			else
				local advanced = offsetCFrame(cursor, piece, liquidY)
				cursor = { Position = advanced.Position, Yaw = cursor.Yaw + (piece.FacingOffsetDegrees or 0) }
				local distance = piece.OffsetAlong or 0
				advanceTravel(beat.Id, piece.Id, distance)
				record(beat.Id, piece.Id, piece.Kind, distance)
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
