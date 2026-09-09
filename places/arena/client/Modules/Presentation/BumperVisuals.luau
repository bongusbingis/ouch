-- Description: Renders the arena ring bumpers, tracking their authored parts and playing a squash animation and impact sound when the server broadcasts a bumper hit.

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

local BumperVisuals = {}

type BumperState = {
	baseSize: Vector3,
	spring: Spring.Spring,
}

local bumpers: { [BasePart]: BumperState } = {}
local started = false

local function config()
	return MapFeatures.Bumper
end

local function isBumperName(name: string): boolean
	for _, prefix in config().NamePrefixes do
		if name:find(prefix, 1, true) == 1 then
			return true
		end
	end
	return false
end

local function trackGroup(group: Instance)
	local assembly = group:FindFirstChild("Assembly")
	if assembly == nil or not assembly:IsA("Model") then
		return
	end
	for _, descendant in assembly:GetDescendants() do
		if descendant:IsA("BasePart") and isBumperName(descendant.Name) and bumpers[descendant] == nil then
			bumpers[descendant] = {
				baseSize = descendant.Size,
				spring = Spring.new(0),
			}
		end
	end
end

local function impulse(part: BasePart)
	local state = bumpers[part]
	if state == nil then
		return
	end
	Spring.impulse(state.spring, config().SquashImpulse)
	GameAudio.play("JumpPadBounce", part)
end

local function step(deltaTime: number)
	local settings = config()
	for part, state in bumpers do
		if part.Parent == nil then
			bumpers[part] = nil
			continue
		end
		Spring.step(state.spring, settings.SquashFrequencyHz, settings.SquashDampingRatio, deltaTime)
		local s = state.spring.position
		if math.abs(s) < 1e-3 and part.Size == state.baseSize then
			continue
		end
		local vertical = math.max(1 + s, settings.MinimumSquash)
		local widen = 1 - (vertical - 1) * settings.WidenScale
		part.Size = state.baseSize * Vector3.new(widen, vertical, widen)
	end
end

function BumperVisuals.start()
	if started then
		return
	end
	started = true

	local scriptables = Workspace:WaitForChild("Assets"):WaitForChild("Arena"):WaitForChild("Scriptables")
	local folder = scriptables:FindFirstChild("Rotating")
	if folder == nil or not folder:IsA("Folder") then
		warn("[BumperVisuals] No Scriptables.Rotating Folder authored; feature inactive")
		return
	end

	for _, child in folder:GetChildren() do
		if child:IsA("Folder") then
			trackGroup(child)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Folder") then
			trackGroup(child)
		end
	end)

	Network.on("BumperHit", function(part)
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			impulse(part)
		end
	end)

	RunService.RenderStepped:Connect(step)
end

return BumperVisuals
