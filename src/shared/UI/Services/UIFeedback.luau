-- Description: Owns the sound and haptic feedback for user interface interactions: hover, click, and notification cues shared by every component.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local SettingsStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Settings"):WaitForChild("SettingsStore")
)

local UIFeedback = {}

type SoundIdConfig = string | { string }

local effects: { [string]: HapticEffect } = {}
local sounds: { [string]: { Sound } } = {}
local lastHover = 0
local started = false
local random = Random.new()

local TYPES = {
	Hover = Enum.HapticEffectType.UIHover,
	Click = Enum.HapticEffectType.UIClick,
	Notification = Enum.HapticEffectType.UINotification,
}

local SOUND_IDS: { [string]: SoundIdConfig } = {
	Hover = UIConfig.Feedback.HoverSoundId,
	Click = UIConfig.Feedback.ClickSoundId,
}

local function getSoundIds(name: string, config: any): { string }
	if type(config) == "string" then
		if config ~= "" then
			return { config }
		end
		warn(`[UIFeedback] {name} feedback sound is empty; skipping this cue`)
		return {}
	end
	if type(config) ~= "table" then
		warn(`[UIFeedback] {name} feedback sound is missing or invalid; skipping this cue`)
		return {}
	end

	local soundIds: { string } = {}
	for index, soundId in config do
		if type(soundId) == "string" and soundId ~= "" then
			table.insert(soundIds, soundId)
		else
			warn(`[UIFeedback] {name} feedback sound at index {tostring(index)} is invalid; skipping it`)
		end
	end
	if #soundIds == 0 then
		warn(`[UIFeedback] {name} feedback sound has no usable entries; skipping this cue`)
	end
	return soundIds
end

local function playSound(options: { Sound }?)
	if not options or #options == 0 then
		return
	end

	for _, option in options do
		option:Stop()
	end

	local sound = options[random:NextInteger(1, #options)]
	sound.Volume = UIConfig.Feedback.Volume * SettingsStore.get("MasterVolume") * SettingsStore.get("EffectsVolume")
	SoundService:PlayLocalSound(sound)
end

function UIFeedback.start()
	if started then
		return
	end
	started = true

	for name, effectType in TYPES do
		local effect = Instance.new("HapticEffect")
		effect.Name = `LobbyUI{name}`
		effect.Type = effectType
		effect.Looped = false
		effect.Parent = Workspace
		effects[name] = effect
	end

	for name, soundIdConfig in SOUND_IDS do
		local soundIds = getSoundIds(name, soundIdConfig)
		local options: { Sound } = {}
		for index, soundId in soundIds do
			local sound = Instance.new("Sound")
			sound.Name = if #soundIds == 1 then `UI{name}` else `UI{name}{index}`
			sound.SoundId = soundId
			sound.Parent = SoundService
			table.insert(options, sound)
		end
		sounds[name] = options
	end
end

function UIFeedback.hover()
	local now = os.clock()
	if now - lastHover < 0.04 then
		return
	end
	lastHover = now
	local effect = effects.Hover
	if effect then
		effect:Play()
	end
	playSound(sounds.Hover)
end

function UIFeedback.click()
	local effect = effects.Click
	if effect then
		effect:Play()
	end
	playSound(sounds.Click)
end

function UIFeedback.notification()
	local effect = effects.Notification
	if effect then
		effect:Play()
	end
end

function UIFeedback.haptic(name: "Hover" | "Click" | "Notification")
	local effect = effects[name]
	if effect then
		effect:Play()
	end
end

function UIFeedback.destroy()
	for name, options in sounds do
		for _, sound in options do
			sound:Destroy()
		end
		sounds[name] = nil
	end
	for name, effect in effects do
		effect:Destroy()
		effects[name] = nil
	end
	lastHover = 0
	started = false
end

return UIFeedback
