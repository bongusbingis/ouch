-- Description: Renders the ring and course bumpers, tracking their authored parts under every tagged Scriptables root, and playing a squash-and-rebound animation and impact sound when the server broadcasts a bumper hit.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Game = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local ScriptableRoots = require(Game:WaitForChild("MapFeatures"):WaitForChild("ScriptableRoots"))
local GameAudio = require(script.Parent.GameAudio)
local HazardVisuals = require(script.Parent.HazardVisuals)

local BumperVisuals = {}

type BumperState = {
	started: number?,
	clear: () -> (),
}

local bumpers: { [BasePart]: BumperState } = {}
local rootConnections: { [Instance]: { RBXScriptConnection } } = {}
local folderConnections: { [Folder]: { RBXScriptConnection } } = {}
local unwatch: (() -> ())? = nil
local remoteConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local started = false

local function config()
	return MapFeatures.Bumper
end

local function isBumper(part: BasePart): boolean
	if part:GetAttribute(MapFeatures.Attributes.Bumper) == true then
		return true
	end
	if part:FindFirstAncestor("SplashdownCourse") then
		return false
	end
	for _, prefix in config().NamePrefixes do
		if part.Name:find(prefix, 1, true) == 1 then
			return true
		end
	end
	return false
end

local function trackGroup(group: Instance)
	for _, descendant in group:GetDescendants() do
		if descendant:IsA("BasePart") and isBumper(descendant) and bumpers[descendant] == nil then
			bumpers[descendant] = {
				started = nil,
				clear = HazardVisuals.setEffect(descendant, "bumper"),
			}
		end
	end
end

local function forgetBumper(part: BasePart)
	local state = bumpers[part]
	if state then
		state.clear()
		bumpers[part] = nil
	end
end

local function trackFolder(root: Instance, folder: Instance)
	if not folder:IsA("Folder") then
		return
	end
	if folderConnections[folder] then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Folder") then
			trackGroup(child)
		end
	end
	local connections = {
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Folder") then
				-- Origin and Assembly stream in after their folder.
				task.defer(function()
					if started and folderConnections[folder] and child:IsDescendantOf(folder) then
						trackGroup(child)
					end
				end)
			end
		end),
		folder.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") and isBumper(descendant) and bumpers[descendant] == nil then
				bumpers[descendant] = {
					started = nil,
					clear = HazardVisuals.setEffect(descendant, "bumper"),
				}
			end
		end),
		folder.DescendantRemoving:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				forgetBumper(descendant)
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
	for part in bumpers do
		if part:IsDescendantOf(folder) then
			forgetBumper(part)
		end
	end
end

local function addRoot(root: Instance)
	rootConnections[root] = {}
	for _, name in { "Bumpers", "Motion", "Rotating" } do
		local folder = root:FindFirstChild(name)
		if folder then
			trackFolder(root, folder)
		end
	end
	table.insert(
		rootConnections[root],
		root.ChildAdded:Connect(function(child)
			if child.Name == "Bumpers" or child.Name == "Motion" or child.Name == "Rotating" then
				trackFolder(root, child)
			end
		end)
	)
	table.insert(
		rootConnections[root],
		root.ChildRemoved:Connect(function(child)
			if child:IsA("Folder") then
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
	for part, state in bumpers do
		if part:IsDescendantOf(root) or part.Parent == nil then
			forgetBumper(part)
		end
	end
end

local function hitImpulse(part: BasePart)
	local state = bumpers[part]
	if state == nil then
		return
	end
	GameAudio.play("JumpPadBounce", part)
	state.started = os.clock()
	HazardVisuals.pulse(part, 0.18, 0.12)
end

local function smoothstep(value: number): number
	local s = math.clamp(value, 0, 1)
	return s * s * (3 - 2 * s)
end

local function amountAt(t: number): number
	if t < 0.045 then
		return smoothstep(t / 0.045)
	elseif t < 0.13 then
		return 1 - 1.35 * smoothstep((t - 0.045) / 0.085)
	end
	return -0.35 * (1 - smoothstep((t - 0.13) / 0.13))
end

function BumperVisuals.start()
	if started then
		return
	end
	started = true

	unwatch = ScriptableRoots.watch(addRoot, removeRoot)

	remoteConnection = Network.on("BumperHit", function(part)
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			hitImpulse(part)
		end
	end)
	renderConnection = RunService.RenderStepped:Connect(function()
		for part, state in bumpers do
			local startedAt = state.started
			if startedAt then
				local t = os.clock() - startedAt
				if not part:IsDescendantOf(workspace) then
					state.started = nil
					state.clear()
				elseif t >= 0.26 then
					state.started = nil
					state.clear = HazardVisuals.setEffect(part, "bumper")
				elseif part.Transparency >= 1 then
					continue
				else
					local size = part.Size
					local q = if GuiService.ReducedMotionEnabled
						then 0
						else math.min(0.08, 0.5 / size.Y, 0.5 / size.X, 0.5 / size.Z)
					local amount = amountAt(t)
					local lateral = math.min(0.03, q * 0.375) * amount
					state.clear = HazardVisuals.setEffect(
						part,
						"bumper",
						CFrame.identity,
						Vector3.new(1 + lateral, 1 - q * amount, 1 + lateral)
					)
				end
			end
		end
	end)
end

function BumperVisuals.stop()
	if remoteConnection then
		remoteConnection:Disconnect()
		remoteConnection = nil
	end
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if unwatch then
		unwatch()
		unwatch = nil
	end
	for root in rootConnections do
		removeRoot(root)
	end
	for part, state in bumpers do
		state.clear()
	end
	table.clear(bumpers)
	started = false
end

return BumperVisuals
