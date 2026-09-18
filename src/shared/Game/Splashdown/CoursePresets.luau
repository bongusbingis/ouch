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
	-- Whirlpool Waltz additions. Spinner covers every single-mesh Y-spin shove
	-- silhouette (dumbbell, cross, two-arm); RidePlatform is a hub-and-plate
	-- rotating deck the route crosses; SwingPanel is obstacle_8's rocking panel
	-- (NOT obstacle_24, the paddlewheel); Door is one slab of a door row.
	| "Spinner"
	| "RidePlatform"
	| "SwingPanel"
	| "Door"
	-- Door Dash additions. Mace is the hanging chain-and-ball pendulum whose top
	-- link is the axle; PaddleWheel is obstacle_24's four-cradle wheel spinning on
	-- its measured X axle (NOT obstacle_8, the swing panel).
	| "Mace"
	| "PaddleWheel"
	-- Tumble Tunnels additions. BeachBall is a real physics ball the runtime kit
	-- unanchors and takes server ownership of; Seesaw is obstacle_25's rider-weighted
	-- board, which is a CHAINED surface because the board is the route's own floor
	-- for its whole length; Mallet is obstacle_1's single-mesh hammer, rocking about
	-- the measured base of its post rather than floating like a Bumper.
	| "BeachBall"
	| "Seesaw"
	| "Mallet"
	-- A mounted piece of visible stock geometry with no kit attributes at all:
	-- arch frames around a landing mouth, enclosure. It lives in Geometry like
	-- any other static piece and is never an encounter.
	| "Prop"
	-- Piston Peak addition. A log-roll turns about its own measured long axis and
	-- both carries and shoves (section 6: "Log-roll ... Spin along long axis + Shove
	-- + Carries on actual ride surface; not an unanchored physics barrel"). Section 6
	-- allows either of the kit's rolling shapes, so the preset drives whichever the
	-- manifest declares: a framed roller turns only its declared drum and holds the
	-- cradle fixed (unlike the Sweeper, whose frame slides), and a single-mesh barrel
	-- turns on its own root.
	| "LogRoll"
	-- A static round deck placed by the Ride kind. It carries no attributes and
	-- does not turn; it exists because a round platform has no preferred heading,
	-- so a spiral can change direction across one without the wedge seam two
	-- straight slabs meeting at an angle would open.
	| "RoundLanding"
	-- Tiptoe Trials addition. FallingTile is one rainbow tile of a tile group: a
	-- CHAINED surface, because the tile IS the route's floor for its own length,
	-- and the group between two stable landings is the encounter. It always ships
	-- with CriticalRoute and a positive RespawnSeconds (section 7.5 / HANDOFF 13:
	-- "No permanent critical falling tiles").
	| "FallingTile"

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
	-- Piston only: the spring's extend distance (studs), its extend/retract cycle
	-- period, and how long it holds fully extended before retracting. B4: the old
	-- hardcoded 6/3.2/0.6 could not reach some lanes' decks; declared here so a
	-- course can tune a specific piston the same way Sweeper tunes RotorAmplitude.
	PistonExtendStuds: number?,
	PistonPeriod: number?,
	HoldSeconds: number?,
	LaunchSpeed: number?,
	FloatFactor: number?,
	FanAxis: ("X" | "Y" | "Z")?,
	FanDirection: number?,
	FanColumnHeight: number?,
	RotorSpeed: number?,
	-- LogRoll only: which of the barrel's own local axes is its long axis. The kit's
	-- two rolling shapes differ, so it is declared rather than guessed.
	RotorAxis: ("X" | "Y" | "Z")?,
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
}

