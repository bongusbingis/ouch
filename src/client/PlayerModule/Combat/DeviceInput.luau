-- Name: DeviceInput.luau
-- Author: Jack C.
-- Description: Translates raw mouse, keyboard, and gamepad input into combat press, release, and cancel callbacks, including the analog trigger handling.
-- Created: 2026-08-20

--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))
local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Input"))

local DeviceInput = {}

export type Handlers = {
	onNormalThrow: () -> (),
	onBeginCharge: () -> (),
	onReleaseCharge: () -> (),
	onCancelCharge: () -> (),
	onHammer: () -> (),
	onEquipHammer: () -> (),
	onEquipDodgeball: () -> (),
}

local THROW_GAMEPAD_BUTTON = Enum.KeyCode.ButtonR2
local HAMMER_GAMEPAD_BUTTON = Enum.KeyCode.ButtonX
local CANCEL_GAMEPAD_BUTTON = Enum.KeyCode.ButtonB

local EQUIP_HAMMER_KEY = InputConfig.WeaponEquip.Hammer.Keyboard
local EQUIP_DODGEBALL_KEY = InputConfig.WeaponEquip.Dodgeball.Keyboard
local EQUIP_HAMMER_GAMEPAD = InputConfig.WeaponEquip.Hammer.Gamepad
local EQUIP_DODGEBALL_GAMEPAD = InputConfig.WeaponEquip.Dodgeball.Gamepad

local started = false
local handlers: Handlers? = nil
local isEnabled: () -> boolean = function()
	return false
end

local pressedAt: number? = nil
local charging = false
local triggerHeld = false
-- Set when a press is deliberately cancelled while the analog trigger is still
-- past its press point, so the held trigger cannot immediately re-arm a new
-- press before it is released back below the threshold.
local triggerBlocked = false

local function fire(name: string)
	local resolved = handlers
	if resolved == nil then
		return
	end
	local callback = (resolved :: any)[name]
	if callback then
		local ok, err = pcall(callback)
		if not ok then
			warn("[CombatInput] handler " .. name .. " errored: " .. tostring(err))
		end
	end
end

local function beginPress()
	if pressedAt ~= nil then
		return
	end
	pressedAt = os.clock()
	charging = false
end

local function endPress()
	local startedAtValue = pressedAt
	pressedAt = nil
	if startedAtValue == nil then
		return
	end
	if charging then
		charging = false
		fire("onReleaseCharge")
		return
	end
	fire("onNormalThrow")
end

local function cancelPress()
	local wasCharging = charging
	pressedAt = nil
	charging = false
	triggerHeld = false
	if wasCharging then
		fire("onCancelCharge")
	end
end

local function requestCancel()
	if pressedAt == nil then
		return
	end
	if triggerHeld then
		triggerBlocked = true
	end
	cancelPress()
end

local function step()
	if pressedAt == nil or charging then
		return
	end
	if os.clock() - pressedAt >= CombatConfig.Charge.HoldDelay then
		charging = true
		fire("onBeginCharge")
	end
end

local function updateTrigger(position: number)
	local config = CombatConfig.Controller
	if triggerBlocked then
		if position <= config.TriggerReleaseThreshold then
			triggerBlocked = false
		end
		return
	end
	if not triggerHeld and position >= config.TriggerPressThreshold then
		triggerHeld = true
		beginPress()
	elseif triggerHeld and position <= config.TriggerReleaseThreshold then
		triggerHeld = false
		endPress()
	end
end

function DeviceInput.setHandlers(value: Handlers)
	handlers = value
end

function DeviceInput.setEnabledPredicate(predicate: () -> boolean)
	isEnabled = predicate
end

function DeviceInput.cancel()
	cancelPress()
end

function DeviceInput.start()
	if started then
		return
	end
	started = true

	UserInputService.InputBegan:Connect(function(input, sunk)
		if sunk then
			return
		end
		if input.KeyCode == EQUIP_HAMMER_KEY or input.KeyCode == EQUIP_HAMMER_GAMEPAD then
			fire("onEquipHammer")
			return
		elseif input.KeyCode == EQUIP_DODGEBALL_KEY or input.KeyCode == EQUIP_DODGEBALL_GAMEPAD then
			fire("onEquipDodgeball")
			return
		end

		if not isEnabled() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			beginPress()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == CANCEL_GAMEPAD_BUTTON then
			requestCancel()
		elseif input.KeyCode == HAMMER_GAMEPAD_BUTTON then
			fire("onHammer")
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			endPress()
		end
	end)

	UserInputService.InputChanged:Connect(function(input, sunk)
		if input.KeyCode ~= THROW_GAMEPAD_BUTTON then
			return
		end
		if sunk or not isEnabled() then
			if triggerHeld then
				triggerHeld = false
				cancelPress()
			end
			return
		end
		updateTrigger(input.Position.Z)
	end)

	UserInputService.GamepadDisconnected:Connect(cancelPress)
	UserInputService.WindowFocusReleased:Connect(cancelPress)

	RunService.Heartbeat:Connect(step)
end

return DeviceInput
