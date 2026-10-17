-- Description: Client-only cosmetic drones and balloons that appear to hold up the game's swinging hazards, animated only while on screen and nearby.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HazardCarriers = {}

-- Placement is data-driven. Offsets are expressed in the hazard's own local space
-- relative to its PIVOT (the swing axle), with +Y up and -Z along the hazard's
-- facing, so a course that faces a hazard differently still hangs its carrier the
-- same way. Orientation is taken from the hazard's HoverMount rather than the
-- swinging part, because the mount only slides and never rotates: that is what
-- keeps a carrier from swinging with its load.
type CarrierConfig = {
	Carrier: string,
	Scale: number,
	Offset: Vector3,
	EyePitchDegrees: number?,
	YawJitterDegrees: number?,
	Cable: boolean,
	CableThickness: number?,
	PerPivot: boolean?,
}

local CONFIG: { Default: CarrierConfig, ByType: { [string]: CarrierConfig }, Overrides: { [string]: any } } = {
	Default = {
		Carrier = "Drone",
		Scale = 0.35,
		Offset = Vector3.new(0, 9, 0),
		EyePitchDegrees = -35,
		YawJitterDegrees = 12,
		Cable = true,
		CableThickness = 0.28,
	},
	ByType = {
		-- Slides laterally across the lane, so it reads as powered flight rather
		-- than drift. One drone per arm pivot, flying in formation.
		Sweeper = {
			Carrier = "Drone",
			Scale = 0.30,
			Offset = Vector3.new(0, 8, 0),
			EyePitchDegrees = -45,
			YawJitterDegrees = 8,
			Cable = true,
			CableThickness = 0.24,
			PerPivot = true,
		},
		-- The balloon's moulded string reads as continuous with the mace chain, and
		-- a spiked ball slung under a party balloon is the better silhouette.
		Mace = {
			Carrier = "Balloon",
			Scale = 0.22,
			Offset = Vector3.new(0, 12, 0),
			Cable = true,
			CableThickness = 0.2,
		},
		HammerLarge = {
			Carrier = "Drone",
			Scale = 0.38,
			Offset = Vector3.new(0, 10, 0),
			EyePitchDegrees = -40,
			YawJitterDegrees = 14,
			Cable = true,
			CableThickness = 0.3,
		},
		HammerSmall = {
			Carrier = "Drone",
			Scale = 0.32,
			Offset = Vector3.new(0, 9, 0),
			EyePitchDegrees = -30,
			YawJitterDegrees = 18,
			Cable = true,
			CableThickness = 0.26,
		},
		Mallet = {
			Carrier = "Drone",
			Scale = 0.32,
			Offset = Vector3.new(0, 9, 0),
			EyePitchDegrees = -30,
			YawJitterDegrees = 18,
			Cable = true,
			CableThickness = 0.26,
		},
	},
	-- Per-instance escape hatch, keyed by the hazard part's name.
	Overrides = {},
}

local TUNING = {
	ActivateStuds = 75,
	-- Hysteresis: a carrier already running keeps running out to this range, so a
	-- player standing on the boundary does not flicker it on and off.
	DeactivateStuds = 85,
	-- Visibility and distance are re-evaluated at this rate, not every frame.
	CheckHz = 8,
	PropellerDegreesPerSecond = 720,
}

local SOURCE_TYPES = {
	obstacle_1 = "Mallet",
	obstacle_2 = "Sweeper",
	obstacle_3 = "HammerLarge",
	obstacle_4 = "HammerSmall",
	obstacle_5 = "Mace",
}

local carriers: { any } = {}
local connection: RBXScriptConnection? = nil
local discoveryConnection: RBXScriptConnection? = nil
local courseConnections: { RBXScriptConnection } = {}
local partConnections: { [BasePart]: { RBXScriptConnection } } = {}
local carrierFolder: Folder? = nil
local currentCourse: Instance? = nil
local rebuildQueued = false
local lifecycle = 0
local sinceCheck = 0

local function hash(text: string): number
	local h = 0
	for index = 1, #text do
		h = (h * 31 + string.byte(text, index)) % 100003
	end
	return h
end

local function configFor(kind: string, name: string): CarrierConfig
	local base = CONFIG.ByType[kind] or CONFIG.Default
	local override = CONFIG.Overrides[name]
	if not override then
		return base
	end
	local merged = table.clone(base)
	for key, value in override do
		(merged :: any)[key] = value
	end
	return merged
end

local function assets(): Folder?
	local folder = ReplicatedStorage:FindFirstChild("HazardCarrierAssets")
	return if folder and folder:IsA("Folder") then folder else nil
end

local function inert(instance: Instance)
	for _, part in instance:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		end
	end
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		instance.CastShadow = false
	end
end

local function scaleModel(instance: Instance, scale: number)
	if instance:IsA("Model") then
		instance:ScaleTo(scale)
	elseif instance:IsA("BasePart") then
		instance.Size = instance.Size * scale
	end
