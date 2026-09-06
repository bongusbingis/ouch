-- Name: MatchAudio.luau
-- Author: Jack C.
-- Description: Drives match music and the results whistle from the replicated match phase, starting, crossfading, and stopping tracks as the match moves between phases.
-- Created: 2026-07-25

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Audio"))
local ClientAudio = require(script.Parent.ClientAudio)
local MatchAudioLogic = require(script.Parent.MatchAudioLogic)

local MatchAudio = {}

local started = false
local matchState: Folder? = nil
local phaseConnection: RBXScriptConnection? = nil
local timeConnection: RBXScriptConnection? = nil
local lastSeconds: any = nil
local musicEndedConnection: RBXScriptConnection? = nil
local currentMusic: Sound? = nil
local currentMode: MatchAudioLogic.MusicMode? = nil
local lastPhase: any = nil
local lastTrackIndex: number? = nil
local musicGeneration = 0
local random = Random.new()

local function disconnectMusicEnded()
	if musicEndedConnection then
		musicEndedConnection:Disconnect()
		musicEndedConnection = nil
	end
end

local function stopCurrentMusic(fadeOutSeconds: number)
	disconnectMusicEnded()
	local sound = currentMusic
	currentMusic = nil
	if sound then
		ClientAudio.stop(sound, fadeOutSeconds)
	end
end

local playMatchTrack: (number) -> ()

playMatchTrack = function(generation: number)
	if generation ~= musicGeneration or currentMode ~= "Match" then
		return
	end
	local config = AudioConfig.Music.Match
	local index = MatchAudioLogic.selectTrackIndex(#config.Tracks, lastTrackIndex, random:NextNumber())
	assert(index ~= nil, "[MatchAudio] Config.Audio.Music.Match.Tracks must not be empty")
	lastTrackIndex = index
	local sound = ClientAudio.play({
		name = `MatchMusic_{index}`,
		assetId = config.Tracks[index],
		category = "Music",
		volume = config.Volume,
		fadeInSeconds = config.FadeInSeconds,
		destroyOnEnded = false,
	})
	currentMusic = sound
	musicEndedConnection = sound.Ended:Once(function()
		if generation ~= musicGeneration or currentMode ~= "Match" or currentMusic ~= sound then
			return
		end
		ClientAudio.stop(sound, 0)
		musicEndedConnection = nil
		currentMusic = nil
		playMatchTrack(generation)
	end)
end

local function setMusicMode(mode: MatchAudioLogic.MusicMode?)
	if mode == currentMode and (mode == nil or currentMusic ~= nil) then
		return
	end
	musicGeneration += 1
	local generation = musicGeneration
	stopCurrentMusic(AudioConfig.Music.FadeOutSeconds)
	currentMode = mode

	if mode == "Match" then
		playMatchTrack(generation)
	elseif mode == "Lobby" then
		local config = AudioConfig.Music.Lobby
		currentMusic = ClientAudio.play({
			name = "LobbyMusic",
			assetId = config.AssetId,
			category = "Music",
			volume = config.Volume,
			looped = true,
			fadeInSeconds = config.FadeInSeconds,
		})
	end
end

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

local function onTimeChanged()
	local state = matchState
	if state == nil then
		return
	end
	local seconds = state:GetAttribute("timeRemaining")
	if
		MatchAudioLogic.shouldPlayTick(
			state:GetAttribute("phase"),
			lastSeconds,
			seconds,
			AudioConfig.Effects.FinalSeconds.Threshold
		)
	then
		playCue("FinalSeconds")
	end
	lastSeconds = seconds
end

local function onPhaseChanged()
	local state = matchState
	if state == nil then
		return
	end
	local phase = state:GetAttribute("phase")
	if MatchAudioLogic.shouldPlayStart(lastPhase, phase) then
		playCue("MatchStart")
	end
	if MatchAudioLogic.shouldPlayWhistle(lastPhase, phase) then
		local whistle = AudioConfig.Effects.MatchEndWhistle
		ClientAudio.play({
			name = "MatchEndWhistle",
			assetId = whistle.AssetId,
			category = "Effects",
			volume = whistle.Volume,
			maxLifetimeSeconds = whistle.MaxLifetimeSeconds,
		})
	end
	setMusicMode(MatchAudioLogic.musicMode(phase))
	lastPhase = phase
	lastSeconds = nil
end

function MatchAudio.start()
	if started then
		return
	end
	started = true
	local state = ReplicatedStorage:WaitForChild("MatchState")
	assert(state:IsA("Folder"), "[MatchAudio] ReplicatedStorage.MatchState must be a Folder")
	matchState = state
	lastPhase = state:GetAttribute("phase")
	setMusicMode(MatchAudioLogic.musicMode(lastPhase))
	phaseConnection = state:GetAttributeChangedSignal("phase"):Connect(onPhaseChanged)
	timeConnection = state:GetAttributeChangedSignal("timeRemaining"):Connect(onTimeChanged)
end

function MatchAudio._resetForTest()
	if timeConnection then
		timeConnection:Disconnect()
	end
	timeConnection = nil
	lastSeconds = nil
	if phaseConnection then
		phaseConnection:Disconnect()
	end
	phaseConnection = nil
	musicGeneration += 1
	stopCurrentMusic(0)
	ClientAudio._resetForTest()
	started = false
	matchState = nil
	currentMode = nil
	lastPhase = nil
	lastTrackIndex = nil
	random = Random.new()
end

return MatchAudio
