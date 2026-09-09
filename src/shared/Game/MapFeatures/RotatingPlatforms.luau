-- Description: Spins the authored rotating platform assemblies from a pure function of the synchronized clock, with a server-only mover and a client-side load so both sides agree without fighting over the same anchored parts.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Rotation = require(script.Parent.Rotation)

local RotatingPlatforms = {}

local FOLDER_NAME = "Rotating"

export type LocalRotor = {
	part: BasePart,
	relativeCenter: CFrame,
	centerToPart: CFrame,
	axis: "X" | "Y",
	mode: "spin" | "rock",
	degreesPerSecond: number,
	amplitude: number,
	period: number,
	phase: number,
	carriesRiders: boolean,
}

type RotorOptions = {
	axis: "X" | "Y",
	mode: "spin" | "rock",
	degreesPerSecond: number?,
	amplitude: number?,
	period: number?,
	phase: number?,
	carriesRiders: boolean,
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

local platforms: { Platform } = {}
local byFolder: { [Folder]: Platform } = {}
local watchConnections: { RBXScriptConnection } = {}
local moverConnection: RBXScriptConnection? = nil
local started = false
local generation = 0

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

function RotatingPlatforms.rotorFor(part: BasePart): (Platform?, LocalRotor?)
	for _, platform in platforms do
		for _, rotor in platform.localRotors do
			if rotor.part == part and rotor.carriesRiders then
				return platform, rotor
			end
		end
	end
	return nil, nil
end

local MINIMUM_TURN_RADIANS = 1e-5

local function rotorSpin(rotor: LocalRotor, now: number): CFrame
	local a = if rotor.mode == "rock"
		then Rotation.rockAt(now, rotor.amplitude, rotor.period, rotor.phase)
		else Rotation.angleAt(now, rotor.degreesPerSecond)
	if rotor.axis == "X" then
		return CFrame.Angles(a, 0, 0)
	end
	return CFrame.Angles(0, a, 0)
end

function RotatingPlatforms.rotorPoseAt(platform: Platform, rotor: LocalRotor, now: number): CFrame
	return RotatingPlatforms.poseAt(platform, now) * rotor.relativeCenter * rotorSpin(rotor, now)
end

local function step()
	local now = Workspace:GetServerTimeNow()
	for _, platform in platforms do
		local angle = Rotation.angleAt(now, platform.degreesPerSecond)
		local pose = platform.origin.CFrame * CFrame.Angles(0, angle, 0) * platform.relativePivot
		if platform.appliedAngle == nil or math.abs(angle - platform.appliedAngle) >= MINIMUM_TURN_RADIANS then
			platform.appliedAngle = angle
			platform.assembly:PivotTo(pose)
		end
		-- One server mover composes the ring with its fan blades, paddles, discs, and swing panels.
		for _, rotor in platform.localRotors do
			if rotor.part:IsDescendantOf(platform.assembly) then
				rotor.part.CFrame = pose * rotor.relativeCenter * rotorSpin(rotor, now) * rotor.centerToPart
			end
		end
	end
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
			axis = options.axis,
			mode = options.mode,
			degreesPerSecond = options.degreesPerSecond or 0,
			amplitude = options.amplitude or 0,
			period = options.period or 1,
			phase = options.phase or 0,
			carriesRiders = options.carriesRiders,
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
		if MapFeatures.Fan.EnabledNames[base.Name] then
			for _, blade in base:GetChildren() do
				if blade:IsA("BasePart") and blade.Name:find("propeller_trampoline_2_", 1, true) == 1 then
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

local function forget(child: Instance)
	if not child:IsA("Folder") then
		return
	end
	local platform = byFolder[child]
	if platform == nil then
		return
	end
	byFolder[child] = nil
	local index = table.find(platforms, platform)
	if index then
		table.remove(platforms, index)
	end
end

-- Origin and Assembly stream in independently of their parent Folder, so each platform builds off the main thread and only joins the live list once both have arrived; a build resolving after a stop() is dropped by the generation guard.
local function track(child: Instance)
	if not child:IsA("Folder") then
		return
	end
	if byFolder[child] then
		return
	end
	local folder = child
	local currentGeneration = generation
	task.spawn(function()
		local origin = folder:WaitForChild("Origin")
		local assembly = folder:WaitForChild("Assembly")
		if not started or generation ~= currentGeneration or folder.Parent == nil or byFolder[folder] then
			return
		end
		assert(origin:IsA("BasePart"), `[RotatingPlatforms] {folder.Name}.Origin must be a BasePart`)
		assert(assembly:IsA("Model"), `[RotatingPlatforms] {folder.Name}.Assembly must be a Model`)
		local platform = build(origin, assembly)
		byFolder[folder] = platform
		table.insert(platforms, platform)
	end)
end

function RotatingPlatforms.load()
	if started then
		return
	end
	started = true

	local scriptables = Workspace:WaitForChild("Assets"):WaitForChild("Arena"):WaitForChild("Scriptables")
	local folder = scriptables:FindFirstChild(FOLDER_NAME)
	if folder == nil or not folder:IsA("Folder") then
		warn(`[RotatingPlatforms] No Scriptables.{FOLDER_NAME} Folder authored; feature inactive`)
		return
	end

	for _, child in folder:GetChildren() do
		track(child)
	end
	table.insert(watchConnections, folder.ChildAdded:Connect(track))
	table.insert(watchConnections, folder.ChildRemoved:Connect(forget))
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
	for _, connection in watchConnections do
		connection:Disconnect()
	end
	table.clear(watchConnections)
	table.clear(platforms)
	table.clear(byFolder)
	started = false
end

return RotatingPlatforms