end

-- The hazard's swing axle. After the pivot fix a pendulum head's GetPivot() is its
-- axle rather than its own centre, so this is the point the carrier must hold.
local function axleOf(part: BasePart): Vector3
	return part:GetPivot().Position
end

local function buildCarrier(kind: string, hazard: BasePart, mount: BasePart, parent: Folder)
	local folder = assets()
	if not folder then
		return
	end
	local config = configFor(kind, hazard.Name)
	local sourceName = if config.Carrier == "Balloon" then "air_balloon_002" else "Drone1"
	local source = folder:FindFirstChild(sourceName)
	if not source then
		return
	end

	local model = source:Clone()
	inert(model)
	scaleModel(model, config.Scale)
	model.Name = "Carrier_" .. hazard.Name
	model.Parent = parent

	local cable: BasePart? = nil
	if config.Cable then
		local line = Instance.new("Part")
		line.Name = "Cable"
		line.Shape = Enum.PartType.Cylinder
		line.Color = Color3.fromRGB(35, 35, 40)
		line.Material = Enum.Material.SmoothPlastic
		local thickness = config.CableThickness or 0.25
		line.Size = Vector3.new(1, thickness, thickness)
		line.Anchored = true
		line.CanCollide = false
		line.CanTouch = false
		line.CanQuery = false
		line.CastShadow = false
		line.Parent = parent
		cable = line
	end

	local seed = hash(hazard.Name)
	table.insert(carriers, {
		kind = kind,
		config = config,
		hazard = hazard,
		mount = mount,
		model = model,
		cable = cable,
		propeller = if model:IsA("Model") then model:FindFirstChild("drone_propeller_001", true) else nil,
		eye = if model:IsA("Model") then model:FindFirstChild("drone_eye_001", true) else nil,
		yaw = math.rad(((seed % 200) / 100 - 1) * (config.YawJitterDegrees or 0)),
		spin = (seed % 360),
		active = false,
	})
end

local function place(entry: any)
	local hazard, mount = entry.hazard, entry.mount
	if not hazard.Parent or not mount.Parent then
		return
	end
	-- Position from the axle, orientation from the mount: the mount slides with the
	-- hover but never rotates, so the carrier tracks the bob without swinging.
	local anchor = axleOf(hazard)
	local facing = mount.CFrame - mount.CFrame.Position
	local base = CFrame.new(anchor) * facing * CFrame.Angles(0, entry.yaw, 0)
	local carrierCFrame = base * CFrame.new(entry.config.Offset)

	if entry.model:IsA("Model") then
		entry.model:PivotTo(carrierCFrame)
	else
		entry.model.CFrame = carrierCFrame
	end

	local cable = entry.cable
	if cable then
		local top = carrierCFrame.Position
		local span = top - anchor
		local length = span.Magnitude
		if length > 0.05 then
			local thickness = entry.config.CableThickness or 0.25
			-- A cylinder's length runs along its own X, so aim that axis down the span.
			cable.Size = Vector3.new(length, thickness, thickness)
			cable.CFrame = CFrame.lookAt(anchor + span * 0.5, top) * CFrame.Angles(0, math.rad(90), 0)
		end
	end
end

local function pose(entry: any, delta: number)
	local propeller = entry.propeller
	if propeller and propeller:IsA("BasePart") then
		entry.spin = (entry.spin + TUNING.PropellerDegreesPerSecond * delta) % 360
		local parentPivot = if entry.model:IsA("Model") then entry.model:GetPivot() else entry.model.CFrame
		local offset = entry.propellerOffset
		if not offset then
			offset = parentPivot:ToObjectSpace(propeller.CFrame)
			entry.propellerOffset = offset
		end
		propeller.CFrame = parentPivot * offset * CFrame.Angles(0, math.rad(entry.spin), 0)
	end
	local eye = entry.eye
	if eye and eye:IsA("BasePart") and entry.config.EyePitchDegrees then
		local parentPivot = if entry.model:IsA("Model") then entry.model:GetPivot() else entry.model.CFrame
		local offset = entry.eyeOffset
		if not offset then
			offset = parentPivot:ToObjectSpace(eye.CFrame)
			entry.eyeOffset = offset
		end
		eye.CFrame = parentPivot * offset * CFrame.Angles(math.rad(entry.config.EyePitchDegrees), 0, 0)
	end
end

local function visible(entry: any, camera: Camera): boolean
	local anchor = axleOf(entry.hazard)
	local distance = (camera.CFrame.Position - anchor).Magnitude
	local limit = if entry.active then TUNING.DeactivateStuds else TUNING.ActivateStuds
	if distance > limit then
		return false
	end
	local _, onScreen = camera:WorldToViewportPoint(anchor)
	return onScreen
end

local function clearCarriers()
	for _, entry in carriers do
		if entry.model then
			entry.model:Destroy()
		end
		if entry.cable then
			entry.cable:Destroy()
		end
	end
	table.clear(carriers)
