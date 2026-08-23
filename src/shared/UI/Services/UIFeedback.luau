--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))

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

local function getSoundIds(config: SoundIdConfig): { string }
	if type(config) == "string" then
		return { config }
	end

	assert(#config > 0, "[UIFeedback] Sound ID arrays cannot be empty")
	return config
end

local function playSound(options: { Sound }?)
	if not options or #options == 0 then
		return
	end

	for _, option in options do
		option:Stop()
	end

	local sound = options[random:NextInteger(1, #options)]
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
		local soundIds = getSoundIds(soundIdConfig)
		local options: { Sound } = {}
		for index, soundId in soundIds do
			assert(soundId ~= "", "[UIFeedback] Sound IDs cannot be empty")
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
