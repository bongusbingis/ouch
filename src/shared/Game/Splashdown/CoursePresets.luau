-- Name: CoursePresets.luau
-- Author: Jack C.
-- Description: Builds one course piece from an AssetManifest source: clones it into a scale/pivot-normalized holder exactly as HANDOFF 5.1 requires, applies the fixed section-6 kit attributes for its preset, and places it by chaining its Entry socket onto the running route cursor, turning the route across a corner slab's measured side socket, or mounting its Support socket at an explicit offset. CourseBuilder owns beat sequencing and the layout guide; this module only knows how to construct, name, attribute and place one piece at a time.
-- Created: 2026-09-15

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetManifest = require(script.Parent.AssetManifest)
local MapFeatures = require(ReplicatedStorage.Config.Gameplay.MapFeatures)
local A = MapFeatures.Attributes

local CoursePresets = {}

export type PresetName =
	"Conveyor"
	| "Platform"
	| "Ramp"
	| "Slide"
	| "Corner"
	| "Fill"
	| "Bumper"
	| "BigBall"
	| "Sweeper"
	| "Piston"
	| "Hammer"
	| "Fan"
	| "JumpPad"

export type PieceSpec = {
	Id: string,
	Preset: PresetName,
	Source: string?,
	Scale: number,
	-- Chains the piece against its own travel direction: Entry and Exit swap and
	-- the forward heading turns 180 degrees. The kit has no ascending ramp mesh,
	-- so every climb in HANDOFF section 7 is a measured descending ramp entered
	-- from its low end. Purely a socket relabel: no mirrored or stretched mesh.
	Reversed: boolean?,
	Direction: ("Left" | "Right")?,
	ConveyorSpeed: number?,
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

export type BuildContext = {
	Sources: Instance,
	Assembly: Instance,
	JumpPadsFolder: Instance,
	Geometry: Instance,
	CourseId: string,
	BeatId: string,
	BeatIndex: number,
	NextIndex: () -> number,
}

export type Cursor = { Position: Vector3, Yaw: number }

export type ChainResult = {
	Model: Model,
	ExitCursor: Cursor,
	PartCount: number,
	ArcLength: number,
}

export type MountResult = {
	Model: Model,
	PartCount: number,
}

local function findSource(context: BuildContext, id: string): Instance
	local found = context.Sources:FindFirstChild(id)
	assert(found ~= nil, `[CoursePresets] source "{id}" not found under injected Sources root`)
	return found :: Instance
end

-- HANDOFF 3.3: sd_<CourseId>_<NN>_<role>_<index>. Original obstacle_/platform_
-- names never survive into a course; the source id lives on as the SourceAsset
-- attribute instead, which is what the audit and the QA crosswalk read.
local function pieceName(context: BuildContext, role: string): string
	return string.format("sd_%s_%02d_%s_%d", context.CourseId, context.BeatIndex, role:lower(), context.NextIndex())
end

-- Clones id (and any AssetManifest SubParts) into a fresh holder Model, scales
-- the whole holder, clears every descendant's imported PivotOffset, and applies
-- the collision/ownership flags every course piece needs (HANDOFF 5.1 step 2).
-- Returns the clones keyed by their source child path so callers address them by
-- source identity rather than by the renamed instance.
local function clonePiece(
	context: BuildContext,
	spec: PieceSpec,
	id: string,
	role: string
): (Model, BasePart, AssetManifest.AssetEntry, { [string]: BasePart })
	local manifest = AssetManifest.get(id)
	local source = findSource(context, id)
	assert(source:IsA("BasePart"), `[CoursePresets] source "{id}" is not a BasePart`)

	local name = pieceName(context, role)
	local holder = Instance.new("Model")
	holder.Name = name
	local root = (source :: BasePart):Clone()
	root.Name = name
	root.Parent = holder

	local byPath: { [string]: BasePart } = { [id] = root }
	if manifest.SubParts then
		for index, sub in manifest.SubParts do
			local subSource = source
			for segment in sub.Name:gmatch("[^.]+") do
				subSource = subSource:FindFirstChild(segment) :: Instance
				assert(subSource ~= nil, `[CoursePresets] sub-part "{sub.Name}" missing from source "{id}"`)
			end
			assert(subSource:IsA("BasePart"), `[CoursePresets] sub-part "{sub.Name}" is not a BasePart`)
			local clone = (subSource :: BasePart):Clone()
			clone.Name = string.format("%s_%d", name, index)
			clone.Parent = root
			byPath[sub.Name] = clone
		end
	end

	holder:ScaleTo(spec.Scale)

	holder:SetAttribute("CourseId", context.CourseId)
	holder:SetAttribute("BeatId", context.BeatId)
	holder:SetAttribute("PieceId", spec.Id)
	for _, descendant in holder:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
			descendant.CanTouch = false
			descendant.CanQuery = true
			descendant.Massless = false
			descendant.PivotOffset = CFrame.identity
			descendant:SetAttribute("SourceAsset", id)
			descendant:SetAttribute("CourseId", context.CourseId)
			descendant:SetAttribute("BeatId", context.BeatId)
			descendant:SetAttribute("PieceId", spec.Id)
		end
	end

	return holder, root, manifest, byPath
end

-- Rigidly repositions the whole holder so `rootLike`'s own CFrame ends up at
-- `targetCFrame`, without disturbing any other descendant's relative pose.
local function placeByPart(holder: Model, rootLike: BasePart, targetCFrame: CFrame)
	holder.WorldPivot = rootLike.CFrame
	holder:PivotTo(targetCFrame)
end

local function partCount(holder: Model): number
	local count = 0
	for _, descendant in holder:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

-- Entry/Exit/forward heading for a chained piece, honouring Reversed.
local function travelSockets(
	manifest: AssetManifest.AssetEntry,
	sourceId: string,
	spec: PieceSpec
): (Vector3, Vector3, number)
	local entry = assert(manifest.Sockets.Entry, `[CoursePresets] {sourceId} has no Entry socket`)
	local exit = assert(manifest.Sockets.Exit, `[CoursePresets] {sourceId} has no Exit socket`)
	local heading = assert(manifest.ForwardHeadingDegrees, `[CoursePresets] {sourceId} has no ForwardHeadingDegrees`)
	if spec.Reversed then
		return exit.Position * spec.Scale, entry.Position * spec.Scale, heading + 180
	end
	return entry.Position * spec.Scale, exit.Position * spec.Scale, heading
end

-- Placement solves `rootTarget = CFrame.new(P) * R * CFrame.new(-X)`, the
-- standard "put local point X at world point P with rotation R" identity
-- (verified: rootTarget:PointToWorldSpace(X) == P for any R). R is built from
-- a single scalar yaw rather than the socket's own local axis, which sidesteps
-- Roblox's "-Z is forward" convention entirely: R = CFrame.Angles(0, rad(cursor.Yaw
-- - forwardHeading), 0) is exactly the rotation that turns the piece's own
-- measured Entry->Exit heading into the cursor's current heading.
local function placeTravelPiece(
	context: BuildContext,
	spec: PieceSpec,
	cursor: Cursor,
	role: string
): (Model, BasePart, AssetManifest.AssetEntry, { [string]: BasePart }, Vector3)
	local sourceId = assert(spec.Source, `[CoursePresets] {spec.Id} needs Source`)
	local holder, root, manifest, byPath = clonePiece(context, spec, sourceId, role)
	local entryLocal, exitLocal, heading = travelSockets(manifest, sourceId, spec)
	local rotation = CFrame.Angles(0, math.rad(cursor.Yaw - heading), 0)
	placeByPart(holder, root, CFrame.new(cursor.Position) * rotation * CFrame.new(-entryLocal))
	return holder, root, manifest, byPath, exitLocal
