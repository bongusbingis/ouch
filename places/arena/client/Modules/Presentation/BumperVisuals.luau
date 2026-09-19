-- Description: Renders the ring and course bumpers, tracking their authored parts under every tagged Scriptables root, squashing them on a metronome locked to the playing track's tempo, and playing a stronger squash and impact sound when the server broadcasts a bumper hit.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Game = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local ScriptableRoots = require(Game:WaitForChild("MapFeatures"):WaitForChild("ScriptableRoots"))
local Spring = require(Game:WaitForChild("Util"):WaitForChild("Spring"))
local BeatClock = require(Game:WaitForChild("Util"):WaitForChild("BeatClock"))
local GameAudio = require(script.Parent.GameAudio)
local MatchAudio = require(script.Parent.MatchAudio)

local BumperVisuals = {}

type BumperState = {
	baseSize: Vector3,
	spring: Spring.Spring,
}

local bumpers: { [BasePart]: BumperState } = {}
local rootConnections: { [Instance]: { RBXScriptConnection } } = {}
local unwatch: (() -> ())? = nil
local renderConnection: RBXScriptConnection? = nil
local remoteConnection: RBXScriptConnection? = nil
local started = false
local beatSound: Sound? = nil
local beatClock: BeatClock.Clock? = nil

local function config()
	return MapFeatures.Bumper
end

-- The clock only needs the tempo half of the bumper settings, named without the
-- Beat prefix the config uses to keep them apart from the squash values.
local function beatSettings(): BeatClock.Settings
	local settings = config()
	return {
		DefaultPeriodSeconds = settings.BeatDefaultPeriodSeconds,
		MinPeriodSeconds = settings.BeatMinPeriodSeconds,
		MaxPeriodSeconds = settings.BeatMaxPeriodSeconds,
		EnvelopeResponseHz = settings.BeatEnvelopeResponseHz,
		LoudnessFloor = settings.BeatLoudnessFloor,
		Sensitivity = settings.BeatSensitivity,
		OnsetGapSeconds = settings.BeatOnsetGapSeconds,
		TempoSamples = settings.BeatTempoSamples,
		TempoAdaptRate = settings.BeatTempoAdaptRate,
		PhaseCorrection = settings.BeatPhaseCorrection,
		PhaseWindow = settings.BeatPhaseWindow,
		LockedScale = settings.BeatLockedScale,
		BeatsPerPulse = settings.BeatsPerPulse,
	}
end

local function isBumper(part: BasePart): boolean
	if part:GetAttribute(MapFeatures.Attributes.Bumper) == true then
		return true
	end
	for _, prefix in config().NamePrefixes do
		if part.Name:find(prefix, 1, true) == 1 then
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
		if descendant:IsA("BasePart") and isBumper(descendant) and bumpers[descendant] == nil then
			bumpers[descendant] = {
				baseSize = descendant.Size,
				spring = Spring.new(0),
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
					bumpers[descendant] = { baseSize = descendant.Size, spring = Spring.new(0) }
				end
			end)
		)
	end
end

local function addRoot(root: Instance)
	rootConnections[root] = {}
	local folder = root:FindFirstChild("Rotating")
	if folder then
		trackFolder(root, folder)
	end
	table.insert(
		rootConnections[root],
		root.ChildAdded:Connect(function(child)
			if child.Name == "Rotating" then
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
	Spring.impulse(state.spring, config().SquashImpulse)
	GameAudio.play("JumpPadBounce", part)
end

local function resetBeatClock(sound: Sound?)
	beatSound = sound
	if sound == nil then
		beatClock = nil
		return
	end
	local settings = beatSettings()
	local clock = BeatClock.new(settings)
	BeatClock.reset(clock, settings, sound.TimePosition, sound.PlaybackLoudness)
	beatClock = clock
end

local function pulseBeat()
	for _, state in bumpers do
		Spring.impulse(state.spring, config().BeatImpulse)
	end
end

local function updateBeat(deltaTime: number)
	local sound = MatchAudio.getCurrentMusic()
	if sound ~= beatSound then
		resetBeatClock(sound)
		return
	end
	local clock = beatClock
	if sound == nil or clock == nil or not sound.IsPlaying then
		return
	end
	local pulses = BeatClock.advance(clock, beatSettings(), sound.TimePosition, sound.PlaybackLoudness, deltaTime)
	-- Several beats can only land in one frame after a hitch, and the bumpers
	-- should read as one squash rather than a stack of them.
	if pulses > 0 then
		pulseBeat()
	end
end

local function step(deltaTime: number)
	updateBeat(deltaTime)
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

	unwatch = ScriptableRoots.watch(addRoot, removeRoot)

	remoteConnection = Network.on("BumperHit", function(part)
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			hitImpulse(part)
		end
	end)

	renderConnection = RunService.RenderStepped:Connect(step)
end

function BumperVisuals.stop()
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
	resetBeatClock(nil)
	started = false
end

return BumperVisuals
