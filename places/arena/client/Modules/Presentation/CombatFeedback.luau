-- Name: CombatFeedback.luau
-- Author: Jack C.
-- Description: Plays the short local confirmation feedback for combat inputs: haptic pulses, charge cues, and 2D audio for throws, catches, and blocked actions.
-- Created: 2026-08-22

--!strict

local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ThrowUX = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThrowUX"))
local UIFeedback = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback")
)
local ClientAudio = require(script.Parent.ClientAudio)

local CombatFeedback = {}
local random = Random.new()
local motorRevisions: { [Enum.VibrationMotor]: number } = {}
local motorDevices: { [Enum.VibrationMotor]: Enum.UserInputType } = {}
local chargeSound: Sound? = nil

local function inputType(): Enum.UserInputType
	local current = UserInputService:GetLastInputType()
	if string.find(current.Name, "Gamepad", 1, true) == 1 then
		return current
	end
	return if current == Enum.UserInputType.Touch then current else Enum.UserInputType.MouseButton1
end

local function haptic(name: string)
	if not ThrowUX.Haptics.Enabled then
		return
	end
	local definition = (ThrowUX.Haptics :: any)[name]
	if definition == nil then
		return
	end
	local device = inputType()
	if device == Enum.UserInputType.Touch then
		UIFeedback.haptic(definition.TouchEffect)
		return
	end
	local supported = false
	pcall(function()
		supported = HapticService:IsMotorSupported(device, definition.Motor)
	end)
	if not supported then
		return
	end
	local revision = (motorRevisions[definition.Motor] or 0) + 1
	motorRevisions[definition.Motor] = revision
	motorDevices[definition.Motor] = device
	pcall(function()
		HapticService:SetMotor(device, definition.Motor, definition.Strength)
	end)
	task.delay(definition.Seconds, function()
		if motorRevisions[definition.Motor] == revision then
			pcall(function()
				HapticService:SetMotor(device, definition.Motor, 0)
			end)
		end
	end)
end

local function audio(name: string)
	local definition = (ThrowUX.Audio :: any)[name]
	if definition == nil or #definition.AssetIds == 0 then
		return
	end
	local id = definition.AssetIds[random:NextInteger(1, #definition.AssetIds)]
	local assetId = tostring(id)
	if string.find(assetId, "rbxassetid://", 1, true) ~= 1 then
		assetId = `rbxassetid://{assetId}`
	end
	ClientAudio.play({
		name = `ThrowUX{name}`,
		assetId = assetId,
		category = "Effects",
		volume = definition.Volume,
		maxLifetimeSeconds = 4,
	})
end

function CombatFeedback.setCharge(alpha: number)
	local definition = ThrowUX.Audio.ChargeBuild
	if alpha <= 0 or #definition.AssetIds == 0 then
		if chargeSound then
			ClientAudio.stop(chargeSound, 0.08)
			chargeSound = nil
		end
		return
	end
	if chargeSound == nil then
		local id = tostring(definition.AssetIds[random:NextInteger(1, #definition.AssetIds)])
		if string.find(id, "rbxassetid://", 1, true) ~= 1 then
			id = `rbxassetid://{id}`
		end
		chargeSound = ClientAudio.play({
			name = "ThrowUXChargeBuild",
			assetId = id,
			category = "Effects",
			volume = definition.Volume,
			looped = true,
			destroyOnEnded = false,
		})
	end
	chargeSound.PlaybackSpeed = definition.BasePlaybackSpeed
		+ (definition.MaxPlaybackSpeed - definition.BasePlaybackSpeed) * math.clamp(alpha, 0, 1)
end

function CombatFeedback.play(name: string)
	haptic(name)
	audio(name)
end

function CombatFeedback.destroy()
	CombatFeedback.setCharge(0)
	for motor in motorRevisions do
		local device = motorDevices[motor] or inputType()
		pcall(function()
			HapticService:SetMotor(device, motor, 0)
		end)
	end
	table.clear(motorRevisions)
	table.clear(motorDevices)
end

return CombatFeedback