end

-- Route pieces (Conveyor / Platform / Ramp / Slide / Fill): chained by Entry socket.
local function buildChainPiece(context: BuildContext, spec: PieceSpec, cursor: Cursor): ChainResult
	local holder, root, _, _, exitLocal = placeTravelPiece(context, spec, cursor, spec.Preset)
	local exitWorldPosition = root.CFrame:PointToWorldSpace(exitLocal)

	if spec.Preset == "Conveyor" then
		root:SetAttribute(A.Conveyor, true)
		root:SetAttribute(A.ConveyorSpeed, assert(spec.ConveyorSpeed, "[CoursePresets] Conveyor needs ConveyorSpeed"))
		root:SetAttribute(A.ConveyorAxis, "Z")
		holder.Parent = context.Assembly
	else
		-- Platform / Ramp / Slide / Fill / Corner carry no attributes: plain static
		-- floor lives in Geometry, outside the CollectionService-tagged Scriptables tree.
		holder.Parent = context.Geometry
	end

	local delta = exitWorldPosition - cursor.Position
	return {
		Model = holder,
		ExitCursor = { Position = exitWorldPosition, Yaw = cursor.Yaw },
		PartCount = partCount(holder),
		ArcLength = Vector3.new(delta.X, 0, delta.Z).Magnitude,
	}
end

