-- Description: Spins authored platform assemblies from the synchronized clock; the server owns motion and publishes immutable rest descriptors, while clients batch local source transforms for smooth physics and rendering across tagged Scriptables roots.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Rotation = require(script.Parent.Rotation)
local MotionProfile = require(script.Parent.MotionProfile)
local ScriptableRoots = require(script.Parent.ScriptableRoots)

local RotatingPlatforms = {}

local FOLDER_NAMES = {
	"Motion",
	"Fans",
	"BigBalls",
	"BeachBalls",
	"Conveyors",
	"FallingTiles",
	"Seesaws",
	"Bumpers",
	"Rotating",
}
local Attributes = MapFeatures.Attributes

export type Axis = "X" | "Y" | "Z"
export type Mode = "spin" | "rock" | "slide"

export type Follower = {
	part: BasePart,
	centerToPart: CFrame,
}

export type RestPart = {
	part: BasePart,
	relative: CFrame,
	id: string?,
}

type ClientBatch = {
	parts: { BasePart },
	frames: { CFrame },
	indices: { [BasePart]: number },
}

export type LocalRotor = {
	part: BasePart,
	relativeCenter: CFrame,
	centerToPart: CFrame,
	followers: { Follower },
	axis: Axis,
	mode: Mode,
	degreesPerSecond: number,
	amplitude: number,
	period: number,
	phase: number,
	carriesRiders: boolean,
	shove: boolean,
	shoveSpeed: number?,
	parentRotor: LocalRotor?,
	parentToCenter: CFrame?,
	profile: string?,
	windup: number?,
	strike: number?,
	hold: number?,
	acceleration: number?,
	phaseDegrees: number?,
}

type RotorOptions = {
	axis: Axis,
	mode: Mode,
	degreesPerSecond: number?,
	amplitude: number?,
	period: number?,
	phase: number?,
	carriesRiders: boolean,
	shove: boolean?,
	shoveSpeed: number?,
	followers: { Follower }?,
	profile: string?,
	windup: number?,
	strike: number?,
	hold: number?,
	acceleration: number?,
	phaseDegrees: number?,
}

export type Platform = {
	assembly: Model | BasePart,
	referencePivot: CFrame,
	motionPivot: CFrame,
	relativePivot: CFrame,
	degreesPerSecond: number,
	motionEpoch: number?,
	serverCarries: boolean,
	boundsSize: Vector3,
	pivotToBounds: CFrame,
	reach: number,
	appliedAngle: number?,
	localRotors: { LocalRotor },
	restParts: { RestPart }?,
	descriptor: string?,
	clientBatch: ClientBatch?,
}

type RootState = {
	root: Instance,
	folders: { [string]: Folder },
	connections: { RBXScriptConnection },
	folderConnections: { [Folder]: { RBXScriptConnection } },
	scanQueued: boolean,
	platforms: { [Instance]: Platform },
	lastSummary: string?,
	legacyWarned: boolean,
}

local platforms: { Platform } = {}
local failedPlatforms: { [Platform]: boolean } = {}
local invalidPlatforms: { [Platform]: boolean } = {}
local bulkFailed: { [Platform]: boolean } = {}
local platformStates: { [Platform]: RootState } = {}
local roots: { [Instance]: RootState } = {}
local unwatch: (() -> ())? = nil
local moverConnection: RBXScriptConnection? = nil
local physicsConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local retryConnection: RBXScriptConnection? = nil
local retryElapsed = 0
local started = false
local generation = 0
local DESCRIPTOR = "HazardMotionDescriptorV1"
local PART_ID = "HazardMotionPartIdV1"

local function frameData(frame: CFrame): { number }
	return { frame:GetComponents() }
end

local function frameFrom(value: any): CFrame?
	if type(value) ~= "table" or #value ~= 12 then
		return nil
	end
	for _, component in value do
		if type(component) ~= "number" or component ~= component or math.abs(component) == math.huge then
			return nil
		end
	end
	return CFrame.new(table.unpack(value))
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function axisVector(axis: Axis): Vector3
	if axis == "X" then
		return Vector3.xAxis
	elseif axis == "Z" then
		return Vector3.zAxis
	end
	return Vector3.yAxis
end

function RotatingPlatforms.poseAt(platform: Platform, now: number): CFrame
	local angle = Rotation.angleAt(now, platform.degreesPerSecond)
	return platform.motionPivot * CFrame.Angles(0, angle, 0) * platform.relativePivot
end

function RotatingPlatforms.all(): { Platform }
	return platforms
end

function RotatingPlatforms.currentBounds(platform: Platform): CFrame
	return RotatingPlatforms.poseAt(platform, Workspace:GetServerTimeNow()) * platform.pivotToBounds
end

local function rotorOwns(rotor: LocalRotor, part: BasePart): boolean
	if rotor.part == part then
		return true
	end
	for _, follower in rotor.followers do
		if follower.part == part then
			return true
		end
	end
	return false
end

function RotatingPlatforms.rotorFor(part: BasePart): (Platform?, LocalRotor?)
	for _, platform in platforms do
		for _, rotor in platform.localRotors do
			if rotorOwns(rotor, part) then
				local ancestor: LocalRotor? = rotor
				while ancestor do
					if ancestor.carriesRiders then
						return platform, rotor
					end
					ancestor = ancestor.parentRotor
				end
			end
		end
	end
	return nil, nil
end

-- The rotor a contact part belongs to, carried or not, for the shove kit.
function RotatingPlatforms.rotorOwning(part: BasePart): (Platform?, LocalRotor?)
	for _, platform in platforms do
		for _, rotor in platform.localRotors do
			if rotorOwns(rotor, part) then
				return platform, rotor
			end
		end
	end
	return nil, nil
end

local MINIMUM_TURN_RADIANS = 1e-5

local function containsSeesaw(assembly: Model | BasePart): boolean
	if assembly:IsA("BasePart") and assembly:GetAttribute(Attributes.Seesaw) == true then
		return true
	end
	for _, descendant in assembly:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute(Attributes.Seesaw) == true then
			return true
		end
	end
	return false