export type BuildContext = {
	Sources: Instance,
	Assembly: Instance,
	JumpPadsFolder: Instance,
	DoorsFolder: Instance,
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
		-- Cloning the root brings its WHOLE source subtree with it, so a declared
		-- sub-part is normally already present inside the clone: the piston's spring
		-- and head are nested under its base, and the mace's nine links and ball
		-- chain one inside the next. Resolving the declared paths against the clone
		-- first is what stops a second copy of that geometry being cloned in on top
		-- of the first (which is what previously gave every piston a doubled spring).
		-- Resolution happens for every path BEFORE anything is renamed, because the
		-- paths are source names and renaming as we go would break the later walks.
		local resolved: { BasePart } = {}
		for index, sub in manifest.SubParts do
			local segments: { string } = {}
			for segment in sub.Name:gmatch("[^.]+") do
				table.insert(segments, segment)
			end

			-- A dot is the path separator here, but one kit child really is called
			-- "obstacle_9_001.001" (obstacle_11's plank), so the WHOLE declared name is
			-- tried as a single child first. Splitting that one on dots would look for a
			-- child "obstacle_9_001" that does not exist and then clone the unrelated
			-- top-level conveyor of that name in beside it.
			local found: Instance? = root:FindFirstChild(sub.Name)
			if found == nil then
				found = root
				for _, segment in segments do
					found = if found then found:FindFirstChild(segment) else nil
				end
			end
			if found == nil then
				-- Not inside the root's own subtree: a sibling asset the manifest pairs
				-- with this root, so it is cloned in and parented under it.
				local subSource: Instance? = source
				for _, segment in segments do
					subSource = if subSource then subSource:FindFirstChild(segment) else nil
					assert(subSource ~= nil, `[CoursePresets] sub-part "{sub.Name}" missing from source "{id}"`)
				end
				local made = (subSource :: Instance):Clone()
				made.Parent = root
				found = made
			end
			assert((found :: Instance):IsA("BasePart"), `[CoursePresets] sub-part "{sub.Name}" is not a BasePart`)
			resolved[index] = found :: BasePart
		end
		for index, sub in manifest.SubParts do
			local part = resolved[index]
			part.Name = string.format("%s_%d", name, index)
			byPath[sub.Name] = part
		end
	end

	holder:ScaleTo(spec.Scale)

	holder:SetAttribute("CourseId", context.CourseId)
	holder:SetAttribute("BeatId", context.BeatId)
	holder:SetAttribute("PieceId", spec.Id)
	local undeclared = 0
	for _, descendant in holder:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- HANDOFF 3.3: no original source name survives into a course. A nested
			-- child that the manifest does not name still arrives inside its parent's
			-- clone, and MapFeatures selects several kits by name prefix
			-- (obstacle_18_001, obstacle_8_002, obstacle_6_001.00x), so an unrenamed
			-- descendant could be driven twice.
			if descendant.Name:sub(1, #name) ~= name then
				undeclared += 1
				descendant.Name = string.format("%s_x%d", name, undeclared)
			end
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

-- HANDOFF 6: spin speed in degrees/s is ceil((33.8 * 180 / (pi * r)) / 5) * 5,
-- computed at the radius the runner actually crosses. 33.8 is 1.3 * the 26-stud
-- walk speed, which is what makes a sweep read as a hazard rather than a nudge.
local function spinDegreesPerSecond(contactRadius: number): number
	return math.ceil((33.8 * 180 / (math.pi * contactRadius)) / 5) * 5
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
	local holder, root, manifest, byPath, exitLocal = placeTravelPiece(context, spec, cursor, spec.Preset)
	local exitWorldPosition = root.CFrame:PointToWorldSpace(exitLocal)

	if spec.Preset == "FallingTile" then
		-- 02-kits.md: "Mark a rainbow tile FallingTile=true. First support contact arms
		-- one shared countdown ... Existing Splashdown uses checkpoints, so critical
		-- route tiles must respawn; the validator rejects zero when CriticalRoute=true."
		-- The tile lives in the Assembly rather than Geometry because FeatureParts.collect
		-- only ever scans <group>/Assembly descendants; a tile left in Geometry is
		-- walkable scenery that never drops.
		root:SetAttribute(A.FallingTile, true)
		root:SetAttribute(A.DropDelaySeconds, spec.DropDelaySeconds or 0.65)
		local respawn = spec.RespawnSeconds or 3
		assert(respawn > 0, `[CoursePresets] {spec.Id}: a CriticalRoute tile must respawn (HANDOFF 13)`)
		root:SetAttribute(A.RespawnSeconds, respawn)
		root:SetAttribute("CriticalRoute", true)
		holder.Parent = context.Assembly
		local tileDelta = exitWorldPosition - cursor.Position
		return {
			Model = holder,
			ExitCursor = { Position = exitWorldPosition, Yaw = cursor.Yaw },
			PartCount = partCount(holder),
			ArcLength = Vector3.new(tileDelta.X, 0, tileDelta.Z).Magnitude,
		}
	end

	if spec.Preset == "Seesaw" then
		-- obstacle_25: a fixed pedestal carrying a rider-weighted board. The board is
		-- the route's floor here, which is why this is a chained Surface rather than a
		-- Mount -- its Entry/Exit sockets are the board's own measured walkable ends, so
		-- the lane meets it flush instead of across an invented gap.
		--
		-- 02-kits.md: "Mark the moving board Seesaw=true, with explicit centre/axle
		-- pivot, SeesawAxis X or Z ... obstacle_25_002 is long in Z, so its tested axle
		-- is X." clonePiece has already cleared the board's imported PivotOffset, so the
		-- kit's GetPivot() base is the board's own centre, which is the axle.
		--
		-- The board is the manifest's single declared sub-part, not a hard-coded id, so
		-- the same preset drives obstacle_25's short board and obstacle_11's long plank.
		-- Both pedestals are measured long in local X and both boards long in local Z,
		-- so both tilt about X.
		local boardPath = (assert(
			manifest.SubParts,
			`[CoursePresets] {spec.Id}: a seesaw source needs a declared board sub-part`
		)[1]).Name
		local board = byPath[boardPath]
		assert(board ~= nil, `[CoursePresets] {spec.Id} missing cloned seesaw board {boardPath}`)
		board:SetAttribute(A.Seesaw, true)
		board:SetAttribute(A.SeesawAxis, "X")
		-- B6: the shipped courses measure 18-24 degrees, which does not read as
		-- dangerous. Raised to 34, still overridable by spec.MaxTiltDegrees exactly
		-- as before.
		board:SetAttribute(A.MaxTiltDegrees, spec.MaxTiltDegrees or 34)
		board:SetAttribute(A.SeesawResponse, 3)
		holder.Parent = context.Assembly
		local delta = exitWorldPosition - cursor.Position
		return {
			Model = holder,
			ExitCursor = { Position = exitWorldPosition, Yaw = cursor.Yaw },
			PartCount = partCount(holder),
			ArcLength = Vector3.new(delta.X, 0, delta.Z).Magnitude,
		}
	end

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
		-- The frame's own "slide" rotor is OPT-IN: it is written only when the caller
		-- declares RotorAmplitude, and there is deliberately no default. A spiked
		-- roller that also translates side to side reads as wrong, which is why the
		-- courses that just wanted a spinning drum must say nothing and get a static
		-- frame. Summit's 06_FinalFooting is the one place the travel is the point --
		-- 27.20 studs of frame plus 2 x 8 of sweep covers a 16.25-stud bridge end to
		-- end -- so it declares the amplitude and keeps the slide.
		if spec.RotorAmplitude then
			root:SetAttribute(A.Rotor, "slide")
			root:SetAttribute(A.RotorAxis, "X")
			root:SetAttribute(A.RotorAmplitude, spec.RotorAmplitude)
			root:SetAttribute(A.RotorPeriod, spec.RotorPeriod or 3.2)
			root:SetAttribute(A.RotorPhase, spec.RotorPhase or 0)
		end
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
	elseif spec.Preset == "LogRoll" then
		-- Section 6: "Log-roll ... Spin along long axis + Shove + Carries on actual ride
		-- surface; not an unanchored physics barrel." Two source shapes qualify, so the
		-- preset drives whichever the manifest declares: a framed roller turns only its
		-- declared drum and leaves the cradle fixed (unlike a Sweeper that has opted
		-- into a sliding frame), and a single-mesh barrel turns on its own root. Speed comes from the
		-- section 6 formula at the MEASURED crossing radius, and the sign is the
		-- caller's, because consecutive rollers spin opposite ways.
		local drum = if manifest.SubParts then sub((manifest.SubParts :: any)[1].Name) else root
		local contactRadius = assert(
			manifest.ContactRadius,
			`[CoursePresets] {sourceId} has no measured ContactRadius for a LogRoll`
		) * spec.Scale
		drum:SetAttribute(A.Rotor, "spin")
		-- The barrel's own long axis, which the caller declares because the two source
		-- shapes differ: obstacle_2_002's drum is long in local X, obstacle_10_001 is
		-- long in local Y and is laid on its side by the mount's PitchDegrees.
		drum:SetAttribute(A.RotorAxis, spec.RotorAxis or "X")
		drum:SetAttribute(A.RotorSpeed, spec.RotorSpeed or spinDegreesPerSecond(contactRadius))
		drum:SetAttribute(A.RotorPhaseDegrees, (spec.RotorPhase or 0) * 60)
		drum:SetAttribute(A.RotorCarries, true)
		drum:SetAttribute(A.Shove, true)
		drum:SetAttribute(A.ShoveSpeed, spec.ShoveSpeed or 48)
		drum:SetAttribute(A.ShoveUpwardSpeed, 20)
		drum:SetAttribute(A.ShoveSeconds, 0.24)
		drum:SetAttribute(A.ShoveContact, "mesh")
		drum:SetAttribute(A.ImpactVisual, true)
		drum:SetAttribute(A.RetriggerCooldown, 0.8)
		drum:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "Piston" then
		-- B4: measured on the shipped courses, the gap from a piston body to the
		-- nearest deck edge runs 9.0-15.1 studs, so the old 6-stud throw physically
		-- could not reach some lanes, and the old cycle read as slow. All four are
		-- now spec-driven with new defaults: a longer, faster throw (18 studs,
		-- 1.9s period), a shorter hold (0.35s) and a faster shove (54).
		local spring = sub("obstacle_22_002")
		spring:SetAttribute(A.Rotor, "slide")
		spring:SetAttribute(A.RotorProfile, "piston")
		spring:SetAttribute(A.RotorAxis, "Z")
		spring:SetAttribute(A.PistonPeriod, spec.PistonPeriod or 1.9)
		spring:SetAttribute(A.PistonPhase, spec.RotorPhase or 0)
		spring:SetAttribute(A.PistonExtendStuds, spec.PistonExtendStuds or 18)
		spring:SetAttribute(A.HoldSeconds, spec.HoldSeconds or 0.35)
		spring:SetAttribute(A.Shove, true)
		spring:SetAttribute(A.ShoveSpeed, spec.ShoveSpeed or 54)
		spring:SetAttribute(A.ShoveUpwardSpeed, 20)
		spring:SetAttribute(A.ShoveSeconds, 0.24)
		spring:SetAttribute(A.ShoveContact, "mesh")
		spring:SetAttribute(A.ImpactVisual, true)
		spring:SetAttribute(A.RetriggerCooldown, 0.8)
		spring:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "Hammer" then
		local head = sub(if sourceId == "obstacle_3_001" then "obstacle_3_002" else "obstacle_4_002")
		head:SetAttribute(A.Rotor, "rock")
		head:SetAttribute(A.RotorAxis, "Z")
		head:SetAttribute(A.RotorAmplitude, spec.RotorAmplitude or 55)
		-- Retuned: the "hammer" windup/strike profile (rise 1.8s, drop .3s) read as a
		-- slow lift snapping shut, not a pendulum. The plain rock is the same symmetric
		-- sinusoid Mace and SwingPanel already swing on -- equal time each way, fastest
		-- at the bottom of the arc -- just slower than the old 2.1s cycle.
		head:SetAttribute(A.RotorPeriod, spec.RotorPeriod or 3.6)
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
		if spec.FanBallSpeed then
			root:SetAttribute(A.FanBallSpeed, spec.FanBallSpeed)
		end
		sub("propeller_trampoline_2_001"):SetAttribute(A.FanBlade, true)
	elseif spec.Preset == "BeachBall" then
		-- 02-kits.md: "BeachBall=true discovers multiple renamed descendants in an
		-- Assembly; do not also give them a kinematic motion owner. The kit moves them
		-- beside their own Scriptables root, unanchors them and assigns server network
		-- ownership." The template ball therefore ships ANCHORED, exactly as
		-- AttributeAudit demands ("author parts anchored; BeachBall unanchors at
		-- runtime"), and carries no Rotor of its own.
		root:SetAttribute(A.BeachBall, true)
	elseif spec.Preset == "Mallet" then
		-- Section 6: "Single mallet / obstacle_1_001 | Scale .6; use only after measured
		-- mounting/axle manifest; hammer profile, not a floating Bumper." The mesh is one
		-- part, so the rock lives on the root and the pivot is moved back onto the
		-- measured post base -- otherwise the whole mallet would swing about the mesh's
		-- bounding centre, which sits inside the head rather than at the mount.
		local axle = assert(manifest.Sockets.Axle, `[CoursePresets] {sourceId} has no measured Axle socket`)
		root.PivotOffset = CFrame.new(axle.Position * spec.Scale)
		root:SetAttribute(A.Rotor, "rock")
		root:SetAttribute(A.RotorAxis, "Z")
		root:SetAttribute(A.RotorAmplitude, spec.RotorAmplitude or 55)
		-- Retuned: dropped the windup/strike hammer profile for the same symmetric
		-- rock every other pendulum in the kit uses (see the Hammer preset above),
		-- at a slower period.
		root:SetAttribute(A.RotorPeriod, spec.RotorPeriod or 3.6)
		root:SetAttribute(A.RotorPhase, spec.RotorPhase or 0)
		root:SetAttribute(A.Shove, true)
		root:SetAttribute(A.ShoveSpeed, spec.ShoveSpeed or 58)
		root:SetAttribute(A.ShoveUpwardSpeed, 20)
		root:SetAttribute(A.ShoveSeconds, 0.24)
		root:SetAttribute(A.ShoveContact, "mesh")
		root:SetAttribute(A.ImpactVisual, true)
		root:SetAttribute(A.RetriggerCooldown, 0.8)
		root:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "JumpPad" then
		-- Outer/Inner are required by the runtime pad contract (HANDOFF 3.3
		-- Scriptables/JumpPads/<model>/Outer, Inner), so they keep those names
		-- while the holder carries the sd_ course name. The inner child is read
		-- from the manifest rather than hard-coded, because trampoline_5's inner
		-- is trampoline_6 and trampoline_3's is trampoline_3_002.
		root.Name = "Outer"
		local subParts = assert(manifest.SubParts, `[CoursePresets] {sourceId} has no pad inner sub-part`)
		sub(subParts[1].Name).Name = "Inner"
		holder:SetAttribute(A.JumpPad, true)
		holder:SetAttribute(A.LaunchSpeed, spec.LaunchSpeed or 51)
		holder:SetAttribute(A.FloatFactor, spec.FloatFactor or 0.2)
	elseif spec.Preset == "Spinner" then
		-- One preset for every single-mesh Y-spin shove silhouette: the dumbbell
		-- bar, the four-arm cross and the two-arm cross. Speed comes from the
		-- section 6 formula at the measured contact radius, never a chosen number.
		local contactRadius = assert(
			manifest.ContactRadius,
			`[CoursePresets] {sourceId} has no measured ContactRadius for a Spinner`
		) * spec.Scale
		root:SetAttribute(A.Rotor, "spin")
		root:SetAttribute(A.RotorAxis, "Y")
		root:SetAttribute(A.RotorSpeed, spec.RotorSpeed or spinDegreesPerSecond(contactRadius))
		root:SetAttribute(A.RotorPhaseDegrees, (spec.RotorPhase or 0) * 60)
		root:SetAttribute(A.Shove, true)
		root:SetAttribute(A.ShoveSpeed, spec.ShoveSpeed or 48)
		root:SetAttribute(A.ShoveUpwardSpeed, 20)
		root:SetAttribute(A.ShoveSeconds, 0.24)
		root:SetAttribute(A.ShoveContact, "mesh")
		root:SetAttribute(A.ImpactVisual, true)
		root:SetAttribute(A.RetriggerCooldown, 0.8)
		root:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "SwingPanel" then
		-- obstacle_8: a fixed axle with a rocking panel a rider stands on. The
		-- axle never moves; the panel both carries and shoves (section 6).
		local panel = sub("obstacle_8_002")
		panel:SetAttribute(A.Rotor, "rock")
		panel:SetAttribute(A.RotorAxis, "X")
		panel:SetAttribute(A.RotorAmplitude, spec.RotorAmplitude or 28)
		panel:SetAttribute(A.RotorPeriod, spec.RotorPeriod or 2.8)
		panel:SetAttribute(A.RotorPhase, spec.RotorPhase or 0)
		panel:SetAttribute(A.RotorCarries, true)
		panel:SetAttribute(A.Shove, true)
		panel:SetAttribute(A.ShoveSpeed, spec.ShoveSpeed or 48)
		panel:SetAttribute(A.ShoveUpwardSpeed, 20)
		panel:SetAttribute(A.ShoveSeconds, 0.24)
		panel:SetAttribute(A.ShoveContact, "mesh")
		panel:SetAttribute(A.ImpactVisual, true)
		panel:SetAttribute(A.RetriggerCooldown, 0.8)
		panel:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "Mace" then
		-- Section 6: "top-link axle, rock Z amplitude 45 period 3.2; Shove owner
		-- includes moving chain/ball". The rotor lives on the top link, which is both
		-- the axle and the shove owner: RotorBump tests the rotor part AND every
		-- follower beneath it, so the links and the ball all shove without needing
		-- their own motion owners (which AttributeAudit would reject as competing).
		root:SetAttribute(A.Rotor, "rock")
		root:SetAttribute(A.RotorAxis, "Z")
		root:SetAttribute(A.RotorAmplitude, spec.RotorAmplitude or 45)
		root:SetAttribute(A.RotorPeriod, spec.RotorPeriod or 3.2)
		root:SetAttribute(A.RotorPhase, spec.RotorPhase or 0)
		root:SetAttribute(A.Shove, true)
		root:SetAttribute(A.ShoveSpeed, spec.ShoveSpeed or 54)
		root:SetAttribute(A.ShoveUpwardSpeed, 20)
		root:SetAttribute(A.ShoveSeconds, 0.24)
		root:SetAttribute(A.ShoveContact, "mesh")
		root:SetAttribute(A.ImpactVisual, true)
		root:SetAttribute(A.RetriggerCooldown, 0.8)
		root:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "PaddleWheel" then
		-- An attribute rotor turns about its own pivot, and CoursePresets clears every
		-- imported display pivot, so the wheel would otherwise spin about the root
		-- mesh's bounding centre -- 4.25 studs (at scale 1) off the axle its four
		-- cradles actually orbit, which reads as a wobble rather than a wheel. 02-kits
		-- ("attribute rotors turn around explicit mechanical pivots; an imported
		-- display pivot is not necessarily an axle. Change pivots, never distort the
		-- mesh") is exactly this case: the authored mechanical axle is set back as a
		-- PivotOffset after scaling.
		local axle = assert(manifest.Sockets.Axle, `[CoursePresets] {sourceId} has no measured Axle socket`)
		root.PivotOffset = CFrame.new(axle.Position * spec.Scale)
		local contactRadius = assert(
			manifest.ContactRadius,
			`[CoursePresets] {sourceId} has no measured ContactRadius for a PaddleWheel`
		) * spec.Scale
		root:SetAttribute(A.Rotor, "spin")
		root:SetAttribute(A.RotorAxis, "X")
		root:SetAttribute(A.RotorSpeed, spec.RotorSpeed or spinDegreesPerSecond(contactRadius))
		root:SetAttribute(A.RotorPhaseDegrees, (spec.RotorPhase or 0) * 60)
		root:SetAttribute(A.Shove, true)
		root:SetAttribute(A.ShoveSpeed, spec.ShoveSpeed or 48)
		root:SetAttribute(A.ShoveUpwardSpeed, 20)
		root:SetAttribute(A.ShoveSeconds, 0.24)
		root:SetAttribute(A.ShoveContact, "mesh")
		root:SetAttribute(A.ImpactVisual, true)
		root:SetAttribute(A.RetriggerCooldown, 0.8)
		root:SetAttribute(A.GuardSeconds, 1.0)
	elseif spec.Preset == "Door" then
		-- One slab of a door row. DoorRows.resolve requires DoorRow and DoorIndex
		-- to be unique contiguous positive integers within the Doors folder.
		root:SetAttribute(A.DoorRow, assert(spec.DoorRow, `[CoursePresets] {spec.Id} needs DoorRow`))
		root:SetAttribute(A.DoorIndex, assert(spec.DoorIndex, `[CoursePresets] {spec.Id} needs DoorIndex`))
	end

	if spec.Preset == "Door" then
		-- Doors are the one kit selected by IMMEDIATE children of its folder:
		-- DoorRows.resolve walks Scriptables.Doors:GetChildren() for BaseParts, and
		-- MapFeatureService collects the same way, so a slab left inside a holder
		-- Model is invisible to both -- the row resolves as zero rows and every slab
		-- stays permanently solid. The slab is therefore parented straight into the
		-- Doors folder, exactly as a foam volume is, and the now-empty holder is
		-- discarded.
		assert(
			manifest.SubParts == nil,
			`[CoursePresets] {spec.Id}: a door slab must be a single part, not an assembly`
		)
		root.Parent = context.DoorsFolder
		holder:Destroy()
		return { Model = root :: any, PartCount = 1 }
	end

	holder.Parent = if spec.Preset == "JumpPad"
		then context.JumpPadsFolder
		elseif spec.Preset == "Prop" then context.Geometry
		else context.Assembly
	return { Model = holder, PartCount = partCount(holder) }
end

-- A round rotating deck the route crosses (pizza, carousel, disc). It is placed
-- by its rotation axis, not by an Entry socket: the deck turns, so only the hub
-- axis and the measured usable radius are stable. CourseBuilder advances the
-- cursor one radius in and one radius out, which is what lets a spiral change
-- heading across it without opening a wedge seam between straight slabs.
local function buildRidePiece(context: BuildContext, spec: PieceSpec, centre: Vector3, yaw: number): MountResult
	local sourceId = assert(spec.Source, `[CoursePresets] {spec.Id} needs Source`)
	local holder, root, manifest, byPath = clonePiece(context, spec, sourceId, "ride")
	local ride = assert(manifest.Ride, `[CoursePresets] {sourceId} has no measured Ride deck`)

	local plate = if ride.Plate then byPath[ride.Plate] else root
	assert(plate ~= nil, `[CoursePresets] {spec.Id} missing cloned ride plate {tostring(ride.Plate)}`)

	-- Root-local position of the deck's walkable top, on the hub axis: the
	-- plate's own measured top lifted by wherever the plate sits under the hub.
	local plateOffset = if ride.Plate
		then (assert(manifest.SubParts, "[CoursePresets] ride plate needs a SubPart entry")[1]).RelativeCFrame.Position
		else Vector3.zero
	local topLocal = Vector3.new(0, plateOffset.Y + ride.PlateTopLocalY, 0) * spec.Scale
	local rotation = CFrame.Angles(0, math.rad(yaw), 0)
	placeByPart(holder, root, CFrame.new(centre) * rotation * CFrame.new(-topLocal))

	if spec.Preset == "RoundLanding" then
		holder.Parent = context.Geometry
		return { Model = holder, PartCount = partCount(holder) }
	end

	plate:SetAttribute(A.Rotor, "spin")
	plate:SetAttribute(A.RotorAxis, "Y")
	plate:SetAttribute(A.RotorSpeed, assert(spec.RotorSpeed, `[CoursePresets] {spec.Id} needs RotorSpeed`))
	plate:SetAttribute(A.RotorPhaseDegrees, (spec.RotorPhase or 0) * 60)
	-- Ride-only platforms carry and do not shove: their hazard is lost support
	-- and real holes, not a knockback (HANDOFF section 6).
	plate:SetAttribute(A.RotorCarries, true)

	holder.Parent = context.Assembly
	return { Model = holder, PartCount = partCount(holder) }
end

function CoursePresets.buildChainPiece(context: BuildContext, spec: PieceSpec, cursor: Cursor): ChainResult
	return buildChainPiece(context, spec, cursor)
end

function CoursePresets.buildRidePiece(context: BuildContext, spec: PieceSpec, centre: Vector3, yaw: number): MountResult
	return buildRidePiece(context, spec, centre, yaw)
end

-- The measured usable crossing radius of a ride deck at this scale.
function CoursePresets.rideRadius(sourceId: string, scale: number): number
	local manifest = AssetManifest.get(sourceId)
	local ride = assert(manifest.Ride, `[CoursePresets] {sourceId} has no measured Ride deck`)
	return ride.Radius * scale
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
