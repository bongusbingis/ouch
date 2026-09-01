-- Name: DeviceClass.luau
-- Author: Jack C.
-- Description: Single owner of client device-class resolution (Mouse/Touch/Gamepad): a pure decision over the input signals plus thin UserInputService samplers, so every consumer classifies the player the same way and a console that has produced no input yet still reads as Gamepad instead of defaulting to Mouse.
-- Created: 2026-09-01

--!strict

local DeviceClass = {}

export type Class = "Mouse" | "Touch" | "Gamepad"

export type Signals = {
	preferredInput: string?,
	lastInputType: string?,
	touchEnabled: boolean,
	keyboardEnabled: boolean,
	mouseEnabled: boolean,
	gamepadEnabled: boolean,
}

function DeviceClass.resolve(signals: Signals): Class
	local preferred = signals.preferredInput
	if preferred == "Touch" then
		return "Touch"
	elseif preferred == "Gamepad" then
		return "Gamepad"
	elseif preferred == "KeyboardAndMouse" then
		return "Mouse"
	end

	local last = signals.lastInputType
	if last == "Touch" then
		return "Touch"
	elseif last ~= nil and string.find(last, "Gamepad", 1, true) == 1 then
		return "Gamepad"
	elseif last ~= nil and (string.find(last, "Mouse", 1, true) == 1 or last == "Keyboard") then
		return "Mouse"
	end

	if signals.touchEnabled and not signals.keyboardEnabled then
		return "Touch"
	end
	if signals.gamepadEnabled and not signals.keyboardEnabled and not signals.mouseEnabled then
		return "Gamepad"
	end
	return "Mouse"
end

local function sample(): Signals
	local uis = game:GetService("UserInputService")
	local preferred: string? = nil
	local ok, value = pcall(function()
		return (uis :: any).PreferredInput
	end)
	if ok and typeof(value) == "EnumItem" then
		preferred = value.Name
	end
	return {
		preferredInput = preferred,
		lastInputType = uis:GetLastInputType().Name,
		touchEnabled = uis.TouchEnabled,
		keyboardEnabled = uis.KeyboardEnabled,
		mouseEnabled = uis.MouseEnabled,
		gamepadEnabled = uis.GamepadEnabled,
	}
end

function DeviceClass.current(): Class
	return DeviceClass.resolve(sample())
end

-- Fires the listener once immediately and again only when the resolved class
-- actually changes, so callers get inherent dedup rather than one event per raw
-- input. PreferredInput may be absent on old clients, hence the guarded connect.
function DeviceClass.observe(listener: (Class) -> ()): () -> ()
	local uis = game:GetService("UserInputService")
	local connections: { RBXScriptConnection } = {}
	local last: Class? = nil
	local function evaluate()
		local class = DeviceClass.current()
		if class ~= last then
			last = class
			listener(class)
		end
	end
	table.insert(connections, uis.LastInputTypeChanged:Connect(evaluate))
	local ok, signal = pcall(function()
		return uis:GetPropertyChangedSignal("PreferredInput")
	end)
	if ok and signal ~= nil then
		table.insert(connections, signal:Connect(evaluate))
	end
	evaluate()
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
end

return DeviceClass