end

local function motionAt(platform: Platform, rotor: LocalRotor, now: number): (number, number)
	if rotor.profile == "hammer" then
		return MotionProfile.hammer(now, rotor.amplitude, rotor.windup :: number, rotor.strike :: number, rotor.phase)
	elseif rotor.profile == "piston" then
		return MotionProfile.piston(now, rotor.amplitude, rotor.period, rotor.hold :: number, rotor.phase)
	elseif rotor.mode == "spin" then
		local epoch = platform.motionEpoch
		-- Never accelerate against the absolute Unix clock when a builder forgets its epoch.
		return MotionProfile.spin(
			now,
			rotor.degreesPerSecond,
			if epoch then rotor.acceleration or 0 else 0,
			epoch or 0,
			rotor.phaseDegrees or 0
		)
	end
	return Rotation.rockAt(now, rotor.amplitude, rotor.period, rotor.phase),
		Rotation.rockRateAt(now, rotor.amplitude, rotor.period, rotor.phase)
end

local function rotorSpin(platform: Platform, rotor: LocalRotor, now: number): CFrame
	local a = motionAt(platform, rotor, now)
	if rotor.mode == "slide" then
		return CFrame.new(axisVector(rotor.axis) * a)
	end
	if rotor.axis == "X" then
		return CFrame.Angles(a, 0, 0)
	elseif rotor.axis == "Z" then
		return CFrame.Angles(0, 0, a)
	end
	return CFrame.Angles(0, a, 0)
end

local function rotorBasePoseAt(platform: Platform, rotor: LocalRotor, now: number): CFrame
	if rotor.parentRotor then
		return RotatingPlatforms.rotorPoseAt(platform, rotor.parentRotor, now) * (rotor.parentToCenter :: CFrame)
	end
	return RotatingPlatforms.poseAt(platform, now) * rotor.relativeCenter
end

function RotatingPlatforms.rotorPoseAt(platform: Platform, rotor: LocalRotor, now: number): CFrame
	return rotorBasePoseAt(platform, rotor, now) * rotorSpin(platform, rotor, now)
end

-- Velocity of the rotor's surface at a world position: the ring's own turn plus
-- the rotor's spin, swing or slide, so a shove can push the way the part moves.
function RotatingPlatforms.surfaceVelocityAt(
	platform: Platform,
	rotor: LocalRotor,
	position: Vector3,
	now: number
): Vector3
	local ringAxis = platform.motionPivot.UpVector * math.rad(platform.degreesPerSecond)
	local velocity = ringAxis:Cross(position - platform.motionPivot.Position)
	local current: LocalRotor? = rotor
	while current do
		local centerFrame = rotorBasePoseAt(platform, current, now)
		local axisWorld = centerFrame:VectorToWorldSpace(axisVector(current.axis))
		local r = position - centerFrame.Position
		local _, rate = motionAt(platform, current, now)
		velocity += if current.mode == "slide" then axisWorld * rate else (axisWorld * rate):Cross(r)
		current = current.parentRotor
	end
	return velocity
end

-- Applies a compiled assembly without depending on a running heartbeat.
function RotatingPlatforms.applyAt(platform: Platform, now: number)
	-- A physical board must never be reset by a kinematic group pivot.
	if containsSeesaw(platform.assembly) then
		return
	end
	local angle = Rotation.angleAt(now, platform.degreesPerSecond)
	local pose = platform.motionPivot * CFrame.Angles(0, angle, 0) * platform.relativePivot
	if platform.appliedAngle == nil or math.abs(angle - platform.appliedAngle) >= MINIMUM_TURN_RADIANS then
		platform.appliedAngle = angle
		if platform.restParts then
			for _, entry in platform.restParts do
				if entry.part:IsDescendantOf(platform.assembly) or entry.part == platform.assembly then
					entry.part.CFrame = pose * entry.relative
				end
			end
		else
			platform.assembly:PivotTo(pose)
		end
	end
	-- One server mover composes the ring with its fan blades, paddles, discs, and swing panels.
	for _, rotor in platform.localRotors do
		if rotor.part == platform.assembly or rotor.part:IsDescendantOf(platform.assembly) then
			local center = RotatingPlatforms.rotorPoseAt(platform, rotor, now)
			rotor.part.CFrame = center * rotor.centerToPart
			for _, follower in rotor.followers do
				if follower.part:IsDescendantOf(platform.assembly) then
					follower.part.CFrame = center * follower.centerToPart
				end
			end
		end
	end
end

function RotatingPlatforms.stepAt(now: number)
	for _, platform in platforms do
		RotatingPlatforms.applyAt(platform, now)
	end
end

local function step()
	RotatingPlatforms.stepAt(Workspace:GetServerTimeNow())
end

