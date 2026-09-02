-- Name: PlatformRider.luau
-- Author: Jack C.
-- Description: Carries the local character along with a rotating arena platform it is standing on or airborne above, measuring the platform's own pose change frame to frame so replication lag cannot desync the ride.
-- Created: 2026-08-18

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local RotatingPlatforms = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("RotatingPlatforms")
)

local PlatformRider = {}

local MINIMUM_CARRY_STUDS = 1e-3

local started = false
local ridingPlatform: RotatingPlatforms.Platform? = nil
local ridingPivot: CFrame? = nil

local function ridden(rootPosition: Vector3): RotatingPlatforms.Platform?
	local config = MapFeatures.Rotating
	for _, platform in RotatingPlatforms.all() do
		if (rootPosition - platform.origin.Position).Magnitude > platform.reach + config.CarryHeight then
			continue
		end
		local offset = RotatingPlatforms.currentBounds(platform):PointToObjectSpace(rootPosition)
		local size = platform.boundsSize
		local top = size.Y / 2
		if
			math.abs(offset.X) <= size.X / 2
			and math.abs(offset.Z) <= size.Z / 2
			and offset.Y >= top - config.CarryDepthTolerance
			and offset.Y <= top + config.CarryHeight
		then
			return platform
		end
	end
	return nil
end

local function step()
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local alive = character ~= nil and character:GetAttribute("CombatAlive") ~= false
	if not alive or root == nil or not root:IsA("BasePart") then
		ridingPlatform = nil
		ridingPivot = nil
		return
	end

	local platform = ridden(root.Position)
	if platform == nil then
		ridingPlatform = nil
		ridingPivot = nil
		return
	end

	local pivot = platform.assembly:GetPivot()
	if ridingPlatform == platform and ridingPivot then
		local current = root.CFrame
		local localOffset = ridingPivot:Inverse() * current.Position
		local carried = pivot * localOffset
		if (carried - current.Position).Magnitude >= MINIMUM_CARRY_STUDS then
			root.CFrame = CFrame.new(carried) * current.Rotation
		end
	end
	ridingPlatform = platform
	ridingPivot = pivot
end

function PlatformRider.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(step)
end

return PlatformRider