-- Corner slab: entered at Entry like any chained piece, left through the measured
-- side socket on the inside of the turn, so one continuous walkable top carries
-- the route through 90 degrees without a seam or an invented arc asset
-- (arc_004 was measured and rejected; see course-sockets-ballbarrage.json).
local function buildCornerPiece(context: BuildContext, spec: PieceSpec, cursor: Cursor): ChainResult
	local direction = assert(spec.Direction, `[CoursePresets] {spec.Id} corner needs Direction`)
	local holder, root, manifest, _ = placeTravelPiece(context, spec, cursor, "corner")
	local sideSocket = if direction == "Left" then manifest.Sockets.SidePositiveX else manifest.Sockets.SideNegativeX
	assert(sideSocket, `[CoursePresets] {spec.Source} has no side socket for a {direction} corner`)
	local exitWorldPosition = root.CFrame:PointToWorldSpace(sideSocket.Position * spec.Scale)
	holder.Parent = context.Geometry

	local delta = exitWorldPosition - cursor.Position
	return {
		Model = holder,
		ExitCursor = {
			Position = exitWorldPosition,
			Yaw = cursor.Yaw + (if direction == "Left" then 90 else -90),
		},
		PartCount = partCount(holder),
		ArcLength = Vector3.new(delta.X, 0, delta.Z).Magnitude,
	}
end

