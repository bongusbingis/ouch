--!strict

local T = require(script.Parent.TestKit)
local ViewModel = require(script.Parent.Parent.UI.Models.CombatToolbarViewModel)

local function snapshot(overrides)
	local value = {
		active = true,
		weapon = "Hammer",
		holdsBall = false,
		throwCooldown = 0,
		hammerCooldown = 0,
		weaponLocked = false,
		throwState = "Idle",
		chargeAlpha = 0,
	}
	for key, item in overrides or {} do
		value[key] = item
	end
	return value
end

T.describe("CombatToolbarViewModel", function()
	T.it("keeps both action slots stable and marks a missing ball unavailable", function()
		local model = ViewModel.fromSnapshot(snapshot(), "Touch")
		T.expect(model.visible):toBeTruthy()
		T.expect(#model.slots):toEqual(2)
		T.expect(model.slots[1].weapon):toEqual("Hammer")
		T.expect(model.slots[1].selected):toBeTruthy()
		T.expect(model.slots[2].weapon):toEqual("Dodgeball")
		T.expect(model.slots[2].state.kind):toEqual("Unavailable")
	end)

	T.it("keeps selection orthogonal to readiness state", function()
		local model =
			ViewModel.fromSnapshot(snapshot({ weapon = "Dodgeball", holdsBall = true, throwCooldown = 0.2 }), "Mouse")
		T.expect(model.slots[2].selected):toBeTruthy()
		T.expect(model.slots[2].state.kind):toEqual("Cooldown")
		T.expect(((model.slots[2].state :: any).progress > 0)):toBeTruthy()
	end)

	T.it("distinguishes a tutorial lock from temporary unavailability", function()
		local model =
			ViewModel.fromSnapshot(snapshot({ weapon = "Dodgeball", holdsBall = true, weaponLocked = true }), "Mouse")
		T.expect(model.slots[1].state.kind):toEqual("Locked")
		T.expect(model.slots[2].state.kind):toEqual("Ready")
	end)

	T.it("projects selected dodgeball charge without duplicating its owner", function()
		local model = ViewModel.fromSnapshot(
			snapshot({ weapon = "Dodgeball", holdsBall = true, throwState = "Charging", chargeAlpha = 0.65 }),
			"Mouse"
		)
		T.expect(model.slots[2].state.kind):toEqual("Charging")
		T.expect((model.slots[2].state :: any).progress):toBeNear(0.65, 1e-9)
		T.expect(model.slots[1].state.kind):toEqual("Ready")
	end)

	T.it("normalizes cooldown progress from empty to ready", function()
		local cooling = ViewModel.fromSnapshot(snapshot({ hammerCooldown = 0.5 }), "Mouse")
		T.expect(cooling.slots[1].state.kind):toEqual("Cooldown")
		local progress = (cooling.slots[1].state :: any).progress
		T.expect(progress >= 0 and progress < 1):toBeTruthy()
	end)

	T.it("uses configured keyboard and gamepad prompts", function()
		local keyboard = ViewModel.fromSnapshot(snapshot({ holdsBall = true }), "Mouse")
		T.expect(keyboard.slots[1].weapon):toEqual("Hammer")
		T.expect(keyboard.slots[1].inputLabel):toEqual("1")
		T.expect(keyboard.slots[1].inputKeyCode):toEqual(Enum.KeyCode.One)
		T.expect(keyboard.slots[2].weapon):toEqual("Dodgeball")
		T.expect(keyboard.slots[2].inputLabel):toEqual("2")
		T.expect(keyboard.slots[2].inputKeyCode):toEqual(Enum.KeyCode.Two)

		local gamepad = ViewModel.fromSnapshot(snapshot({ holdsBall = true }), "Gamepad")
		T.expect(gamepad.slots[1].inputLabel):toEqual("L1")
		T.expect(gamepad.slots[1].inputKeyCode):toEqual(Enum.KeyCode.ButtonL1)
		T.expect(gamepad.slots[2].inputLabel):toEqual("R1")
		T.expect(gamepad.slots[2].inputKeyCode):toEqual(Enum.KeyCode.ButtonR1)
		T.expect(gamepad.slots[1].interactive):toBeFalsy()
	end)

	T.it("keeps touch prompts hidden and only unequipped usable actions interactive", function()
		local touch = ViewModel.fromSnapshot(snapshot({ holdsBall = true }), "Touch")
		T.expect(touch.slots[1].inputLabel):toBeNil()
		T.expect(touch.slots[1].interactive):toBeFalsy()
		T.expect(touch.slots[2].inputLabel):toBeNil()
		T.expect(touch.slots[2].interactive):toBeTruthy()
	end)

	T.it("projects disabled state while the hidden HUD is inactive", function()
		local model = ViewModel.fromSnapshot(snapshot({ active = false }), "Mouse")
		T.expect(model.visible):toBeFalsy()
		T.expect(model.slots[1].state.kind):toEqual("Disabled")
		T.expect(model.slots[2].state.kind):toEqual("Disabled")
	end)
end)

T.describe("CombatToolbar responsive layout", function()
	T.it("caps desktop and ultrawide growth", function()
		local desktop = ViewModel.layout(Vector2.new(1920, 1080), "Mouse")
		local ultrawide = ViewModel.layout(Vector2.new(3440, 1440), "Mouse")
		T.expect(desktop.width):toEqual(332)
		T.expect(ultrawide.width):toEqual(332)
		T.expect(desktop.height >= 105 and desktop.height <= 106):toBeTruthy()
	end)

	T.it("keeps phone and tablet touch targets compact but usable", function()
		for _, viewport in { Vector2.new(896, 414), Vector2.new(844, 390), Vector2.new(1180, 820) } do
			local layout = ViewModel.layout(viewport, "Touch")
			T.expect(layout.width >= 260 and layout.width <= 350):toBeTruthy()
			T.expect(layout.height >= 95 and layout.height <= 117):toBeTruthy()
		end
	end)

	T.it("stays compact and legible at the onboarding capture resolution", function()
		local layout = ViewModel.layout(Vector2.new(1223, 875), "Mouse")
		T.expect(layout.width):toBeNear(330.21, 0.01)
		T.expect(layout.height):toBeNear(104.83, 0.01)
	end)

	T.it("fits a portrait phone without spanning the screen", function()
		local layout = ViewModel.layout(Vector2.new(390, 844), "Touch")
		T.expect(layout.width < 390):toBeTruthy()
		T.expect(layout.bottomGap >= 8):toBeTruthy()
	end)
end)

return true
