-- Description: Plays the existing match cues at the Splashdown race beats: a tick on each countdown second, the start horn on GO, and the whistle when a round closes, all driven from the race view so every client hears the same moment.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Audio"))
local ClientAudio = require(script.Parent.ClientAudio)
local SplashdownClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("SplashdownClient"))

local SplashdownAudio = {}

local started = false
local disconnect: (() -> ())? = nil
local lastCountdown: string? = nil
local lastPhase: string? = nil

local function playCue(name: string)
	local cue = AudioConfig.Effects[name]
	ClientAudio.play({
		name = name,
		assetId = cue.AssetId,
		category = "Effects",
		volume = cue.Volume,
		maxLifetimeSeconds = cue.MaxLifetimeSeconds,
	})
end

local function onView(view)
	local countdown = view.countdown
	if countdown ~= lastCountdown and countdown ~= nil then
		if countdown == "GO!" then
			playCue("MatchStart")
		else
			playCue("FinalSeconds")
		end
	end
	lastCountdown = countdown
	if view.phase ~= lastPhase and view.phase == "RoundOver" then
		playCue("MatchEndWhistle")
	end
	lastPhase = view.phase
end

function SplashdownAudio.start()
	if started then
		return
	end
	started = true
	local first = SplashdownClient.getView()
	lastCountdown = first.countdown
	lastPhase = first.phase
	disconnect = SplashdownClient.subscribeView(onView)
end

function SplashdownAudio.destroy()
	if disconnect then
		disconnect()
		disconnect = nil
	end
	started = false
end

return SplashdownAudio