end

local function clearCourseWatch()
	for _, courseConnection in courseConnections do
		courseConnection:Disconnect()
	end
	table.clear(courseConnections)
	for _, connections in partConnections do
		for _, partConnection in connections do
			partConnection:Disconnect()
		end
	end
	table.clear(partConnections)
	currentCourse = nil
end

local function findCourse(): Instance?
	local rootAssets = workspace:FindFirstChild("Assets")
	local arena = rootAssets and rootAssets:FindFirstChild("Arena")
	return arena and arena:FindFirstChild("SplashdownCourse") or nil
end

local function discover(course: Instance)
	local parent = carrierFolder
	if not parent or not course:IsDescendantOf(workspace) then
		return
	end
	clearCarriers()
	-- Discovery keys on the hazard's identity, not its motion mode: a pendulum is a
	-- "rock" rotor but the spiked roller is a slide parent with a spin child.
	for _, mount in course:GetDescendants() do
		if mount:IsA("BasePart") and mount.Name == "HoverMount" then
			local kind, swing = nil, nil
			for _, part in mount:GetDescendants() do
				if part:IsA("BasePart") then
					if not kind then
						local source = tostring(part:GetAttribute("SourceAsset")):match("^(obstacle_%d+)")
						kind = source and SOURCE_TYPES[source] or nil
					end
					if not swing and part:GetAttribute("Rotor") == "rock" then
						swing = part
					end
				end
			end
			if kind then
				buildCarrier(kind, (swing or mount) :: BasePart, mount, parent)
			end
		end
	end
	for _, entry in carriers do
		place(entry)
	end
end

local queueRebuild: () -> ()

local function watchCoursePart(part: BasePart)
	if partConnections[part] then
		return
	end
	partConnections[part] = {
		part:GetAttributeChangedSignal("SourceAsset"):Connect(queueRebuild),
		part:GetAttributeChangedSignal("Rotor"):Connect(queueRebuild),
	}
end

local function unwatchCoursePart(part: BasePart)
	local connections = partConnections[part]
	if not connections then
		return
	end
	for _, partConnection in connections do
		partConnection:Disconnect()
	end
	partConnections[part] = nil
end

queueRebuild = function()
	if rebuildQueued then
		return
	end
	rebuildQueued = true
	local queuedLifecycle = lifecycle
	task.defer(function()
		if queuedLifecycle ~= lifecycle then
			return
		end
		rebuildQueued = false
		local course = findCourse()
		if course ~= currentCourse then
			clearCourseWatch()
			clearCarriers()
			currentCourse = course
			if course then
				table.insert(
					courseConnections,
					course.DescendantAdded:Connect(function(instance)
						if instance:IsA("BasePart") then
							watchCoursePart(instance)
							queueRebuild()
						elseif instance.Name == "HoverMount" then
							queueRebuild()
						end
					end)
				)
				table.insert(
					courseConnections,
					course.DescendantRemoving:Connect(function(instance)
						if instance:IsA("BasePart") then
							unwatchCoursePart(instance)
							queueRebuild()
						elseif instance.Name == "HoverMount" then
							queueRebuild()
						end
					end)
				)
				table.insert(
					courseConnections,
					course.AncestryChanged:Connect(function()
						if not course:IsDescendantOf(workspace) then
							queueRebuild()
						end
					end)
				)
				for _, instance in course:GetDescendants() do
					if instance:IsA("BasePart") then
						watchCoursePart(instance)
					end
				end
			end
		end
		if course then
			discover(course)
		end
	end)
end

function HazardCarriers.start()
	HazardCarriers.stop()
	lifecycle += 1
	discoveryConnection = workspace.DescendantAdded:Connect(function(instance)
		if instance.Name == "SplashdownCourse" then
			queueRebuild()
		end
	end)

	local parent = Instance.new("Folder")
	parent.Name = "HazardCarriers"
	-- Keep the cosmetic world-owned: replacing CurrentCamera must not orphan it.
	parent.Parent = workspace
	carrierFolder = parent
	queueRebuild()

	connection = RunService.RenderStepped:Connect(function(delta: number)
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		sinceCheck += delta
		local recheck = sinceCheck >= 1 / TUNING.CheckHz
		if recheck then
			sinceCheck = 0
		end
		for _, entry in carriers do
			if recheck then
				entry.active = visible(entry, camera)
			end
			if entry.active then
				place(entry)
				pose(entry, delta)
			end
		end
	end)
end

function HazardCarriers.stop()
	lifecycle += 1
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if discoveryConnection then
		discoveryConnection:Disconnect()
		discoveryConnection = nil
	end
	clearCourseWatch()
	clearCarriers()
	if carrierFolder then
		carrierFolder:Destroy()
	end
	carrierFolder = nil
	rebuildQueued = false
	sinceCheck = 0
end

return HazardCarriers