local function attributeRotor(part: BasePart): RotorOptions?
	local mode = part:GetAttribute(Attributes.Rotor)
	if mode == nil then
		return nil
	end
	local function requiredNumber(name: string, minimum: number?): number
		local value = part:GetAttribute(name)
		assert(
			type(value) == "number" and value == value and math.abs(value) < math.huge,
			`[RotatingPlatforms] {part:GetFullName()}.{name} must be a finite number`
		)
		if minimum then
			assert(value >= minimum, `[RotatingPlatforms] {part:GetFullName()}.{name} is below its minimum`)
		end
		return value
	end
	local function optionalNumber(name: string, fallback: number, minimum: number?): number
		if part:GetAttribute(name) == nil then
			return fallback
		end
		return requiredNumber(name, minimum)
	end
	if mode ~= "spin" and mode ~= "rock" and mode ~= "slide" then
		assert(false, `[RotatingPlatforms] {part:GetFullName()}.Rotor must be spin, rock, or slide`)
	end
	local axis = part:GetAttribute(Attributes.RotorAxis)
	assert(axis == "X" or axis == "Y" or axis == "Z", `[RotatingPlatforms] {part:GetFullName()}.RotorAxis is required`)
	local profile = part:GetAttribute(Attributes.RotorProfile)
	local amplitude = if mode == "spin" or profile == "piston"
		then optionalNumber(Attributes.RotorAmplitude, 0)
		else requiredNumber(Attributes.RotorAmplitude, 0)
	-- Spin uses RotorSpeed, while a piston has its own period and extent.
	-- Validate optional generic values when present without requiring duplicates.
	local period = if mode == "spin" or profile == "piston"
		then optionalNumber(Attributes.RotorPeriod, 1, 0.05)
		else requiredNumber(Attributes.RotorPeriod, 0.05)
	local phase = optionalNumber(Attributes.RotorPhase, 0)
	if profile == "piston" and mode == "slide" then
		period = requiredNumber(Attributes.PistonPeriod, 0.1)
		amplitude = requiredNumber(Attributes.PistonExtendStuds, 0)
		phase = optionalNumber(Attributes.PistonPhase, 0)
	elseif profile ~= "hammer" or mode ~= "rock" then
		profile = nil
	end
	if profile == "hammer" then
		assert(mode == "rock", `[RotatingPlatforms] {part:GetFullName()}.RotorProfile=hammer requires rock mode`)
	elseif profile == "piston" then
		assert(mode == "slide", `[RotatingPlatforms] {part:GetFullName()}.RotorProfile=piston requires slide mode`)
	end
	local speed = if mode == "spin" then requiredNumber(Attributes.RotorSpeed) else 0
	local windup = if profile == "hammer" then requiredNumber(Attributes.WindupSeconds, 0.05) else 0.05
	local strike = if profile == "hammer" then requiredNumber(Attributes.StrikeSeconds, 0.05) else 0.05
	local hold = if profile == "piston" then optionalNumber(Attributes.HoldSeconds, 0, 0) else 0
	assert(
		hold >= 0 and hold < period,
		`[RotatingPlatforms] {part:GetFullName()}.HoldSeconds must be less than its period`
	)
	return {
		axis = axis,
		mode = mode,
		degreesPerSecond = speed,
		amplitude = if mode == "slide" then amplitude else math.rad(amplitude),
		period = period,
		phase = phase,
		profile = profile :: string?,
		windup = windup,
		strike = strike,
		hold = hold,
		acceleration = optionalNumber(Attributes.RotorAccel, 0),
		phaseDegrees = optionalNumber(Attributes.RotorPhaseDegrees, 0),
		carriesRiders = part:GetAttribute(Attributes.RotorCarries) == true,
		shove = part:GetAttribute(Attributes.Shove) == true,
		shoveSpeed = if part:GetAttribute(Attributes.ShoveSpeed) == nil
			then nil
			else requiredNumber(Attributes.ShoveSpeed, 0),
	}
end

local function isArenaCompatibilityRoot(root: Instance): boolean
	local arena = root.Parent
	local assets = arena and arena.Parent
	return root.Name == "Scriptables"
		and arena ~= nil
		and arena.Name == "Arena"
		and assets ~= nil
		and assets.Name == "Assets"
end

local function isFan(base: BasePart): boolean
	return MapFeatures.Fan.EnabledNames[base.Name] == true or base:GetAttribute(Attributes.Fan) == true
end

local function getBounds(instance: Model | BasePart): (CFrame, Vector3)
	if instance:IsA("Model") then
		return instance:GetBoundingBox()
	elseif instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end
	return CFrame.identity, Vector3.zero
end

-- BeachBalls moves these parts out of the assembly into live physics. Match its
-- selection exactly so neither a rotor nor a rest snapshot retains ownership.
local function isDetachedBeachBallCandidate(part: BasePart, assembly: Model | BasePart): boolean
	return part:GetAttribute(Attributes.BeachBall) == true
		or (
			assembly:FindFirstAncestor("SplashdownCourse") == nil
			and part.Parent == assembly
			and part.Name:find(MapFeatures.BeachBall.NamePrefix, 1, true) == 1
		)
end

local function isDetachedBeachBall(part: BasePart, assembly: Model | BasePart): boolean
	local ancestor: Instance? = part
	while ancestor do
		if ancestor:IsA("BasePart") and isDetachedBeachBallCandidate(ancestor, assembly) then
			return true
		end
		if ancestor == assembly then
			break
		end
		ancestor = ancestor.Parent
	end
	return false
end

