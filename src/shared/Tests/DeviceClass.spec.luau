-- Description: Spec for device-class resolution: PreferredInput priority, last-input fallback, and the capability last resort that keeps a fresh console on Gamepad instead of Mouse.

--!strict

local T = require(script.Parent.TestKit)
local DeviceClass = require(script.Parent.Parent.Game.Input.DeviceClass)

local function signals(overrides: { [string]: any }): DeviceClass.Signals
	local base = {
		preferredInput = nil,
		lastInputType = nil,
		touchEnabled = false,
		keyboardEnabled = false,
		mouseEnabled = false,
		gamepadEnabled = false,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base
end

T.describe("DeviceClass", function()
	T.it("prefers PreferredInput over the last input type and capability", function()
		T.expect(DeviceClass.resolve(signals({
			preferredInput = "Gamepad",
			lastInputType = "MouseMovement",
			keyboardEnabled = true,
			mouseEnabled = true,
		}))):toEqual("Gamepad")
		T.expect(DeviceClass.resolve(signals({ preferredInput = "Touch", lastInputType = "Keyboard" })))
			:toEqual("Touch")
		T.expect(DeviceClass.resolve(signals({ preferredInput = "KeyboardAndMouse", lastInputType = "Touch" })))
			:toEqual("Mouse")
	end)

	T.it("classifies a console with no input yet as Gamepad, not Mouse", function()
		T.expect(DeviceClass.resolve(signals({ lastInputType = "None", gamepadEnabled = true }))):toEqual("Gamepad")
	end)

	T.it("falls back to the last input type when PreferredInput is absent", function()
		T.expect(
			DeviceClass.resolve(signals({ lastInputType = "Gamepad1", gamepadEnabled = true, keyboardEnabled = true }))
		)
			:toEqual("Gamepad")
		T.expect(DeviceClass.resolve(signals({ lastInputType = "Touch", touchEnabled = true }))):toEqual("Touch")
		T.expect(DeviceClass.resolve(signals({ lastInputType = "MouseButton1", mouseEnabled = true }))):toEqual("Mouse")
		T.expect(DeviceClass.resolve(signals({ lastInputType = "Keyboard", keyboardEnabled = true }))):toEqual("Mouse")
	end)

	T.it("uses device capability only as a last resort", function()
		T.expect(DeviceClass.resolve(signals({ touchEnabled = true }))):toEqual("Touch")
		T.expect(DeviceClass.resolve(signals({ touchEnabled = true, keyboardEnabled = true }))):toEqual("Mouse")
		T.expect(DeviceClass.resolve(signals({}))):toEqual("Mouse")
	end)
end)

return true
