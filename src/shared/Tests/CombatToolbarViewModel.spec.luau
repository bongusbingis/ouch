--!strict

local T = require(script.Parent.TestKit)
local ViewModel = require(script.Parent.Parent.UI.Models.CombatToolbarViewModel)

local function snapshot(overrides)
	local value = {
		active = true,
		weapon = "Hammer",
		holdsBall = false,
		ready = false,
		throwCooldown = 0,
		hammerCooldown = 0,
		weaponLocked = false,
	}
	for key, item in overrides or {} do
		value[key] = item
	end
	return value
end

T.describe("CombatToolbarViewModel", function()
	T.it("keeps both slots stable when no ball is held", function()
		local model = ViewModel.fromSnapshot(snapshot(), "Touch")
		T.expect(model.visible):toBeTruthy()
		T.expect(#model.slots):toEqual(2)
		T.expect(model.slots[1].weapon):toEqual("Dodgeball")
		T.expect(model.slots[1].available):toBeFalsy()
		T.expect(model.slots[2].weapon):toEqual("Hammer")
	end)

	T.it("marks the held dodgeball equipped without changing slot order", function()
		local model = ViewModel.fromSnapshot(snapshot({ weapon = "Dodgeball", holdsBall = true }), "Mouse")
		T.expect(#model.slots):toEqual(2)
		T.expect(model.slots[1].inputLabel):toEqual("2")
		T.expect(model.slots[2].inputLabel):toEqual("1")
		T.expect(model.slots[1].equipped):toBeTruthy()
	end)

	T.it("uses touch presentation without keyboard labels", function()
		local model = ViewModel.fromSnapshot(snapshot({ holdsBall = true }), "Touch")
		for _, slot in model.slots do
			T.expect(slot.inputLabel):toBeNil()
		end
	end)

	T.it("uses gamepad labels and stays passive", function()
		local model = ViewModel.fromSnapshot(snapshot({ holdsBall = true }), "Gamepad")
		T.expect(model.slots[1].interactive):toBeFalsy()
		T.expect(model.slots[2].interactive):toBeFalsy()
		T.expect(model.slots[1].inputLabel):toEqual("R1")
		T.expect(model.slots[2].inputLabel):toEqual("L1")
	end)
end)

return true