local function build(first: Model | BasePart, second: (Model | BasePart)?): Platform
	-- The two-argument form is the bounded Arena compatibility adapter. New
	-- assemblies use their authored pivot as both the reference and motion pivot.
	local legacyOrigin: BasePart? = nil
	local assembly: Model | BasePart
	if second ~= nil and first:IsA("BasePart") then
		legacyOrigin = first
		assembly = second
	else
		assembly = first
	end
	local referencePivot = assembly:GetPivot()
	local motionPivot = if legacyOrigin then legacyOrigin.CFrame else referencePivot
	local pivot = referencePivot
	local boundsCFrame, boundsSize = getBounds(assembly)
	local localRotors: { LocalRotor } = {}
	-- Imported pivot orientations are arbitrary; use only the authored center so
	-- the local rotation stays around a stable axis within the moving ring.
	local function addRotor(part: BasePart, center: CFrame, options: RotorOptions)
		if isDetachedBeachBall(part, assembly) then
			return
		end
		table.insert(localRotors, {
			part = part,
			relativeCenter = pivot:ToObjectSpace(center),
			centerToPart = center:ToObjectSpace(part.CFrame),
			followers = options.followers or {},
			axis = options.axis,
			mode = options.mode,
			degreesPerSecond = options.degreesPerSecond or 0,
			amplitude = options.amplitude or 0,
			period = options.period or 1,
			phase = options.phase or 0,
			profile = options.profile,
			windup = options.windup,
			strike = options.strike,
			hold = options.hold,
			acceleration = options.acceleration,
			phaseDegrees = options.phaseDegrees,
			carriesRiders = options.carriesRiders,
			shove = options.shove == true,
			shoveSpeed = options.shoveSpeed,
		})
	end

	local function checkBase(base: BasePart)
		if isDetachedBeachBall(base, assembly) then
			return
		end
		local allowLegacy = legacyOrigin ~= nil
		if allowLegacy and MapFeatures.Spinner.EnabledNames[base.Name] then
			local center = base.CFrame.Rotation + base.CFrame:PointToWorldSpace(base.PivotOffset.Position)
			addRotor(base, center, {
				axis = "Y",
				mode = "spin",
				degreesPerSecond = MapFeatures.Spinner.DegreesPerSecond,
				carriesRiders = false,
			})
		end
		if allowLegacy and base.Name:find(MapFeatures.Disc.HubPrefix, 1, true) == 1 then
			for _, plate in base:GetChildren() do
				if plate:IsA("BasePart") and plate.Name:find(MapFeatures.Disc.PlatePrefix, 1, true) == 1 then
					local center = base.CFrame.Rotation + plate.Position
					addRotor(plate, center, {
						axis = "Y",
						mode = "spin",
						degreesPerSecond = MapFeatures.Disc.DegreesPerSecond,
						carriesRiders = true,
					})
				end
			end
		end
		if allowLegacy and base.Name:find(MapFeatures.SwingPanel.AxlePrefix, 1, true) == 1 then
			local suffix = tonumber(base.Name:match("%.(%d+)$")) or 0
			for _, panel in base:GetChildren() do
				if panel:IsA("BasePart") and panel.Name:find(MapFeatures.SwingPanel.PanelPrefix, 1, true) == 1 then
					local center = base.CFrame.Rotation + base.Position
					addRotor(panel, center, {
						axis = "X",
						mode = "rock",
						amplitude = math.rad(MapFeatures.SwingPanel.AmplitudeDegrees),
						period = MapFeatures.SwingPanel.PeriodSeconds,
						phase = suffix * MapFeatures.SwingPanel.PhaseStepSeconds,
						carriesRiders = false,
					})
				end
			end
		end
		-- An attribute rotor turns about its own pivot and carries every part
		-- beneath it as one rigid body, so a chain, a paddle wheel or a bar on a
		-- post is authored as a plain hierarchy with one attribute set.
		local declared = attributeRotor(base)
		if declared then
			-- RotorAxis is authored in the part's own frame. A mesh can use a
			-- rotated PivotOffset to place its hinge, as Ball Barrage's axes do;
			-- using GetPivot()'s rotation here applies that offset rotation twice
			-- and changes the swing plane. Keep the pivot position, but preserve
			-- the part CFrame orientation for the rotor basis.
			local authoredPivot = base:GetPivot()
			local center = base.CFrame.Rotation + authoredPivot.Position
			local followers: { Follower } = {}
			for _, descendant in base:GetDescendants() do
				if descendant:IsA("BasePart") and not isDetachedBeachBall(descendant, assembly) then
					table.insert(
						followers,
						{ part = descendant, centerToPart = center:ToObjectSpace(descendant.CFrame) }
					)
				end
			end
			declared.followers = followers
			addRotor(base, center, declared)
		end
	end

	if assembly:IsA("BasePart") then
		checkBase(assembly)
		for _, descendant in assembly:GetDescendants() do
			if descendant:IsA("BasePart") then
				checkBase(descendant)
			end
		end
	else
		for _, base in assembly:GetDescendants() do
			if base:IsA("BasePart") then
				checkBase(base)
			end
		end
	end

	-- Each part has exactly one motion owner. An explicit attribute replaces a
	-- legacy name match on that same part; unrelated arena paths stay unchanged.
	local byPart: { [BasePart]: LocalRotor } = {}
	for _, rotor in localRotors do
		byPart[rotor.part] = rotor
	end
	local unique: { LocalRotor } = {}
	for _, rotor in localRotors do
		if byPart[rotor.part] == rotor then
			table.insert(unique, rotor)
		end
	end
	localRotors = unique
	local function owner(part: Instance): LocalRotor?
		local ancestor: Instance? = part
		while ancestor do
			if ancestor:IsA("BasePart") and byPart[ancestor] then
				return byPart[ancestor]
			end
			if ancestor == assembly then
				break
			end
			ancestor = ancestor.Parent
		end
		return nil
	end
	for _, rotor in localRotors do
		rotor.parentRotor = if rotor.part.Parent then owner(rotor.part.Parent) else nil
		if rotor.parentRotor then
			rotor.parentToCenter = rotor.parentRotor.relativeCenter:ToObjectSpace(rotor.relativeCenter)
		end
		local followers: { Follower } = {}
		for _, follower in rotor.followers do
			if owner(follower.part) == rotor then
				table.insert(followers, follower)
			end
		end
		rotor.followers = followers
	end

	local metadata = assembly :: Instance
	local legacyMetadata = legacyOrigin :: Instance?
	local function attribute(name: string): any
		local value = metadata:GetAttribute(name)
		if value == nil and legacyMetadata then
			value = legacyMetadata:GetAttribute(name)
		end
		return value
	end
	return {
		assembly = assembly,
		referencePivot = referencePivot,
		motionPivot = motionPivot,
		relativePivot = motionPivot:Inverse() * pivot,
		-- New moving models own their motion through explicit rotor parts. The
		-- legacy assembly default is only valid when the Origin adapter exists;
		-- otherwise every piston/hammer model would slowly orbit its own pivot.
		degreesPerSecond = if legacyOrigin
			then (attribute("RotationSpeed") :: number?) or MapFeatures.Rotating.DegreesPerSecond
			else (attribute("RotationSpeed") :: number?) or 0,
		motionEpoch = tonumber(attribute(Attributes.MotionEpoch)),
		serverCarries = attribute(Attributes.ServerCarries) == true,
		boundsSize = boundsSize,
		pivotToBounds = pivot:Inverse() * boundsCFrame,
		reach = (boundsCFrame.Position - motionPivot.Position).Magnitude + boundsSize.Magnitude / 2,
		localRotors = localRotors,
	}
