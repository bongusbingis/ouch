-- Description: Renders the arena and course jump pads, tracking their authored parts under every tagged Scriptables root and playing the squash animation and launch sound when the server broadcasts a pad impulse.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Game = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local ScriptableRoots = require(Game:WaitForChild("MapFeatures"):WaitForChild("ScriptableRoots"))
local Spring = require(Game:WaitForChild("Util"):WaitForChild("Spring"))
local GameAudio = require(script.Parent.GameAudio)

local JumpPadVisuals = {}

local INNER_PART_NAME = "Inner"
local FOLDER_NAME = "JumpPads"

type PartState = {
	baseSize: Vector3,
	baseCFrame: CFrame,
	spring: Spring.Spring,
}

type PadState = {
	parts: { [BasePart]: PartState },
	outer: Spring.Spring,
	inner: Spring.Spring,
	connections: { RBXScriptConnection },
}

local pads: { [Model]: PadState } = {}
local rootConnections: { [Instance]: { RBXScriptConnection } } = {}
local unwatch: (() -> ())? = nil
local renderConnection: RBXScriptConnection? = nil
local remoteConnection: RBXScriptConnection? = nil
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

local function forgetPad(pad: Model)
	local state = pads[pad]
	if state == nil then
		return
	end
	pads[pad] = nil
	for _, connection in state.connections do
		connection:Disconnect()
	end
end

local function trackPad(pad: Model)
	if pads[pad] then
		return
	end
	local state: PadState = {
		parts = {},
		outer = Spring.new(0),
		inner = Spring.new(0),
		connections = {},
	}
	pads[pad] = state
	for _, descendant in pad:GetDescendants() do
		trackPart(state, descendant)
	end
	table.insert(
		state.connections,
		pad.DescendantAdded:Connect(function(descendant)
			trackPart(state, descendant)
		end)
	)
	table.insert(
		state.connections,
		pad.DescendantRemoving:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				state.parts[descendant] = nil
			end
		end)
	)
end

local function trackFolder(root: Instance, folder: Instance)
	if not folder:IsA("Folder") then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			trackPad(child)
		end
	end
	local connections = rootConnections[root]
	if connections then
		table.insert(
			connections,
			folder.ChildAdded:Connect(function(child)
				if child:IsA("Model") then
					trackPad(child)
				end
			end)
		)
		table.insert(
			connections,
			folder.ChildRemoved:Connect(function(child)
				if child:IsA("Model") then
					forgetPad(child)
				end
			end)
		)
	end
end

local function addRoot(root: Instance)
	rootConnections[root] = {}
	local folder = root:FindFirstChild(FOLDER_NAME)
	if folder then
		trackFolder(root, folder)
	end
	table.insert(
		rootConnections[root],
		root.ChildAdded:Connect(function(child)
			if child.Name == FOLDER_NAME then
				trackFolder(root, child)
			end
		end)
	)
end

local function removeRoot(root: Instance)
	local connections = rootConnections[root]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		rootConnections[root] = nil
	end
	for pad in pads do
		if pad:IsDescendantOf(root) or pad.Parent == nil then
			forgetPad(pad)
		end
	end
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
			local s = partState.spring.position
			if math.abs(s) < 1e-3 and part.Size == baseSize then
				continue
			end
			local height = math.max(baseSize.Y + s, baseSize.Y * settings.MinimumSquash)
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

	unwatch = ScriptableRoots.watch(addRoot, removeRoot)

	remoteConnection = Network.on("JumpPadImpulse", function(pad)
		if typeof(pad) == "Instance" and pad:IsA("Model") then
			impulse(pad)
		end
	end)

	renderConnection = RunService.RenderStepped:Connect(step)
end

function JumpPadVisuals.stop()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if remoteConnection then
		remoteConnection:Disconnect()
		remoteConnection = nil
	end
	if unwatch then
		unwatch()
		unwatch = nil
	end
	for root in rootConnections do
		removeRoot(root)
	end
	for pad in pads do
		forgetPad(pad)
	end
	started = false
end

return JumpPadVisuals
