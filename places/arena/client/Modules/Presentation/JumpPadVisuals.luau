-- Name: JumpPadVisuals.luau
-- Author: Jack C.
-- Description: Renders the arena jump pads, tracking their authored parts and playing the squash animation and launch sound when the server broadcasts a pad impulse.
-- Created: 2026-08-19

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Spring =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Util"):WaitForChild("Spring"))
local GameAudio = require(script.Parent.GameAudio)

local JumpPadVisuals = {}

local INNER_PART_NAME = "Inner"

type PartState = {
	baseSize: Vector3,
	baseCFrame: CFrame,
	spring: Spring.Spring,
}

type PadState = {
	parts: { [BasePart]: PartState },
	outer: Spring.Spring,
	inner: Spring.Spring,
}

local pads: { [Model]: PadState } = {}
local started = false

local function config()
	return MapFeatures.JumpPad
end

local function trackPart(state: PadState, instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	state.parts[instance] = {
		baseSize = instance.Size,
		baseCFrame = instance.CFrame,
		spring = if instance.Name == INNER_PART_NAME then state.inner else state.outer,
	}
end

local function trackPad(pad: Model)
	if pads[pad] then
		return
	end
	local state: PadState = {
		parts = {},
		outer = Spring.new(0),
		inner = Spring.new(0),
	}
	pads[pad] = state
	for _, descendant in pad:GetDescendants() do
		trackPart(state, descendant)
	end
	pad.DescendantAdded:Connect(function(descendant)
		trackPart(state, descendant)
	end)
	pad.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			state.parts[descendant] = nil
		end
	end)
end

local function impulse(pad: Model)
	local state = pads[pad]
	if state == nil then
		return
	end
	Spring.impulse(state.outer, config().OuterImpulse)
	Spring.impulse(state.inner, config().InnerImpulse)
	GameAudio.play("JumpPadBounce", pad)
end

local function step(deltaTime: number)
	local settings = config()
	for _, state in pads do
		Spring.step(state.outer, settings.OuterFrequencyHz, settings.OuterDampingRatio, deltaTime)
		Spring.step(state.inner, settings.InnerFrequencyHz, settings.InnerDampingRatio, deltaTime)

		for part, partState in state.parts do
			if part.Parent == nil then
				state.parts[part] = nil
				continue
			end
			local baseSize = partState.baseSize
			local height = math.max(baseSize.Y + partState.spring.position, baseSize.Y * settings.MinimumSquash)
			local spread = 1 / math.sqrt(height / baseSize.Y)
			part.Size = Vector3.new(baseSize.X * spread, height, baseSize.Z * spread)
			part.CFrame = partState.baseCFrame + Vector3.new(0, (height - baseSize.Y) / 2, 0)
		end
	end
end

function JumpPadVisuals.start()
	if started then
		return
	end
	started = true

	local scriptables = Workspace:WaitForChild("Assets"):WaitForChild("Arena"):WaitForChild("Scriptables")
	local folder = scriptables:FindFirstChild("JumpPads")
	if folder == nil or not folder:IsA("Folder") then
		warn("[JumpPadVisuals] No Scriptables.JumpPads Folder authored; feature inactive")
		return
	end

	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			trackPad(child)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			trackPad(child)
		end
	end)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			pads[child :: Model] = nil
		end
	end)

	Network.on("JumpPadImpulse", function(pad)
		if typeof(pad) == "Instance" and pad:IsA("Model") then
			impulse(pad)
		end
	end)

	RunService.RenderStepped:Connect(step)
end

return JumpPadVisuals
