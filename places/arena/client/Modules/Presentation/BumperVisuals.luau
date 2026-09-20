-- Description: Renders the ring and course bumpers, tracking their authored parts under every tagged Scriptables root, and playing a squash-and-rebound animation and impact sound when the server broadcasts a bumper hit.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Game = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local ScriptableRoots = require(Game:WaitForChild("MapFeatures"):WaitForChild("ScriptableRoots"))
local GameAudio = require(script.Parent.GameAudio)

local BumperVisuals = {}

type BumperState = {
	baseSize: Vector3,
	activeTween: Tween?,
}

local bumpers: { [BasePart]: BumperState } = {}
local rootConnections: { [Instance]: { RBXScriptConnection } } = {}
local unwatch: (() -> ())? = nil
local remoteConnection: RBXScriptConnection? = nil
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
				baseSize = descendant.Size,
				activeTween = nil,
			}
		end
	end
end

local function trackFolder(root: Instance, folder: Instance)
	if not folder:IsA("Folder") then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Folder") then
			trackGroup(child)
		end
	end
	local connections = rootConnections[root]
	if connections then
		table.insert(
			connections,
			folder.ChildAdded:Connect(function(child)
				if child:IsA("Folder") then
					-- Origin and Assembly stream in after their folder.
					task.defer(trackGroup, child)
				end
			end)
		)
		table.insert(
			connections,
			folder.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") and isBumper(descendant) and bumpers[descendant] == nil then
					bumpers[descendant] = {
						baseSize = descendant.Size,
						activeTween = nil,
					}
				end
			end)
		)
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
end

local function removeRoot(root: Instance)
	local connections = rootConnections[root]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		rootConnections[root] = nil
	end
end

local function hitImpulse(part: BasePart)
	local state = bumpers[part]
	if state == nil then
		return
	end
	if state.activeTween then
		state.activeTween:Cancel()
		state.activeTween = nil
	end

	GameAudio.play("JumpPadBounce", part)

	local settings = config()
	local vertical = settings.MinimumSquash
	local widen = 1 - (vertical - 1) * settings.WidenScale
	local squashSize = state.baseSize * Vector3.new(widen, vertical, widen)

	local squashTween = TweenService:Create(
		part,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = squashSize }
	)
	local reboundTween = TweenService:Create(
		part,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = state.baseSize }
	)

	squashTween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and state.activeTween == squashTween then
			state.activeTween = reboundTween
			reboundTween:Play()
		end
	end)

	reboundTween.Completed:Connect(function(playbackState)
		if state.activeTween == reboundTween then
			state.activeTween = nil
			if playbackState == Enum.PlaybackState.Completed then
				part.Size = state.baseSize
			end
		end
	end)

	state.activeTween = squashTween
	squashTween:Play()
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
end

function BumperVisuals.stop()
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
	for part, state in bumpers do
		if state.activeTween then
			state.activeTween:Cancel()
			state.activeTween = nil
		end
		part.Size = state.baseSize
	end
	table.clear(bumpers)
	started = false
end

return BumperVisuals
