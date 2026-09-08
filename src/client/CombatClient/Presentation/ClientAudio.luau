-- Description: Owns dynamic Sound playback on the client and the single runtime audio mix, exposing master, music, and effects volume controls that every client sound routes through.

--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AudioConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Audio"))
local SettingsStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Settings"):WaitForChild("SettingsStore")
)

local ClientAudio = {}

export type Category = "Music" | "Effects"
export type PlayOptions = {
	name: string,
	assetId: string,
	category: Category,
	volume: number,
	looped: boolean?,
	fadeInSeconds: number?,
	maxLifetimeSeconds: number?,
	destroyOnEnded: boolean?,
}

type ActiveSound = {
	baseVolume: number,
	category: Category,
	tween: Tween?,
}

local levels = {
	Master = AudioConfig.Mix.MasterVolume,
	Music = AudioConfig.Mix.MusicVolume,
	Effects = AudioConfig.Mix.EffectsVolume,
}
local activeSounds: { [Sound]: ActiveSound } = {}

local function normalizedVolume(value: number): number
	assert(value == value and math.abs(value) < math.huge, "[ClientAudio] volume must be finite")
	return math.clamp(value, 0, 1)
end

function ClientAudio.effectiveVolume(category: Category, baseVolume: number): number
	local categoryVolume = if category == "Music" then levels.Music else levels.Effects
	return math.max(baseVolume, 0) * levels.Master * categoryVolume
end

local function cancelTween(entry: ActiveSound)
	if entry.tween then
		entry.tween:Cancel()
		entry.tween = nil
	end
end

local function forget(sound: Sound)
	local entry = activeSounds[sound]
	if entry then
		cancelTween(entry)
		activeSounds[sound] = nil
	end
end

local function refreshVolumes()
	for sound, entry in activeSounds do
		cancelTween(entry)
		sound.Volume = ClientAudio.effectiveVolume(entry.category, entry.baseVolume)
	end
end

function ClientAudio.setMasterVolume(value: number)
	levels.Master = normalizedVolume(value)
	refreshVolumes()
end

function ClientAudio.setMusicVolume(value: number)
	levels.Music = normalizedVolume(value)
	refreshVolumes()
end

function ClientAudio.setEffectsVolume(value: number)
	levels.Effects = normalizedVolume(value)
	refreshVolumes()
end

function ClientAudio.getVolumes(): { master: number, music: number, effects: number }
	return {
		master = levels.Master,
		music = levels.Music,
		effects = levels.Effects,
	}
end

function ClientAudio.play(options: PlayOptions): Sound
	assert(string.match(options.assetId, "^rbxassetid://%d+$") ~= nil, "[ClientAudio] assetId must be an rbxassetid")
	local fadeInSeconds = math.max(options.fadeInSeconds or 0, 0)
	local sound = Instance.new("Sound")
	sound.Name = options.name
	sound.SoundId = options.assetId
	sound.Looped = options.looped == true
	sound.Volume = if fadeInSeconds > 0 then 0 else ClientAudio.effectiveVolume(options.category, options.volume)
	sound.Parent = SoundService

	local entry: ActiveSound = {
		baseVolume = math.max(options.volume, 0),
		category = options.category,
		tween = nil,
	}
	activeSounds[sound] = entry
	sound.Destroying:Once(function()
		forget(sound)
	end)
	if options.destroyOnEnded ~= false then
		sound.Ended:Once(function()
			if not sound.Looped then
				sound:Destroy()
			end
		end)
	end

	sound:Play()
	if fadeInSeconds > 0 then
		local tween = TweenService:Create(
			sound,
			TweenInfo.new(fadeInSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Volume = ClientAudio.effectiveVolume(options.category, options.volume) }
		)
		entry.tween = tween
		tween.Completed:Once(function()
			if entry.tween == tween then
				entry.tween = nil
			end
		end)
		tween:Play()
	end
	if options.maxLifetimeSeconds then
		Debris:AddItem(sound, options.maxLifetimeSeconds)
	end
	return sound
end

function ClientAudio.stop(sound: Sound?, fadeOutSeconds: number?)
	if sound == nil then
		return
	end
	local entry = activeSounds[sound]
	if entry then
		cancelTween(entry)
		activeSounds[sound] = nil
	end
	if sound.Parent == nil then
		return
	end

	local fadeSeconds = math.max(fadeOutSeconds or 0, 0)
	if fadeSeconds == 0 then
		sound:Destroy()
		return
	end
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(fadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = 0 }
	)
	tween.Completed:Once(function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	tween:Play()
	Debris:AddItem(sound, fadeSeconds + 1)
end

function ClientAudio._resetForTest()
	local sounds = {}
	for sound in activeSounds do
		table.insert(sounds, sound)
	end
	for _, sound in sounds do
		sound:Destroy()
	end
	levels.Master = AudioConfig.Mix.MasterVolume
	levels.Music = AudioConfig.Mix.MusicVolume
	levels.Effects = AudioConfig.Mix.EffectsVolume
end

local SETTING_TO_LEVEL = {
	MasterVolume = "Master",
	MusicVolume = "Music",
	EffectsVolume = "Effects",
}

local function applySetting(id: string)
	local level = SETTING_TO_LEVEL[id]
	if level == nil then
		return
	end
	local value = SettingsStore.get(id)
	if typeof(value) ~= "number" then
		return
	end
	levels[level] = normalizedVolume(value)
	refreshVolumes()
end

for id in SETTING_TO_LEVEL do
	applySetting(id)
end
SettingsStore.subscribe(applySetting)

return ClientAudio
