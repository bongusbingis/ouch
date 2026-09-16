-- Visual-only ghosts: never resize or move replicated collision geometry.
--!strict
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Network = require(RS.Shared.Network)
local HazardVisuals = {}
type Effect = { ghost: BasePart, started: number, duration: number, kind: string, transparency: number }
local active: { [BasePart]: Effect } = {}
local render: RBXScriptConnection? = nil
local remote: RBXScriptConnection? = nil
local function clear(part: BasePart)
	local state = active[part]
	if not state then
		return
	end
	if part.Parent then
		part.LocalTransparencyModifier = state.transparency
	end
	state.ghost:Destroy()
	active[part] = nil
end
local function show(part: any, kind: any, duration: any)
	if
		typeof(part) ~= "Instance"
		or not part:IsA("BasePart")
		or not part:IsDescendantOf(Workspace)
		or (kind ~= "impact" and kind ~= "shake")
		or typeof(duration) ~= "number"
	then
		return
	end
	clear(part)
	local ghost = part:Clone()
	for _, child in ghost:GetChildren() do
		if
			not child:IsA("DataModelMesh")
			and not child:IsA("Decal")
			and not child:IsA("Texture")
			and not child:IsA("SurfaceAppearance")
		then
			child:Destroy()
		end
	end
	ghost.Name = "HazardVisualGhost"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanTouch = false
	ghost.CanQuery = false
	ghost:RemoveTag("ScriptableRoot")
	for name in ghost:GetAttributes() do
		ghost:SetAttribute(name, nil)
	end
	ghost.Parent = Workspace.CurrentCamera
	active[part] = {
		ghost = ghost,
		started = os.clock(),
		duration = math.clamp(duration, 0.05, 10),
		kind = kind,
		transparency = part.LocalTransparencyModifier,
	}
	part.LocalTransparencyModifier = 1
end
function HazardVisuals.start()
	if render then
		return
	end
	remote = Network.on("HazardVisual", show)
	render = RunService.RenderStepped:Connect(function()
		for part, state in active do
			local t = os.clock() - state.started
			if not part.Parent or t >= state.duration or part.Transparency >= 1 then
				clear(part)
				continue
			end
			local envelope = 1 - t / state.duration
			if state.kind == "shake" then
				state.ghost.CFrame = part.CFrame * CFrame.Angles(0, 0, math.sin(t * 70) * 0.035)
			else
				local squash = math.sin(t * math.pi / state.duration) * 0.12 * envelope
				state.ghost.Size = part.Size * Vector3.new(1 + squash / 2, 1 - squash, 1 + squash / 2)
				state.ghost.CFrame = part.CFrame
			end
		end
	end)
end
function HazardVisuals.stop()
	if render then
		render:Disconnect()
		render = nil
	end
	if remote then
		remote:Disconnect()
		remote = nil
	end
	for part in active do
		clear(part)
	end
end
return HazardVisuals
