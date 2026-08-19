--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapFeatures = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MapFeatures"))
local Rotation = require(script.Parent.Rotation)

-- Spins each assembly authored under Workspace.Assets.Arena.Scriptables.Rotating.
-- Every child folder there is one assembly: an "Origin" BasePart whose up axis is
-- the axis of rotation, and an "Assembly" Model that turns about it. The
-- Assembly keeps the pose it was authored in relative to Origin.
--
-- Only the server drives the motion; clients receive the pose through ordinary
-- replication. Both sides moving the same anchored assembly would fight, with
-- each write undone by the other's, so `load` builds the registry everywhere but
-- `startMover` is server-only.
--
-- Speed is Config.MapFeatures.Rotating.DegreesPerSecond, overridable per
-- assembly with a numeric "RotationSpeed" attribute on that assembly's Origin.

local RotatingPlatforms = {}

local FOLDER_NAME = "Rotating"

export type Platform = {
	origin: BasePart,
	assembly: Model,
	relativePivot: CFrame,
	degreesPerSecond: number,
	boundsSize: Vector3,
	pivotToBounds: CFrame,
	reach: number,
	appliedAngle: number?,
}

local platforms: { Platform } = {}
local connection: RBXScriptConnection? = nil
local started = false

function RotatingPlatforms.poseAt(platform: Platform, now: number): CFrame
	local angle = Rotation.angleAt(now, platform.degreesPerSecond)
	return platform.origin.CFrame * CFrame.Angles(0, angle, 0) * platform.relativePivot
end

function RotatingPlatforms.all(): { Platform }
	return platforms
end

-- Bounds of the assembly where it actually is, not where the clock says it
-- should be: on a client that is the replicated pose, which is what the player
-- is standing on.
function RotatingPlatforms.currentBounds(platform: Platform): CFrame
	return platform.assembly:GetPivot() * platform.pivotToBounds
end

-- Re-posing an assembly that has not turned is wasted work on every descendant,
-- and re-seats the ground contact of anyone standing on it.
local MINIMUM_TURN_RADIANS = 1e-5

local function step()
	local now = Workspace:GetServerTimeNow()
	for _, platform in platforms do
		local angle = Rotation.angleAt(now, platform.degreesPerSecond)
		if platform.appliedAngle == nil or math.abs(angle - platform.appliedAngle) >= MINIMUM_TURN_RADIANS then
			platform.appliedAngle = angle
			platform.assembly:PivotTo(platform.origin.CFrame * CFrame.Angles(0, angle, 0) * platform.relativePivot)
		end
	end
end

local function build(folder: Folder): Platform
	local origin = folder:WaitForChild("Origin")
	assert(origin:IsA("BasePart"), `[RotatingPlatforms] {folder.Name}.Origin must be a BasePart`)
	local assembly = folder:WaitForChild("Assembly")
	assert(assembly:IsA("Model"), `[RotatingPlatforms] {folder.Name}.Assembly must be a Model`)

	local pivot = assembly:GetPivot()
	local boundsCFrame, boundsSize = assembly:GetBoundingBox()

	return {
		origin = origin,
		assembly = assembly,
		relativePivot = origin.CFrame:Inverse() * pivot,
		degreesPerSecond = (origin:GetAttribute("RotationSpeed") :: number?) or MapFeatures.Rotating.DegreesPerSecond,
		boundsSize = boundsSize,
		pivotToBounds = pivot:Inverse() * boundsCFrame,
		-- Farthest the assembly can ever be from its axis. Constant because it
		-- only rotates about that axis, so it makes a cheap rejection test.
		reach = (boundsCFrame.Position - origin.Position).Magnitude + boundsSize.Magnitude / 2,
	}
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
		if child:IsA("Folder") then
			table.insert(platforms, build(child))
		end
	end
end

function RotatingPlatforms.startMover()
	RotatingPlatforms.load()
	if connection == nil and #platforms > 0 then
		connection = RunService.Heartbeat:Connect(step)
	end
end

function RotatingPlatforms.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	table.clear(platforms)
	started = false
end

return RotatingPlatforms
