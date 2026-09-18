-- Anchored Roblox surface velocities move both humanoids and unanchored balls.
--!strict
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Config.Gameplay.MapFeatures)
local Parts = require(script.Parent.FeatureParts)
local Kit = require(script.Parent.MapFeatureKit)
local Guard = require(RS.Shared.Game.Adapters.MovementGuard)
local Conveyors = { folderName = "Rotating", instanceClass = "Folder" }
local original: { [BasePart]: Vector3 } = {}
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.RespectCanCollide = true
function Conveyors.tickWorld(context: Kit.Context)
	local active = {}
	for _, part in Parts.collect(context.instances, Config.Attributes.Conveyor) do
		active[part] = true
		if not original[part] then
			original[part] = part.AssemblyLinearVelocity
		end
		local axis = Parts.axis(part:GetAttribute(Config.Attributes.ConveyorAxis) or Config.Conveyor.Axis)
		part.AssemblyLinearVelocity = part.CFrame:VectorToWorldSpace(axis)
			* Parts.number(part, "ConveyorSpeed", Config.Conveyor.Speed, -80, 80)
	end
	for part, value in original do
		if not active[part] then
			if part.Parent then
				part.AssemblyLinearVelocity = value
			end
			original[part] = nil
		end
	end
end
function Conveyors.tickPlayer(_context: Kit.Context, _player: Player, root: BasePart)
	local humanoid = if root.Parent then root.Parent:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or root.Anchored then
		return
	end
	ray.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = workspace:Raycast(root.Position, -Vector3.yAxis * (humanoid.HipHeight + root.Size.Y / 2 + 0.75), ray)
	if hit and hit.Normal.Y >= 0.5 and original[hit.Instance] then
		local speed = hit.Instance.AssemblyLinearVelocity.Magnitude
		Guard.allow(root, "Conveyor", 0.3, (humanoid.WalkSpeed + speed) * 1.3, 60, hit.Instance)
	end
end
function Conveyors.forget(player: Player?)
	if player then
		return
	end
	for part, value in original do
		if part.Parent then
			part.AssemblyLinearVelocity = value
		end
	end
	table.clear(original)
end
return Conveyors
