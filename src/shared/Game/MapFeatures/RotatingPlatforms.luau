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

local FOLDER_NAME = "Rotating"
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
	origin: BasePart,
	assembly: Model,
	relativePivot: CFrame,
	degreesPerSecond: number,
	boundsSize: Vector3,
	pivotToBounds: CFrame,
	reach: number,
	appliedAngle: number?,
	localRotors: { LocalRotor },
}

type RootState = {
	folder: Folder?,
	connections: { RBXScriptConnection },
	platforms: { [Folder]: Platform },
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
	return platform.origin.CFrame * CFrame.Angles(0, angle, 0) * platform.relativePivot
end

function RotatingPlatforms.all(): { Platform }
	return platforms
end

function RotatingPlatforms.currentBounds(platform: Platform): CFrame
	return platform.assembly:GetPivot() * platform.pivotToBounds
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
		local epoch = tonumber(platform.origin:GetAttribute(Attributes.MotionEpoch))
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
	local ringAxis = platform.origin.CFrame.UpVector * math.rad(platform.degreesPerSecond)
	local velocity = ringAxis:Cross(position - platform.origin.Position)
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
	local pose = platform.origin.CFrame * CFrame.Angles(0, angle, 0) * platform.relativePivot
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
	if mode ~= "spin" and mode ~= "rock" and mode ~= "slide" then
		return nil
	end
	local axis = part:GetAttribute(Attributes.RotorAxis)
	local amplitude = tonumber(part:GetAttribute(Attributes.RotorAmplitude)) or 0
	local profile = part:GetAttribute(Attributes.RotorProfile)
	local period = math.max(tonumber(part:GetAttribute(Attributes.RotorPeriod)) or 1, 0.05)
	local phase = tonumber(part:GetAttribute(Attributes.RotorPhase)) or 0
	if profile == "piston" and mode == "slide" then
		period = math.max(tonumber(part:GetAttribute(Attributes.PistonPeriod)) or MapFeatures.Piston.PeriodSeconds, 0.1)
		amplitude = tonumber(part:GetAttribute(Attributes.PistonExtendStuds)) or MapFeatures.Piston.ExtendStuds
		phase = tonumber(part:GetAttribute(Attributes.PistonPhase)) or 0
	elseif profile ~= "hammer" or mode ~= "rock" then
		profile = nil
	end
	return {
		axis = if axis == "X" or axis == "Z" then axis else "Y",
		mode = mode,
		degreesPerSecond = tonumber(part:GetAttribute(Attributes.RotorSpeed)) or 0,
		amplitude = if mode == "slide" then amplitude else math.rad(amplitude),
		period = period,
		phase = phase,
		profile = profile :: string?,
		windup = math.max(
			tonumber(part:GetAttribute(Attributes.WindupSeconds)) or MapFeatures.Hammer.WindupSeconds,
			0.05
		),
		strike = math.max(
			tonumber(part:GetAttribute(Attributes.StrikeSeconds)) or MapFeatures.Hammer.StrikeSeconds,
			0.05
		),
		hold = math.clamp(
			tonumber(part:GetAttribute(Attributes.HoldSeconds)) or MapFeatures.Piston.HoldSeconds,
			0,
			period - 0.05
		),
		acceleration = tonumber(part:GetAttribute(Attributes.RotorAccel)) or 0,
		phaseDegrees = tonumber(part:GetAttribute(Attributes.RotorPhaseDegrees)) or 0,
		carriesRiders = part:GetAttribute(Attributes.RotorCarries) == true,
		shove = part:GetAttribute(Attributes.Shove) == true,
		shoveSpeed = tonumber(part:GetAttribute(Attributes.ShoveSpeed)),
	}
end

local function isFan(base: BasePart): boolean
	return MapFeatures.Fan.EnabledNames[base.Name] == true or base:GetAttribute(Attributes.Fan) == true
end

local function isFanBlade(blade: BasePart): boolean
	return blade.Name:find("propeller_trampoline_2_", 1, true) == 1 or blade:GetAttribute(Attributes.FanBlade) == true
end

local function build(origin: BasePart, assembly: Model): Platform
	local pivot = assembly:GetPivot()
	local boundsCFrame, boundsSize = assembly:GetBoundingBox()
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
	for _, base in assembly:GetDescendants() do
		if not base:IsA("BasePart") then
			continue
		end
		if MapFeatures.Spinner.EnabledNames[base.Name] then
			local center = CFrame.new(base.CFrame:PointToWorldSpace(base.PivotOffset.Position))
			addRotor(base, center, {
				axis = "Y",
				mode = "spin",
				degreesPerSecond = MapFeatures.Spinner.DegreesPerSecond,
				carriesRiders = false,
			})
		end
		if isFan(base) then
			for _, blade in base:GetChildren() do
				if blade:IsA("BasePart") and isFanBlade(blade) then
					local center = CFrame.new(blade.CFrame:PointToWorldSpace(blade.PivotOffset.Position))
					addRotor(blade, center, {
						axis = "Y",
						mode = "spin",
						degreesPerSecond = MapFeatures.Fan.BladeDegreesPerSecond,
						carriesRiders = false,
					})
				end
			end
		end
		if base.Name:find(MapFeatures.Disc.HubPrefix, 1, true) == 1 then
			for _, plate in base:GetChildren() do
				if plate:IsA("BasePart") and plate.Name:find(MapFeatures.Disc.PlatePrefix, 1, true) == 1 then
					addRotor(plate, CFrame.new(plate.Position), {
						axis = "Y",
						mode = "spin",
						degreesPerSecond = MapFeatures.Disc.DegreesPerSecond,
						carriesRiders = true,
					})
				end
			end
		end
		if base.Name:find(MapFeatures.SwingPanel.AxlePrefix, 1, true) == 1 then
			local suffix = tonumber(base.Name:match("%.(%d+)$")) or 0
			for _, panel in base:GetChildren() do
				if panel:IsA("BasePart") and panel.Name:find(MapFeatures.SwingPanel.PanelPrefix, 1, true) == 1 then
					addRotor(panel, CFrame.new(base.Position), {
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
			local center = base:GetPivot()
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

	return {
		origin = origin,
		assembly = assembly,
		relativePivot = origin.CFrame:Inverse() * pivot,
		degreesPerSecond = (origin:GetAttribute("RotationSpeed") :: number?) or MapFeatures.Rotating.DegreesPerSecond,
		boundsSize = boundsSize,
		pivotToBounds = pivot:Inverse() * boundsCFrame,
		reach = (boundsCFrame.Position - origin.Position).Magnitude + boundsSize.Magnitude / 2,
		localRotors = localRotors,
	}
end

-- Builds a snapshot without registering a heartbeat or modifying geometry.
-- Useful to builders/validators and deterministic engine tests.
RotatingPlatforms.build = build

local function forgetGroup(state: RootState, child: Instance)
	if not child:IsA("Folder") then
		return
	end
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

-- Origin and Assembly stream in independently of their parent Folder, so each platform builds off the main thread and only joins the live list once both have arrived; a build resolving after a stop() is dropped by the generation guard.
local function trackGroup(state: RootState, child: Instance)
	if not child:IsA("Folder") then
		return
	end
	if state.platforms[child] then
		return
	end
	local folder = child
	local currentGeneration = generation
	task.spawn(function()
		local origin = folder:WaitForChild("Origin")
		local assembly = folder:WaitForChild("Assembly")
		if
			not started
			or generation ~= currentGeneration
			or folder.Parent == nil
			or state.platforms[folder]
			or roots[folder.Parent.Parent :: Instance] ~= state
		then
			return
		end
		assert(origin:IsA("BasePart"), `[RotatingPlatforms] {folder.Name}.Origin must be a BasePart`)
		assert(assembly:IsA("Model"), `[RotatingPlatforms] {folder.Name}.Assembly must be a Model`)
		local platform = build(origin, assembly)
		state.platforms[folder] = platform
		table.insert(platforms, platform)
	end)
end

local function attachFolder(state: RootState, folder: Folder)
	if state.folder ~= nil then
		return
	end
	state.folder = folder
	for _, child in folder:GetChildren() do
		trackGroup(state, child)
	end
	table.insert(
		state.connections,
		folder.ChildAdded:Connect(function(child)
			trackGroup(state, child)
		end)
	)
	table.insert(
		state.connections,
		folder.ChildRemoved:Connect(function(child)
			forgetGroup(state, child)
		end)
	)
end

local function addRoot(root: Instance)
	if roots[root] then
		return
	end
	local state: RootState = { folder = nil, connections = {}, platforms = {} }
	roots[root] = state
	local folder = root:FindFirstChild(FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		attachFolder(state, folder)
	end
	table.insert(
		state.connections,
		root.ChildAdded:Connect(function(child)
			if child.Name == FOLDER_NAME and child:IsA("Folder") then
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
	for folder in state.platforms do
		forgetGroup(state, folder)
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