end

-- Builds a snapshot without registering a heartbeat or modifying geometry.
-- Useful to builders/validators and deterministic engine tests.
RotatingPlatforms.build = build

-- The server publishes the authored rest state before its first Heartbeat move.
-- Part IDs make hydration independent of child replication order and streaming.
local function publish(key: Instance, platform: Platform)
	local parts: { BasePart } = {}
	if platform.assembly:IsA("BasePart") and not isDetachedBeachBall(platform.assembly, platform.assembly) then
		table.insert(parts, platform.assembly)
	end
	for _, descendant in platform.assembly:GetDescendants() do
		if descendant:IsA("BasePart") and not isDetachedBeachBall(descendant, platform.assembly) then
			table.insert(parts, descendant)
		end
	end
	local token = HttpService:GenerateGUID(false)
	local ids: { [BasePart]: string } = {}
	local partStates = {}
	for index, part in parts do
		local id = `{token}:{index}`
		ids[part] = id
		partStates[index] = { id = id, rest = frameData(part.CFrame) }
		part:SetAttribute(PART_ID, id)
	end
	local rotorIndices: { [LocalRotor]: number } = {}
	for index, rotor in platform.localRotors do
		rotorIndices[rotor] = index
	end
	local rotors = {}
	for _, rotor in platform.localRotors do
		local followers = {}
		for _, follower in rotor.followers do
			table.insert(followers, { id = ids[follower.part], centerToPart = frameData(follower.centerToPart) })
		end
		table.insert(rotors, {
			id = ids[rotor.part],
			relativeCenter = frameData(rotor.relativeCenter),
			centerToPart = frameData(rotor.centerToPart),
			followers = followers,
			axis = rotor.axis,
			mode = rotor.mode,
			degreesPerSecond = rotor.degreesPerSecond,
			amplitude = rotor.amplitude,
			period = rotor.period,
			phase = rotor.phase,
			carriesRiders = rotor.carriesRiders,
			shove = rotor.shove,
			shoveSpeed = rotor.shoveSpeed,
			parent = if rotor.parentRotor then rotorIndices[rotor.parentRotor] else nil,
			parentToCenter = if rotor.parentToCenter then frameData(rotor.parentToCenter) else nil,
			profile = rotor.profile,
			windup = rotor.windup,
			strike = rotor.strike,
			hold = rotor.hold,
			acceleration = rotor.acceleration,
			phaseDegrees = rotor.phaseDegrees,
		})
	end
	key:SetAttribute(
		DESCRIPTOR,
		HttpService:JSONEncode({
			version = 1,
			parts = partStates,
			referencePivot = frameData(platform.referencePivot),
			motionPivot = frameData(platform.motionPivot),
			relativePivot = frameData(platform.relativePivot),
			pivotToBounds = frameData(platform.pivotToBounds),
			boundsSize = { platform.boundsSize.X, platform.boundsSize.Y, platform.boundsSize.Z },
			degreesPerSecond = platform.degreesPerSecond,
			motionEpoch = platform.motionEpoch,
			serverCarries = platform.serverCarries,
			reach = platform.reach,
			rotors = rotors,
		})
	)
end

