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

type LocalRotor = {
	part: BasePart,
	relativeCenter: CFrame,
	centerToPart: CFrame,
	degreesPerSecond: number,
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

local MINIMUM_TURN_RADIANS = 1e-5

local function step()
	local now = Workspace:GetServerTimeNow()
	for _, platform in platforms do
		local angle = Rotation.angleAt(now, platform.degreesPerSecond)
		local pose = platform.origin.CFrame * CFrame.Angles(0, angle, 0) * platform.relativePivot
		if platform.appliedAngle == nil or math.abs(angle - platform.appliedAngle) >= MINIMUM_TURN_RADIANS then
			platform.appliedAngle = angle
			platform.assembly:PivotTo(pose)
		end
		-- One server mover composes the ring with its fan blades and paddles.
		for _, rotor in platform.localRotors do
			if rotor.part:IsDescendantOf(platform.assembly) then
				local localAngle = Rotation.angleAt(now, rotor.degreesPerSecond)
				rotor.part.CFrame = pose * rotor.relativeCenter * CFrame.Angles(0, localAngle, 0) * rotor.centerToPart
			end
		end
	end
end

local function build(origin: BasePart, assembly: Model): Platform
	local pivot = assembly:GetPivot()
	local boundsCFrame, boundsSize = assembly:GetBoundingBox()
	local localRotors: { LocalRotor } = {}
	local function addRotor(part: BasePart, degreesPerSecond: number)
		-- Imported pivot orientations are arbitrary; use only the authored center
		-- so the local rotation stays around world up within the moving ring.
		local center = CFrame.new(part.CFrame:PointToWorldSpace(part.PivotOffset.Position))
		table.insert(localRotors, {
			part = part,
			relativeCenter = pivot:ToObjectSpace(center),
			centerToPart = center:ToObjectSpace(part.CFrame),
			degreesPerSecond = degreesPerSecond,
		})
	end
	for _, base in assembly:GetDescendants() do
		if not base:IsA("BasePart") then
			continue
		end
		if MapFeatures.Spinner.EnabledNames[base.Name] then
			addRotor(base, MapFeatures.Spinner.DegreesPerSecond)
		end
		if MapFeatures.Fan.EnabledNames[base.Name] then
			for _, blade in base:GetChildren() do
				if blade:IsA("BasePart") and blade.Name:find("propeller_trampoline_2_", 1, true) == 1 then
					addRotor(blade, MapFeatures.Fan.BladeDegreesPerSecond)
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
