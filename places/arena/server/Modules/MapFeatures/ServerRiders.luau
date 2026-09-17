-- Opt-in course carrying after the mover: actual support ray, all three axes,
-- no new airborne acquisition, and only for a character the server simulates.
--!strict
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Features = RS.Shared.Game.MapFeatures
local MapFeatures = require(RS.Config.Gameplay.MapFeatures)
local Rotating = require(Features.RotatingPlatforms)
local Motion = require(Features.CarryMotion)
local RiderSupport = require(Features.RiderSupport)
local Guard = require(RS.Shared.Game.Adapters.MovementGuard)
local MapFeatureKit = require(script.Parent.MapFeatureKit)
local ServerRiders = { folderName = "Rotating", instanceClass = "Folder" }
type Ride = { root: BasePart, support: BasePart, frame: CFrame, position: Vector3 }
local rides: { [Player]: Ride } = {}
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.RespectCanCollide = true

function ServerRiders.tickPlayer(context: MapFeatureKit.Context, player: Player, root: BasePart)
	local character = root.Parent
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local config = MapFeatures.ServerCarry
	local previous = rides[player]
	if not humanoid or humanoid.Health <= 0 or root.Anchored or context.deltaTime > config.MaxFrameSeconds then
		rides[player] = nil
		return
	end
	ray.FilterDescendantsInstances = { character :: Instance }
	local distance = humanoid.HipHeight + root.Size.Y / 2 + config.ContactTolerance
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), ray)
	if not hit or hit.Normal.Y < MapFeatures.Rotating.MinSupportNormalY then
		rides[player] = nil
		return
	end
	local support = hit.Instance
	local eligible = false
	for _, platform in Rotating.all() do
		if
			platform.origin:GetAttribute(MapFeatures.Attributes.ServerCarries) == true
			and support:IsDescendantOf(platform.assembly)
		then
			local _, rotor = Rotating.rotorFor(support)
			-- A static follower still belongs to a whole-assembly rotating ride.
			local _, owner = Rotating.rotorOwning(support)
			eligible = rotor ~= nil or owner == nil
			break
		end
	end
	if not eligible then
		rides[player] = nil
		return
	end
	local owned, owner = pcall(root.GetNetworkOwner, root)
	if
		not RiderSupport.serverMayCarry({
			serverOwnsRoot = owned and owner == nil,
			seated = previous ~= nil,
			airborne = humanoid.FloorMaterial == Enum.Material.Air,
		})
	then
		rides[player] = nil
		return
	end
	if
		previous
		and previous.root == root
		and previous.support == support
		and (root.Position - previous.position).Magnitude < MapFeatures.Rotating.MaxFrameDisplacement
	then
		local delta = Motion.delta(previous.frame, support.CFrame, root.Position, config.MaxCarryDelta)
		if delta then
			local speed = delta.Magnitude / math.max(context.deltaTime, 1e-4)
			Guard.allow(root, "CourseCarry", config.GuardSeconds, humanoid.WalkSpeed + speed, speed + 60, support)
			root.CFrame += delta
		end
	end
	rides[player] = { root = root, support = support, frame = support.CFrame, position = root.Position }
end

function ServerRiders.forget(player: Player?)
	if player then
		rides[player] = nil
	else
		table.clear(rides)
	end
end
return ServerRiders
