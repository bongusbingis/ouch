--!strict
-- Carries a local rider only after support contact; airborne carry cannot acquire a platform.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Features = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MapFeatures")
local RotatingPlatforms = require(Features:WaitForChild("RotatingPlatforms"))
local RiderSupport = require(Features:WaitForChild("RiderSupport"))

local PlatformRider = {}
local connection: RBXScriptConnection? = nil
local ridingPlatform: RotatingPlatforms.Platform? = nil
local ridingRotor: RotatingPlatforms.LocalRotor? = nil
local ridingPivot: CFrame? = nil
local previousRoot: BasePart? = nil
local previousPosition: Vector3? = nil
local airborneSeconds = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function clear()
	ridingPlatform = nil
	ridingRotor = nil
	ridingPivot = nil
	previousRoot = nil
	previousPosition = nil
	airborneSeconds = 0
end

local function platformFor(hit: RaycastResult?): (RotatingPlatforms.Platform?, RotatingPlatforms.LocalRotor?)
	if hit == nil or hit.Normal.Y < MapFeatures.Rotating.MinSupportNormalY then
		return nil, nil
	end
	for _, platform in RotatingPlatforms.all() do
		if hit.Instance:IsDescendantOf(platform.assembly) then
			local _, rotor = RotatingPlatforms.rotorFor(hit.Instance)
			return platform, rotor
		end
	end
	return nil, nil
end

local function step(dt: number)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local config = MapFeatures.Rotating
	if
		character == nil
		or character:GetAttribute("CombatAlive") == false
		or root == nil
		or not root:IsA("BasePart")
		or humanoid == nil
		or root.Anchored
		or dt > config.MaxFrameSeconds
	then
		clear()
		return
	end
	if
		previousRoot ~= root
		or (previousPosition and (root.Position - previousPosition).Magnitude > config.MaxFrameDisplacement)
	then
		clear()
	end
	rayParams.FilterDescendantsInstances = { character }
	local contactDistance = humanoid.HipHeight + root.Size.Y / 2 + config.ContactTolerance
	local supportHit = Workspace:Raycast(root.Position, Vector3.new(0, -contactDistance, 0), rayParams)
	local platform, rotor = platformFor(supportHit)
	if platform then
		airborneSeconds = 0
	else
		airborneSeconds += dt
		local below =
			Workspace:Raycast(root.Position, Vector3.new(0, -contactDistance - config.CarryHeight, 0), rayParams)
		local belowPlatform, belowRotor = platformFor(below)
		if
			RiderSupport.canRetain({
				previous = ridingPlatform ~= nil,
				sameSupport = belowPlatform == ridingPlatform and belowRotor == ridingRotor,
				airborne = humanoid.FloorMaterial == Enum.Material.Air
					or humanoid:GetState() == Enum.HumanoidStateType.Jumping
					or humanoid:GetState() == Enum.HumanoidStateType.Freefall,
				otherContact = supportHit ~= nil,
				airborneSeconds = airborneSeconds,
			}, config.MaxAirborneSeconds)
		then
			platform = ridingPlatform
			rotor = ridingRotor
		end
	end
	if platform == nil then
		clear()
		return
	end
	local pivot = if rotor
		then RotatingPlatforms.rotorPoseAt(platform, rotor, Workspace:GetServerTimeNow())
		else platform.assembly:GetPivot()
	if ridingPlatform == platform and ridingRotor == rotor and ridingPivot then
		local current = root.CFrame
		local carried = pivot:PointToWorldSpace(ridingPivot:PointToObjectSpace(current.Position))
		local delta = Vector3.new(carried.X - current.X, 0, carried.Z - current.Z)
		if delta.Magnitude > config.MaxCarryDelta then
			clear()
			return
		end
		if delta.Magnitude >= config.MinimumCarryStuds then
			root.CFrame = current + delta
		end
	end
	ridingPlatform = platform
	ridingRotor = rotor
	ridingPivot = pivot
	previousRoot = root
	previousPosition = root.Position
end

function PlatformRider.start()
	if connection == nil then
		connection = RunService.Heartbeat:Connect(step)
	end
end

function PlatformRider.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	clear()
end

function PlatformRider._snapshotForTest()
	return {
		started = connection ~= nil,
		platform = if ridingPlatform then ridingPlatform.assembly:GetFullName() else "",
		rotor = ridingRotor ~= nil,
		airborneSeconds = airborneSeconds,
		root = previousRoot,
	}
end

return PlatformRider