local function hydrate(key: Instance, assembly: Model | BasePart): Platform?
	local encoded = key:GetAttribute(DESCRIPTOR)
	if type(encoded) ~= "string" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, encoded)
	if not ok or type(data) ~= "table" or data.version ~= 1 or type(data.parts) ~= "table" then
		return nil
	end
	local actual: { [string]: BasePart } = {}
	local actualCount = 0
	local function collect(part: BasePart): boolean
		if isDetachedBeachBall(part, assembly) then
			return true
		end
		local id = part:GetAttribute(PART_ID)
		if type(id) ~= "string" or actual[id] or not part.Anchored then
			return false
		end
		actual[id] = part
		actualCount += 1
		return true
	end
	if assembly:IsA("BasePart") and not collect(assembly) then
		return nil
	end
	for _, descendant in assembly:GetDescendants() do
		if descendant:IsA("BasePart") and not collect(descendant) then
			return nil
		end
	end
	if actualCount ~= #data.parts then
		return nil
	end
	local matched: { [string]: boolean } = {}
	local restParts: { RestPart } = {}
	local referencePivot = frameFrom(data.referencePivot)
	if not referencePivot then
		return nil
	end
	for _, entry in data.parts do
		local id = entry.id
		local rest = frameFrom(entry.rest)
		if type(id) ~= "string" or not actual[id] or matched[id] or not rest then
			return nil
		end
		matched[id] = true
		table.insert(restParts, { part = actual[id], relative = referencePivot:ToObjectSpace(rest), id = id })
	end
	local motionPivot = frameFrom(data.motionPivot)
	local relativePivot = frameFrom(data.relativePivot)
	local pivotToBounds = frameFrom(data.pivotToBounds)
	local size = data.boundsSize
	if
		not referencePivot
		or not motionPivot
		or not relativePivot
		or not pivotToBounds
		or type(size) ~= "table"
		or #size ~= 3
		or not finite(size[1])
		or not finite(size[2])
		or not finite(size[3])
		or not finite(data.degreesPerSecond)
		or not finite(data.reach)
		or (data.motionEpoch ~= nil and not finite(data.motionEpoch))
		or type(data.serverCarries) ~= "boolean"
		or type(data.rotors) ~= "table"
	then
		return nil
	end
	local rotors: { LocalRotor } = {}
	local owned: { [BasePart]: boolean } = {}
	for _, item in data.rotors do
		local part = actual[item.id]
		local center = frameFrom(item.relativeCenter)
		local offset = frameFrom(item.centerToPart)
		if
			not part
			or not center
			or not offset
			or (item.axis ~= "X" and item.axis ~= "Y" and item.axis ~= "Z")
			or (item.mode ~= "spin" and item.mode ~= "rock" and item.mode ~= "slide")
			or not finite(item.degreesPerSecond)
			or not finite(item.amplitude)
			or not finite(item.period)
			or not finite(item.phase)
			or type(item.carriesRiders) ~= "boolean"
			or type(item.shove) ~= "boolean"
			or type(item.followers) ~= "table"
			or owned[part]
			or (item.shoveSpeed ~= nil and not finite(item.shoveSpeed))
			or (item.acceleration ~= nil and not finite(item.acceleration))
			or (item.phaseDegrees ~= nil and not finite(item.phaseDegrees))
			or (item.profile ~= nil and item.profile ~= "hammer" and item.profile ~= "piston")
			or (item.profile == "hammer" and (not finite(item.windup) or not finite(item.strike)))
			or (item.profile == "piston" and not finite(item.hold))
		then
			return nil
		end
		owned[part] = true
		local followers: { Follower } = {}
		for _, entry in item.followers do
			local followerPart = actual[entry.id]
			local followerOffset = frameFrom(entry.centerToPart)
			if not followerPart or not followerOffset or owned[followerPart] then
				return nil
			end
			owned[followerPart] = true
			table.insert(followers, { part = followerPart, centerToPart = followerOffset })
		end
		table.insert(rotors, {
			part = part,
			relativeCenter = center,
			centerToPart = offset,
			followers = followers,
			axis = item.axis,
			mode = item.mode,
			degreesPerSecond = item.degreesPerSecond,
			amplitude = item.amplitude,
			period = item.period,
			phase = item.phase,
			carriesRiders = item.carriesRiders,
			shove = item.shove,
			shoveSpeed = item.shoveSpeed,
			profile = item.profile,
			windup = item.windup,
			strike = item.strike,
			hold = item.hold,
			acceleration = item.acceleration,
			phaseDegrees = item.phaseDegrees,
		})
	end
	for index, item in data.rotors do
		if item.parent ~= nil then
			local parentFrame = frameFrom(item.parentToCenter)
			if not finite(item.parent) or item.parent >= index or not rotors[item.parent] or not parentFrame then
				return nil
			end
			rotors[index].parentRotor = rotors[item.parent]
			rotors[index].parentToCenter = parentFrame
		end
	end
	local batchParts: { BasePart } = {}
	local batchFrames: { CFrame } = {}
	local batchIndices: { [BasePart]: number } = {}
	for index, entry in restParts do
		batchParts[index] = entry.part
		batchFrames[index] = CFrame.identity
		batchIndices[entry.part] = index
	end
	for _, rotor in rotors do
		if not batchIndices[rotor.part] then
			return nil
		end
		for _, follower in rotor.followers do
			if not batchIndices[follower.part] then
				return nil
			end
		end
	end
	return {
		assembly = assembly,
		referencePivot = referencePivot,
		motionPivot = motionPivot,
		relativePivot = relativePivot,
		pivotToBounds = pivotToBounds,
		boundsSize = Vector3.new(size[1], size[2], size[3]),
		degreesPerSecond = data.degreesPerSecond,
		motionEpoch = data.motionEpoch,
		serverCarries = data.serverCarries,
		reach = data.reach,
		localRotors = rotors,
		restParts = restParts,
		descriptor = encoded,
		clientBatch = { parts = batchParts, frames = batchFrames, indices = batchIndices },
	}
end

local function membershipMatches(key: Instance, platform: Platform): boolean
	if key:GetAttribute(DESCRIPTOR) ~= platform.descriptor then
		return false
	end
	local restParts = platform.restParts
	if not restParts then
		return false
	end
	local expected: { [BasePart]: boolean } = {}
	for _, entry in restParts do
		if
			entry.part:GetAttribute(PART_ID) ~= entry.id
			or not entry.part.Anchored
			or (entry.part ~= platform.assembly and not entry.part:IsDescendantOf(platform.assembly))
		then
			return false
		end
		expected[entry.part] = true
	end
	local count = 0
	local function matches(part: BasePart): boolean
		if isDetachedBeachBall(part, platform.assembly) then
			return true
		end
		count += 1
		return expected[part] == true
	end
	if platform.assembly:IsA("BasePart") and not matches(platform.assembly) then
		return false
	end
	for _, descendant in platform.assembly:GetDescendants() do
		if descendant:IsA("BasePart") and not matches(descendant) then
			return false
		end
	end
	return count == #restParts
end

local function forgetGroup(state: RootState, child: Instance)
	local platform = state.platforms[child]
	if platform == nil then
		return
	end
	state.platforms[child] = nil
	failedPlatforms[platform] = nil
	invalidPlatforms[platform] = nil
	bulkFailed[platform] = nil
	platformStates[platform] = nil
	local index = table.find(platforms, platform)
	if index then
		table.remove(platforms, index)
	end
end

local function hasMotionMarker(model: Model, allowLegacy: boolean): boolean
	if
		(allowLegacy and model:GetAttribute("RotationSpeed") ~= nil)
		or model:GetAttribute(Attributes.MotionEpoch) ~= nil
		or model:GetAttribute(Attributes.ServerCarries) ~= nil
	then
		return true
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if
				descendant:GetAttribute(Attributes.Rotor) ~= nil
				or (allowLegacy and MapFeatures.Spinner.EnabledNames[descendant.Name])
				or (allowLegacy and isFan(descendant))
				or (allowLegacy and descendant.Name:find(MapFeatures.Disc.HubPrefix, 1, true) == 1)
				or (allowLegacy and descendant.Name:find(MapFeatures.SwingPanel.AxlePrefix, 1, true) == 1)
			then
				local owner = descendant:FindFirstAncestorOfClass("Model")
				if owner == model then
					return true
				end
			end
		end
	end
	return false
end

local function hasPartMotionMarker(part: BasePart, allowLegacy: boolean): boolean
	return part:GetAttribute(Attributes.Rotor) ~= nil
		or (allowLegacy and MapFeatures.Spinner.EnabledNames[part.Name] == true)
		or (allowLegacy and isFan(part))
		or (allowLegacy and part.Name:find(MapFeatures.Disc.HubPrefix, 1, true) == 1)
		or (allowLegacy and part.Name:find(MapFeatures.SwingPanel.AxlePrefix, 1, true) == 1)
