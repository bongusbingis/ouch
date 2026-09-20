-- Description: Spins the authored rotating platform assemblies from a pure function of the synchronized clock, with a server-only mover and a client-side load so both sides agree without fighting over the same anchored parts; follows every tagged Scriptables root, and drives both the arena's name-listed rotors and attribute-declared course rotors that spin, rock or slide with their descendants.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
}

type RootState = {
	root: Instance,
	folders: { [string]: Folder },
	connections: { RBXScriptConnection },
	platforms: { [Instance]: Platform },
	lastSummary: string?,
	legacyWarned: boolean,
}

local platforms: { Platform } = {}
local roots: { [Instance]: RootState } = {}
local unwatch: (() -> ())? = nil
local moverConnection: RBXScriptConnection? = nil
local started = false
local generation = 0

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
	local angle = Rotation.angleAt(now, platform.degreesPerSecond)
	local pose = platform.motionPivot * CFrame.Angles(0, angle, 0) * platform.relativePivot
	if platform.appliedAngle == nil or math.abs(angle - platform.appliedAngle) >= MINIMUM_TURN_RADIANS then
		platform.appliedAngle = angle
		platform.assembly:PivotTo(pose)
	end
	-- One server mover composes the ring with its fan blades, paddles, discs, and swing panels.
	for _, rotor in platform.localRotors do
		if rotor.part:IsDescendantOf(platform.assembly) then
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
	local amplitude = if mode == "spin"
		then optionalNumber(Attributes.RotorAmplitude, 0)
		else requiredNumber(Attributes.RotorAmplitude, 0)
	local profile = part:GetAttribute(Attributes.RotorProfile)
	local period = requiredNumber(Attributes.RotorPeriod, 0.05)
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
	assert(hold >= 0 and hold < period, `[RotatingPlatforms] {part:GetFullName()}.HoldSeconds must be less than its period`)
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

local function isFanBlade(blade: BasePart): boolean
	return blade.Name:find("propeller_trampoline_2_", 1, true) == 1 or blade:GetAttribute(Attributes.FanBlade) == true
end

local function getBounds(instance: Model | BasePart): (CFrame, Vector3)
	if instance:IsA("Model") then
		return instance:GetBoundingBox()
	elseif instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end
	return CFrame.identity, Vector3.zero
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
	if allowLegacy and isFan(base) then
			local fanAxis = base:GetAttribute(Attributes.FanAxis)
			local axis: Axis = if fanAxis == "X" or fanAxis == "Z" then fanAxis else "Y"
			for _, blade in base:GetChildren() do
				if blade:IsA("BasePart") and isFanBlade(blade) then
					-- Carry the fan's own rotation into the centre so the blade spins about
					-- the fan's local axis, matching FanUpdraft's local-axis airflow, instead
					-- of always turning about world Y regardless of how the fan is pitched.
					local center = base.CFrame.Rotation + blade.CFrame:PointToWorldSpace(blade.PivotOffset.Position)
					addRotor(blade, center, {
						axis = axis,
						mode = "spin",
						degreesPerSecond = MapFeatures.Fan.BladeDegreesPerSecond,
						carriesRiders = false,
					})
				end
			end
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
				if descendant:IsA("BasePart") then
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
		while ancestor and ancestor ~= assembly do
			if ancestor:IsA("BasePart") and byPart[ancestor] then
				return byPart[ancestor]
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

local function forgetGroup(state: RootState, child: Instance)
	local platform = state.platforms[child]
	if platform == nil then
		return
	end
	state.platforms[child] = nil
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
				attributeRotor(descendant) ~= nil
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
	return attributeRotor(part) ~= nil
		or (allowLegacy and MapFeatures.Spinner.EnabledNames[part.Name] == true)
		or (allowLegacy and isFan(part))
		or (allowLegacy and part.Name:find(MapFeatures.Disc.HubPrefix, 1, true) == 1)
		or (allowLegacy and part.Name:find(MapFeatures.SwingPanel.AxlePrefix, 1, true) == 1)
end

local function register(state: RootState, key: Instance, assembly: Model | BasePart, legacyOrigin: BasePart?)
	if state.platforms[key] then
		return
	end
	local platform = build(assembly, legacyOrigin)
	state.platforms[key] = platform
	table.insert(platforms, platform)
end

local function scan(state: RootState)
	if not started or roots[state.root] ~= state or not state.root:IsDescendantOf(Workspace) then
		return
	end
	local seen: { [Instance]: boolean } = {}
	local legacy: { [Instance]: { origin: BasePart, assembly: Model | BasePart } } = {}
	local rejected = 0
	local allowLegacy = isArenaCompatibilityRoot(state.root)
	if state.folders.Rotating and not state.legacyWarned then
		state.legacyWarned = true
		if allowLegacy then
			warn(`[RotatingPlatforms] WARN temporary Arena legacy motion: {state.root:GetFullName()}.Rotating`)
		else
			warn(`[RotatingPlatforms] ERROR legacy Rotating root rejected outside Arena: {state.root:GetFullName()}`)
		end
	end
	if allowLegacy then
		for _, folder in state.folders do
			for _, child in folder:GetChildren() do
				local origin = child:FindFirstChild("Origin")
				local assembly = child:FindFirstChild("Assembly")
				if origin and origin:IsA("BasePart") and assembly and (assembly:IsA("Model") or assembly:IsA("BasePart")) then
					legacy[child] = { origin = origin, assembly = assembly :: Model | BasePart }
				elseif origin ~= nil or assembly ~= nil then
					rejected += 1
					warn(`[RotatingPlatforms] rejected malformed legacy group {child:GetFullName()}`)
				end
			end
		end
	end
	local candidates = 0
	for _, folder in state.folders do
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
			register(state, candidate, candidate :: Model | BasePart, nil)
		end
	 end
	end
	-- Explicitly bounded legacy adapter: only a direct Rotating child with both
	-- named members is treated as an old group. Category folders are ignored.
	for child, entry in legacy do
		seen[child] = true
		register(state, child, entry.assembly, entry.origin)
	end
	for key in state.platforms do
		local inMotionFolder = false
		for _, folder in state.folders do
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
		if candidates > 0 and registeredCount == 0 then
			warn(
				`[RotatingPlatforms] motion markers found but no platforms registered under {state.root:GetFullName()}`
			)
		end
	end
end

local function attachFolder(state: RootState, folder: Folder)
	if state.folders[folder.Name] ~= nil then
		return
	end
	state.folders[folder.Name] = folder
	scan(state)
	table.insert(
		state.connections,
		folder.DescendantAdded:Connect(function()
			task.defer(scan, state)
		end)
	)
	table.insert(
		state.connections,
		folder.DescendantRemoving:Connect(function()
			task.defer(scan, state)
		end)
	)
end

local function addRoot(root: Instance)
	if roots[root] then
		return
	end
	local state: RootState = {
		root = root,
		folders = {},
		connections = {},
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

function RotatingPlatforms.stop()
	generation += 1
	if moverConnection then
		moverConnection:Disconnect()
		moverConnection = nil
	end
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
