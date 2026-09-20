-- Kinematic local-axis tilt from normalized rider offsets, sampled once per frame.
--!strict
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(RS.Config.Gameplay.MapFeatures)
local Parts = require(script.Parent.FeatureParts)
local Kit = require(script.Parent.MapFeatureKit)
local Seesaws = { folderName = "Rotating", instanceClass = "Folder" }
Seesaws.folderNames = { "Seesaws", "Rotating" }
type State = { base: CFrame, angle: number, moment: number, followers: { { part: BasePart, offset: CFrame } } }
local states: { [BasePart]: State } = {}
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.RespectCanCollide = true
local function apply(part: BasePart, state: State, angle: number)
	local axis = Parts.axis(part:GetAttribute("SeesawAxis") or Config.Seesaw.Axis)
	local center = state.base * CFrame.fromAxisAngle(axis, angle)
	for _, follower in state.followers do
		if follower.part.Parent then
			follower.part.CFrame = center * follower.offset
		end
	end
end
function Seesaws.tickWorld(context: Kit.Context)
	local active = {}
	for _, part in Parts.collect(context.instances, Config.Attributes.Seesaw) do
		active[part] = true
		local state = states[part]
		if not state then
			local base = part:GetPivot()
			local followers = { { part = part, offset = base:ToObjectSpace(part.CFrame) } }
			for _, child in part:GetDescendants() do
				if child:IsA("BasePart") then
					table.insert(followers, { part = child, offset = base:ToObjectSpace(child.CFrame) })
				end
			end
			state = { base = base, angle = 0, moment = 0, followers = followers }
			states[part] = state
		end
		local limit = math.rad(Parts.number(part, "MaxTiltDegrees", Config.Seesaw.MaxTiltDegrees, 1, 40))
		local target = math.clamp(state.moment * Config.Seesaw.RiderWeight, -1, 1) * limit
		state.angle += (target - state.angle) * (1 - math.exp(
			-Parts.number(part, "SeesawResponse", Config.Seesaw.Response, 0.1, 10) * math.min(context.deltaTime, 0.2)
		))
		state.moment = 0
		apply(part, state, state.angle)
	end
	for part, state in states do
		if not active[part] then
			apply(part, state, 0)
			states[part] = nil
		end
	end
end
function Seesaws.tickPlayer(_context: Kit.Context, _player: Player, root: BasePart)
	local humanoid = if root.Parent then root.Parent:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or root.Anchored then
		return
	end
	ray.FilterDescendantsInstances = { root.Parent :: Instance }
	local hit = Workspace:Raycast(root.Position, -Vector3.yAxis * (humanoid.HipHeight + root.Size.Y / 2 + 1), ray)
	if not hit or hit.Normal.Y < 0.5 then
		return
	end
	for part, state in states do
		if hit.Instance == part or hit.Instance:IsDescendantOf(part) then
			local offset = state.base:PointToObjectSpace(root.Position)
			local axis = part:GetAttribute("SeesawAxis") or Config.Seesaw.Axis
			-- Downward torque: positive X lowers the positive-X side of a Z axle.
			state.moment += if axis == "X" then offset.Z / (part.Size.Z / 2) else -offset.X / (part.Size.X / 2)
			return
		end
	end
end
function Seesaws.forget(player: Player?)
	if player then
		return
	end
	for part, state in states do
		apply(part, state, 0)
	end
	table.clear(states)
end
return Seesaws