end

local function register(state: RootState, key: Instance, assembly: Model | BasePart, legacyOrigin: BasePart?)
	if state.platforms[key] then
		return
	end
	if containsSeesaw(assembly) then
		return
	end
	local platform: Platform?
	if RunService:IsServer() then
		platform = if legacyOrigin then build(legacyOrigin, assembly) else build(assembly)
		local ok, reason = pcall(publish, key, platform)
		if not ok then
			warn(`[RotatingPlatforms] rest snapshot unavailable for {key:GetFullName()}: {reason}`)
		end
	else
		local ok, result = pcall(hydrate, key, assembly)
		platform = if ok then result else nil
	end
	if not platform then
		return
	end
	state.platforms[key] = platform
	table.insert(platforms, platform)
	if RunService:IsClient() then
		platformStates[platform] = state
	end
end

local function scan(state: RootState)
	if not started or roots[state.root] ~= state or not state.root:IsDescendantOf(Workspace) then
		return
	end
	local liveFolders: { Folder } = {}
	for _, folder in state.folders do
		if folder.Parent == state.root then
			table.insert(liveFolders, folder)
		end
	end
	local seen: { [Instance]: boolean } = {}
	local legacy: { [Instance]: { origin: BasePart, assembly: Model | BasePart } } = {}
	local rejected = 0
	local allowLegacy = isArenaCompatibilityRoot(state.root)
	if state.folders.Rotating and state.folders.Rotating.Parent == state.root and not state.legacyWarned then
		state.legacyWarned = true
		if allowLegacy then
			warn(`[RotatingPlatforms] WARN temporary Arena legacy motion: {state.root:GetFullName()}.Rotating`)
		else
			warn(`[RotatingPlatforms] ERROR legacy Rotating root rejected outside Arena: {state.root:GetFullName()}`)
		end
	end
	if allowLegacy then
		for _, folder in liveFolders do
			for _, child in folder:GetChildren() do
				local origin = child:FindFirstChild("Origin")
				local assembly = child:FindFirstChild("Assembly")
				if
					origin
					and origin:IsA("BasePart")
					and assembly
					and (assembly:IsA("Model") or assembly:IsA("BasePart"))
				then
					legacy[child] = { origin = origin, assembly = assembly :: Model | BasePart }
				elseif origin ~= nil or assembly ~= nil then
					rejected += 1
					warn(`[RotatingPlatforms] rejected malformed legacy group {child:GetFullName()}`)
				end
			end
		end
	end
	local candidates = 0
	for _, folder in liveFolders do
		for _, descendant in folder:GetDescendants() do
			local isLegacyMember = false
			for _, entry in legacy do
				if descendant == entry.assembly or descendant:IsDescendantOf(entry.assembly) then
					isLegacyMember = true
					break
				end
			end
			local candidate = if not isLegacyMember
					and descendant:IsA("Model")
					and hasMotionMarker(descendant, allowLegacy)
				then descendant
				elseif
					not isLegacyMember
					and descendant:IsA("BasePart")
					and descendant.Parent == folder
					and hasPartMotionMarker(descendant, allowLegacy)
				then descendant
				else nil
			if candidate then
				candidates += 1
				seen[candidate] = true
				if RunService:IsClient() and state.platforms[candidate] then
					if
						invalidPlatforms[state.platforms[candidate]]
						or not membershipMatches(candidate, state.platforms[candidate])
					then
						forgetGroup(state, candidate)
					end
				end
				register(state, candidate, candidate :: Model | BasePart, nil)
			end
		end
	end
	-- Explicitly bounded legacy adapter: only a direct Rotating child with both
	-- named members is treated as an old group. Category folders are ignored.
	for child, entry in legacy do
		seen[child] = true
		if RunService:IsClient() and state.platforms[child] then
			if invalidPlatforms[state.platforms[child]] or not membershipMatches(child, state.platforms[child]) then
				forgetGroup(state, child)
			end
		end
		register(state, child, entry.assembly, entry.origin)
	end
	for key in state.platforms do
		local inMotionFolder = false
		for _, folder in liveFolders do
			if key:IsDescendantOf(folder) then
				inMotionFolder = true
				break
			end
		end
		if not seen[key] or key.Parent == nil or not inMotionFolder then
			forgetGroup(state, key)
		end
	end
	local rotorCount = 0
	local registeredCount = 0
	for _, platform in state.platforms do
		registeredCount += 1
		rotorCount += #platform.localRotors
	end
	local summary = `{candidates}|{registeredCount}|{rotorCount}|{rejected}`
	if summary ~= state.lastSummary then
		state.lastSummary = summary
		print(
			`[RotatingPlatforms] root={state.root:GetFullName()} candidates={candidates} registered={registeredCount} rotors={rotorCount} rejected={rejected}`
		)
		if RunService:IsServer() and candidates > 0 and registeredCount == 0 then
			warn(
				`[RotatingPlatforms] motion markers found but no platforms registered under {state.root:GetFullName()}`
			)
		end
	end
end

local function scheduleScan(state: RootState)
	if state.scanQueued then
		return
	end
	state.scanQueued = true
	task.defer(function()
		state.scanQueued = false
		if roots[state.root] == state then
			scan(state)
		end
	end)
end

local function detachFolder(state: RootState, folder: Folder)
	local tracked = false
	for name, current in state.folders do
		if current == folder then
			state.folders[name] = nil
			tracked = true
		end
	end
	local connections = state.folderConnections[folder]
	if connections then
		tracked = true
		for _, connection in connections do
			connection:Disconnect()
		end
		state.folderConnections[folder] = nil
	end
	if tracked then
		scheduleScan(state)
	end
end

