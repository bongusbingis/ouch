--!strict

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

-- Mouse and gamepad combat input, classified on the same rhythm as touch.
--
-- Every device answers the same two questions -- was that a quick press or a
-- held one -- so a player moving between mouse, controller and phone keeps the
-- same muscle memory. The thresholds are shared with touch deliberately: if a
-- hold became a charge at different times per device, one device would have a
-- strictly faster charged throw.
--
-- Nothing here knows what a throw does. It reports intent and stops.

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

-- Weapon slots, numbered as the HUD shows them: slot 1 is the hammer, slot 2 is
-- the dodgeball. The controller bumpers describe the same pair in the same
-- order, LB before RB, so the two devices agree on which slot is which.
local EQUIP_HAMMER_KEY = Enum.KeyCode.One
local EQUIP_DODGEBALL_KEY = Enum.KeyCode.Two
local EQUIP_HAMMER_GAMEPAD = Enum.KeyCode.ButtonL1
local EQUIP_DODGEBALL_GAMEPAD = Enum.KeyCode.ButtonR1

local started = false
local handlers: Handlers? = nil
local isEnabled: () -> boolean = function()
	return false
end

-- One press at a time per device family, tracked as a small record rather than
-- a bare boolean so a missed release cannot strand a charge.
local pressedAt: number? = nil
local charging = false
local triggerHeld = false

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
	-- Released before the hold threshold: a quick press, which is the normal
	-- throw. No duration ceiling here, unlike touch -- a mouse cannot drift, so
	-- there is no ambiguity to protect against.
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

local function step()
	if pressedAt == nil or charging then
		return
	end
	if os.clock() - pressedAt >= CombatConfig.Charge.HoldDelay then
		charging = true
		fire("onBeginCharge")
	end
end

-- Analog triggers rest near their threshold and jitter across it. Separate
-- press and release points mean the state can only flip after a deliberate
-- change of pressure, rather than chattering and spamming throws.
local function updateTrigger(position: number)
	local config = CombatConfig.Controller
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
		-- sunk means a UI element took it. Clicking a button must never throw,
		-- and typing must never change weapon.
		if sunk then
			return
		end
		-- Choosing a slot is not an attack, so it is deliberately not gated on
		-- combat being live: a player sets their loadout during the countdown or
		-- while the vote holds the cursor, which is exactly when they want to. The
		-- server accepts an equip outside an active match for the same reason, and
		-- the HUD slots call in ungated too -- all three agree.
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
		elseif input.KeyCode == HAMMER_GAMEPAD_BUTTON then
			fire("onHammer")
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		-- Deliberately not gated on isEnabled: a release must always be able to
		-- resolve a press that began while combat was live, or the charge sticks.
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			endPress()
		end
	end)

	UserInputService.InputChanged:Connect(function(input, sunk)
		if input.KeyCode ~= THROW_GAMEPAD_BUTTON then
			return
		end
		if sunk or not isEnabled() then
			-- Treat a disabled trigger as released so it cannot resume mid-hold.
			if triggerHeld then
				triggerHeld = false
				cancelPress()
			end
			return
		end
		updateTrigger(input.Position.Z)
	end)

	-- A controller unplugged mid-charge never sends a release.
	UserInputService.GamepadDisconnected:Connect(cancelPress)
	UserInputService.WindowFocusReleased:Connect(cancelPress)

	RunService.Heartbeat:Connect(step)
end

return DeviceInput
