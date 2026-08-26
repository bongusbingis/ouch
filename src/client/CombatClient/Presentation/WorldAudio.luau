-- Name: WorldAudio.luau
-- Author: Jack C.
-- Description: Plays a Studio-authored sound at a world position or on an instance by wiring an audio player to an emitter, the shared entry point for spatial one-shots.
-- Created: 2026-07-13

--!strict

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local ClientAudio = require(script.Parent.ClientAudio)

local WorldAudio = {}

local combatAudio = SoundService:WaitForChild("CombatAudio")

local function findAudioPlayer(groupName: string, soundName: string): AudioPlayer?
	local group = combatAudio:FindFirstChild(groupName)
	if group == nil then
		return nil
	end
	local player = group:FindFirstChild(soundName)
	if player and player:IsA("AudioPlayer") then
		return player
	end
	return nil
end

local function emitterFor(parent: Instance): AudioEmitter?
	local emitter = parent:FindFirstChild("CombatAudioEmitter", true)
	if emitter and emitter:IsA("AudioEmitter") then
		return emitter
	end

	local created = Instance.new("AudioEmitter")
	created.Name = "CombatAudioEmitter"
	created.Parent = parent
	return created
end

function WorldAudio.play(
	groupName: string,
	soundName: string,
	parent: Instance,
	volumeScale: number?,
	speedScale: number?
)
	local template = findAudioPlayer(groupName, soundName)
	local emitter = emitterFor(parent)
	if template == nil or emitter == nil then
		return
	end

	local player = template:Clone()
	player.Volume = ClientAudio.effectiveVolume("Effects", player.Volume * (volumeScale or 1))
	player.PlaybackSpeed *= speedScale or 1
	local wire = Instance.new("Wire")
	player.Parent = parent
	wire.Parent = player
	wire.SourceInstance = player
	wire.TargetInstance = emitter
	player:Play()

	Debris:AddItem(player, math.max(player.TimeLength, 3) + 0.25)
end

return WorldAudio