local function attachFolder(state: RootState, folder: Folder)
	if folder.Parent ~= state.root then
		return
	end
	local previous = state.folders[folder.Name]
	if previous == folder or (previous and previous.Parent == state.root) then
		return
	end
	if previous then
		detachFolder(state, previous)
	end
	state.folders[folder.Name] = folder
	scan(state)
	state.folderConnections[folder] = {
		folder.DescendantAdded:Connect(function()
			scheduleScan(state)
		end),
		folder.DescendantRemoving:Connect(function()
			scheduleScan(state)
		end),
		folder.AncestryChanged:Connect(function()
			if folder.Parent ~= state.root then
				detachFolder(state, folder)
			end
		end),
	}
end

local function addRoot(root: Instance)
	if roots[root] then
		return
	end
	local state: RootState = {
		root = root,
		folders = {},
		connections = {},
		folderConnections = {},
		scanQueued = false,
		platforms = {},
		lastSummary = nil,
		legacyWarned = false,
	}
	roots[root] = state
	for _, folderName in FOLDER_NAMES do
		local folder = root:FindFirstChild(folderName)
		if folder and folder:IsA("Folder") then
			attachFolder(state, folder)
		end
	end
	table.insert(
		state.connections,
		root.ChildAdded:Connect(function(child)
			if table.find(FOLDER_NAMES, child.Name) and child:IsA("Folder") then
				attachFolder(state, child)
			end
		end)
	)
	table.insert(
		state.connections,
		root.ChildRemoved:Connect(function(child)
			if child:IsA("Folder") then
				detachFolder(state, child)
			end
		end)
	)
end

local function removeRoot(root: Instance)
	local state = roots[root]
	if state == nil then
		return
	end
	roots[root] = nil
	for _, connection in state.connections do
		connection:Disconnect()
	end
	for folder, connections in state.folderConnections do
		for _, connection in connections do
			connection:Disconnect()
		end
		state.folderConnections[folder] = nil
	end
	for key in state.platforms do
		forgetGroup(state, key)
	end
end

function RotatingPlatforms.load()
	if started then
		return
	end
	started = true
	unwatch = ScriptableRoots.watch(addRoot, removeRoot)
end

function RotatingPlatforms.startMover()
	RotatingPlatforms.load()
	if moverConnection == nil then
		moverConnection = RunService.Heartbeat:Connect(step)
	end
end

local function applyClientBatch(platform: Platform, now: number): (string, string?)
	if containsSeesaw(platform.assembly) then
		return "ok", nil
	end
	local batch = platform.clientBatch :: ClientBatch
	local restParts = platform.restParts :: { RestPart }
	local pose = RotatingPlatforms.poseAt(platform, now)
	for index, entry in restParts do
		local part = entry.part
		if not part.Anchored or (part ~= platform.assembly and not part:IsDescendantOf(platform.assembly)) then
			return "invalid", "rest part left or became unanchored"
		end
		batch.frames[index] = pose * entry.relative
	end
	for _, rotor in platform.localRotors do
		local center = RotatingPlatforms.rotorPoseAt(platform, rotor, now)
		batch.frames[batch.indices[rotor.part]] = center * rotor.centerToPart
		for _, follower in rotor.followers do
			batch.frames[batch.indices[follower.part]] = center * follower.centerToPart
		end
	end
	if #batch.parts > 0 then
		local ok, reason =
			pcall(Workspace.BulkMoveTo, Workspace, batch.parts, batch.frames, Enum.BulkMoveMode.FireCFrameChanged)
		if not ok then
			return "bulkError", tostring(reason)
		end
	end
	return "ok", nil
end

local function clientStep()
	local now = Workspace:GetServerTimeNow()
	for _, platform in platforms do
		local state = platformStates[platform]
		if not failedPlatforms[platform] and not (state and state.scanQueued) then
			if platform.clientBatch and not bulkFailed[platform] then
				local ok, kind, reason = pcall(applyClientBatch, platform, now)
				if ok and kind == "invalid" then
					failedPlatforms[platform] = true
					invalidPlatforms[platform] = true
					if state then
						scheduleScan(state)
					end
					warn(`[RotatingPlatforms] local motion disabled for {platform.assembly:GetFullName()}: {reason}`)
					continue
				elseif not ok or kind == "bulkError" then
					bulkFailed[platform] = true
					warn(
						`[RotatingPlatforms] local batch disabled for {platform.assembly:GetFullName()}: {if ok
							then reason
							else kind}`
					)
				else
					continue
				end
			end
			local ok, reason = pcall(RotatingPlatforms.applyAt, platform, now)
			if not ok then
				failedPlatforms[platform] = true
				warn(`[RotatingPlatforms] local motion disabled for {platform.assembly:GetFullName()}: {reason}`)
			end
		end
	end
end

function RotatingPlatforms.startClientMover()
	if not RunService:IsClient() then
		return
	end
	RotatingPlatforms.load()
	if physicsConnection then
		return
	end
	physicsConnection = RunService.PreSimulation:Connect(clientStep)
	renderConnection = RunService.PreRender:Connect(clientStep)
	-- Attributes can arrive after streamed descendants, so revisit incomplete groups.
	retryConnection = RunService.Heartbeat:Connect(function(dt)
		retryElapsed += dt
		if retryElapsed < 2 then
			return
		end
		retryElapsed = 0
		for _, state in roots do
			scan(state)
		end
	end)
end

function RotatingPlatforms.stop()
	generation += 1
	if moverConnection then
		moverConnection:Disconnect()
		moverConnection = nil
	end
	if physicsConnection then
		physicsConnection:Disconnect()
		physicsConnection = nil
	end
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if retryConnection then
		retryConnection:Disconnect()
		retryConnection = nil
	end
	retryElapsed = 0
	table.clear(failedPlatforms)
	table.clear(invalidPlatforms)
	table.clear(bulkFailed)
	table.clear(platformStates)
	if unwatch then
		unwatch()
		unwatch = nil
	end
	for root in roots do
		removeRoot(root)
	end
	table.clear(platforms)
	table.clear(roots)
	started = false
end

return RotatingPlatforms
