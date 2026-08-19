--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapFeatures = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MapFeatures"))
local RotatingPlatforms = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("RotatingPlatforms")
)

-- Carries the local character with the rotating platform it is riding.
--
-- This runs only on the owning client: under default network ownership the
-- character's position replicates outward from here, so every other client and
-- the server see the carried position without a second mover.
--
-- The delta is measured from the assembly's own pose frame over frame, not from
-- the clock: the server drives the motion and this client sees it through
-- replication, so the pose it is standing on is the only one that matters.
-- Only position is carried, never orientation: turning the camera under a player
-- would fight aiming, and aim direction drives every throw.
--
-- Carry continues while the rider is airborne above the assembly's footprint,
-- which is what makes a jump land in the same spot relative to the platform.

local PlatformRider = {}

-- Below this the carry is skipped entirely. Assigning CFrame to an unanchored
-- root disturbs the physics solver, so a platform that has barely moved must not
-- touch the character at all or it stutters in place.
local MINIMUM_CARRY_STUDS = 1e-3

local started = false
local ridingPlatform: RotatingPlatforms.Platform? = nil
local ridingPivot: CFrame? = nil

local function ridden(rootPosition: Vector3): RotatingPlatforms.Platform?
	local config = MapFeatures.Rotating
	for _, platform in RotatingPlatforms.all() do
		-- Reject on a plain distance from the axis before paying for the bounds
		-- transform; most platforms are nowhere near the player most frames.
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
	-- Only a continuous ride carries: stepping onto a different platform starts
	-- tracking fresh rather than applying a delta accumulated elsewhere.
	if ridingPlatform == platform and ridingPivot then
		local delta = pivot * ridingPivot:Inverse()
		local current = root.CFrame
		local carried = delta * current.Position
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
