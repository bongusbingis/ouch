--!strict

local T = require(script.Parent.TestKit)
local ViewModel = require(script.Parent.Parent.UI.Models.CombatToolbarViewModel)

local function snapshot(overrides)
	local value = {
		weapon = "Hammer",
		holdsBall = false,
		ready = false,
		throwCooldown = 0,
	}
	for key, item in overrides or {} do
		value[key] = item
	end
	return value
end

T.describe("CombatToolbarViewModel", function()
	T.it("shows only the hammer when no ball is held", function()
		local model = ViewModel.fromSnapshot(snapshot(), "Touch")
		T.expect(model.visible):toBeTruthy()
		T.expect(#model.slots):toEqual(1)
		T.expect(model.slots[1].weapon):toEqual("Hammer")
		T.expect(model.interactive):toBeTruthy()
	end)

	T.it("shows the dodgeball only while a ball is held", function()
		local model = ViewModel.fromSnapshot(snapshot({ weapon = "Dodgeball", holdsBall = true }), "Mouse")
		T.expect(#model.slots):toEqual(2)
		T.expect(model.slots[1].inputLabel):toEqual("2")
		T.expect(model.slots[2].inputLabel):toEqual("1")
		T.expect(model.slots[1].equipped):toBeTruthy()
	end)

	T.it("uses touch presentation without keyboard labels", function()
		local model = ViewModel.fromSnapshot(snapshot({ holdsBall = true }), "Touch")
		T.expect(model.interactive):toBeTruthy()
		for _, slot in model.slots do
			T.expect(slot.inputLabel):toBeNil()
		end
	end)

	T.it("uses gamepad labels and stays passive", function()
		local model = ViewModel.fromSnapshot(snapshot({ holdsBall = true }), "Gamepad")
		T.expect(model.interactive):toBeFalsy()
		T.expect(model.slots[1].inputLabel):toEqual("2")
		T.expect(model.slots[2].inputLabel):toEqual("L1")
	end)
end)

return true
