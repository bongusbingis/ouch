-- Description: Renders the arena and course jump pads, tracking their authored parts under every tagged Scriptables root and playing the squash animation and launch sound when the server broadcasts a pad impulse.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Game = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local ScriptableRoots = require(Game:WaitForChild("MapFeatures"):WaitForChild("ScriptableRoots"))
local GameAudio = require(script.Parent.GameAudio)
local HazardVisuals = require(script.Parent.HazardVisuals)

local JumpPadVisuals = {}

local INNER_PART_NAME = "Inner"
local FOLDER_NAME = "JumpPads"

type PartState = {
	baseSize: Vector3,
	inner: boolean,
	clear: () -> (),
}

type PadState = {
	parts: { [BasePart]: PartState },
	started: number?,
	connections: { RBXScriptConnection },
}

local pads: { [Model]: PadState } = {}
local rootConnections: { [Instance]: { RBXScriptConnection } } = {}
local folderConnections: { [Folder]: { RBXScriptConnection } } = {}
local unwatch: (() -> ())? = nil
local renderConnection: RBXScriptConnection? = nil
local remoteConnection: RBXScriptConnection? = nil
local started = false

local function noop() end

local function trackPart(state: PadState, instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	state.parts[instance] = {
		baseSize = instance.Size,
		inner = instance.Name == INNER_PART_NAME,
		clear = noop,
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
	for _, partState in state.parts do
		partState.clear()
	end
end

local function trackPad(pad: Model)
	if pads[pad] then
		return
	end
	local state: PadState = {
		parts = {},
		started = nil,
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
				local partState = state.parts[descendant]
				if partState then
					partState.clear()
				end
				state.parts[descendant] = nil
			end
		end)
	)
end

local function trackFolder(root: Instance, folder: Instance)
	if not folder:IsA("Folder") then
		return
	end
	if folderConnections[folder] then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			trackPad(child)
		end
	end
	local connections = {
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				trackPad(child)
			end
		end),
		folder.ChildRemoved:Connect(function(child)
			if child:IsA("Model") then
				forgetPad(child)
			end
		end),
	}
	folderConnections[folder] = connections
end

local function untrackFolder(folder: Folder)
	local connections = folderConnections[folder]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		folderConnections[folder] = nil
	end
	for pad in pads do
		if pad:IsDescendantOf(folder) then
			forgetPad(pad)
		end
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
	table.insert(
		rootConnections[root],
		root.ChildRemoved:Connect(function(child)
			if child:IsA("Folder") and child.Name == FOLDER_NAME then
				untrackFolder(child)
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
	for folder in folderConnections do
		if folder:IsDescendantOf(root) then
			untrackFolder(folder)
		end
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
	state.started = os.clock()
	for part, partState in state.parts do
		if partState.inner then
			HazardVisuals.pulse(part, 0.18, 0.12)
		end
	end
	GameAudio.play("JumpPadBounce", pad)
end

local function smoothstep(value: number): number
	local s = math.clamp(value, 0, 1)
	return s * s * (3 - 2 * s)
end

local function amountAt(t: number): number
	if t < 0.05 then
		return smoothstep(t / 0.05)
	elseif t < 0.13 then
		return 1 - 1.3125 * smoothstep((t - 0.05) / 0.08)
	end
	return -0.3125 * (1 - smoothstep((t - 0.13) / 0.19))
end

local function step()
	for _, state in pads do
		local startedAt = state.started
		if not startedAt then
			continue
		end
		local t = os.clock() - startedAt
		local finished = t >= 0.32
		for part, partState in state.parts do
			if not part:IsDescendantOf(workspace) then
				partState.clear()
				state.parts[part] = nil
				continue
			end
			if finished then
				partState.clear()
				partState.clear = noop
				continue
			end
			if part.Transparency >= 1 then
				continue
			end
			local baseSize = partState.baseSize
			local q = if GuiService.ReducedMotionEnabled
				then 0
				else math.min(0.08, 0.12 / baseSize.Y, 0.5 / baseSize.X, 0.5 / baseSize.Z)
			if not partState.inner then
				q *= 0.5
			end
			local amount = amountAt(t)
			local heightChange = -baseSize.Y * q * amount
			local lateral = math.min(0.02, q * 0.25) * amount
			local scale = Vector3.new(1 + lateral, 1 + heightChange / baseSize.Y, 1 + lateral)
			partState.clear = HazardVisuals.setEffect(part, "jumpPad", CFrame.new(0, heightChange / 2, 0), scale)
		end
		if finished then
			state.started = nil
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