-- Mounted hazards (Bumper / BigBall / Sweeper / Piston / Hammer / Fan / JumpPad):
-- `targetCFrame` is the caller-chosen world pose (position AND facing) the
-- Support socket should land at; the piece takes on that rotation directly.
local function buildMountPiece(context: BuildContext, spec: PieceSpec, targetCFrame: CFrame): MountResult
	local sourceId = assert(spec.Source, `[CoursePresets] {spec.Id} needs Source`)
	local holder, root, manifest, byPath = clonePiece(context, spec, sourceId, spec.Preset)
	local supportLocal = manifest.Sockets.Support.Position * spec.Scale
	placeByPart(holder, root, targetCFrame * CFrame.new(-supportLocal))

	local function sub(path: string): BasePart
		local found = byPath[path]
		assert(found ~= nil, `[CoursePresets] {spec.Id} missing cloned sub-part {path}`)
		return found
	end

	if spec.Preset == "Bumper" then
		root:SetAttribute(A.Bumper, true)
		root:SetAttribute(A.ShoveSpeed, spec.ShoveSpeed or 54)
		root:SetAttribute(A.ShoveUpwardSpeed, 22)
		root:SetAttribute(A.ShoveSeconds, 0.26)
		root:SetAttribute(A.ShoveContact, "mesh")
		root:SetAttribute(A.RetriggerCooldown, 0.8)
		root:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "BigBall" then
		local sphere = sub("obstacle_23_002")
		sphere:SetAttribute(A.BigBall, true)
		sphere:SetAttribute(A.CapDegrees, 40)
		sphere:SetAttribute(A.BounceSpeed, 58)
		sphere:SetAttribute(A.FloatFactor, 0.25)
		sphere:SetAttribute(A.RollOffSpeed, 38)
		if spec.RotorAmplitude then
			root:SetAttribute(A.Rotor, "rock")
			root:SetAttribute(A.RotorAxis, "Z")
			root:SetAttribute(A.RotorAmplitude, spec.RotorAmplitude)
			root:SetAttribute(A.RotorPeriod, spec.RotorPeriod)
			root:SetAttribute(A.RotorPhase, spec.RotorPhase or 0)
		end
	elseif spec.Preset == "Sweeper" then
		root:SetAttribute(A.Rotor, "slide")
		root:SetAttribute(A.RotorAxis, "X")
		root:SetAttribute(A.RotorAmplitude, 4)
		root:SetAttribute(A.RotorPeriod, 3.2)
		root:SetAttribute(A.RotorPhase, spec.RotorPhase or 0)
		local drum = sub("obstacle_2_002")
		drum:SetAttribute(A.Rotor, "spin")
		drum:SetAttribute(A.RotorAxis, "X")
		local radius = 6.13 * spec.Scale
		local degreesPerSecond = math.ceil((33.8 * 180 / (math.pi * radius)) / 5) * 5
		drum:SetAttribute(A.RotorSpeed, degreesPerSecond)
		drum:SetAttribute(A.Shove, true)
		drum:SetAttribute(A.ShoveSpeed, 48)
		drum:SetAttribute(A.ShoveUpwardSpeed, 20)
		drum:SetAttribute(A.ShoveSeconds, 0.24)
		drum:SetAttribute(A.ShoveContact, "mesh")
		drum:SetAttribute(A.ImpactVisual, true)
		drum:SetAttribute(A.RetriggerCooldown, 0.8)
		drum:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "Piston" then
		local spring = sub("obstacle_22_002")
		spring:SetAttribute(A.Rotor, "slide")
		spring:SetAttribute(A.RotorProfile, "piston")
		spring:SetAttribute(A.RotorAxis, "Z")
		spring:SetAttribute(A.PistonPeriod, 3.2)
		spring:SetAttribute(A.PistonPhase, spec.RotorPhase or 0)
		spring:SetAttribute(A.PistonExtendStuds, 6)
		spring:SetAttribute(A.HoldSeconds, 0.6)
		spring:SetAttribute(A.Shove, true)
		spring:SetAttribute(A.ShoveSpeed, 44)
		spring:SetAttribute(A.ShoveUpwardSpeed, 20)
		spring:SetAttribute(A.ShoveSeconds, 0.24)
		spring:SetAttribute(A.ShoveContact, "mesh")
		spring:SetAttribute(A.ImpactVisual, true)
		spring:SetAttribute(A.RetriggerCooldown, 0.8)
		spring:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "Hammer" then
		local head = sub(if sourceId == "obstacle_3_001" then "obstacle_3_002" else "obstacle_4_002")
		head:SetAttribute(A.Rotor, "rock")
		head:SetAttribute(A.RotorProfile, "hammer")
		head:SetAttribute(A.RotorAxis, "Z")
		head:SetAttribute(A.RotorAmplitude, spec.RotorAmplitude or 55)
		head:SetAttribute(A.WindupSeconds, 1.8)
		head:SetAttribute(A.StrikeSeconds, 0.3)
		head:SetAttribute(A.RotorPhase, spec.RotorPhase or 0)
		head:SetAttribute(A.Shove, true)
		head:SetAttribute(A.ShoveSpeed, 58)
		head:SetAttribute(A.ShoveUpwardSpeed, 20)
		head:SetAttribute(A.ShoveSeconds, 0.24)
		head:SetAttribute(A.ShoveContact, "mesh")
		head:SetAttribute(A.ImpactVisual, true)
		head:SetAttribute(A.RetriggerCooldown, 0.8)
		head:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "Fan" then
		root:SetAttribute(A.Fan, true)
		root:SetAttribute(A.FanAxis, spec.FanAxis or "Y")
		root:SetAttribute(A.FanDirection, spec.FanDirection or 1)
		root:SetAttribute(A.FanColumnHeight, spec.FanColumnHeight or 18)
		root:SetAttribute(A.LaunchSpeed, spec.LaunchSpeed or 48)
		root:SetAttribute(A.FloatFactor, spec.FloatFactor or 0.2)
		sub("propeller_trampoline_2_001"):SetAttribute(A.FanBlade, true)
	elseif spec.Preset == "JumpPad" then
		-- Outer/Inner are required by the runtime pad contract (HANDOFF 3.3
		-- Scriptables/JumpPads/<model>/Outer, Inner), so they keep those names
		-- while the holder carries the sd_ course name.
		root.Name = "Outer"
		sub("trampoline_1_002").Name = "Inner"
		holder:SetAttribute(A.JumpPad, true)
		holder:SetAttribute(A.LaunchSpeed, spec.LaunchSpeed or 51)
		holder:SetAttribute(A.FloatFactor, spec.FloatFactor or 0.2)
	end

	holder.Parent = if spec.Preset == "JumpPad" then context.JumpPadsFolder else context.Assembly
	return { Model = holder, PartCount = partCount(holder) }
end

function CoursePresets.buildChainPiece(context: BuildContext, spec: PieceSpec, cursor: Cursor): ChainResult
	return buildChainPiece(context, spec, cursor)
end

function CoursePresets.buildCornerPiece(context: BuildContext, spec: PieceSpec, cursor: Cursor): ChainResult
	return buildCornerPiece(context, spec, cursor)
end

function CoursePresets.buildMountPiece(context: BuildContext, spec: PieceSpec, targetCFrame: CFrame): MountResult
	return buildMountPiece(context, spec, targetCFrame)
end

-- Straight travel length one chained instance of `sourceId` covers at `scale`,
-- measured between its own Entry and Exit sockets. CourseBuilder uses this to
-- size filler runs before it places anything.
function CoursePresets.travelLength(sourceId: string, scale: number, reversed: boolean?): number
	local manifest = AssetManifest.get(sourceId)
	local entry, exit =
		travelSockets(manifest, sourceId, { Id = sourceId, Preset = "Platform", Scale = scale, Reversed = reversed })
	local delta = exit - entry
	return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

return CoursePresets
