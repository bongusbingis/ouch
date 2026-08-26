-- Name: ThrowUXViewModel.spec.luau
-- Author: Jack C.
-- Description: Spec for the throw HUD view model: ready, pending, charging, and full-charge states, cancel and release feedback priority, and clamped cooldown presentation.
-- Created: 2026-08-22

--!strict

local T = require(script.Parent.TestKit)
local ViewModel = require(script.Parent.Parent.UI.Models.ThrowUXViewModel)

local function input(overrides)
	local value = {
		weapon = "Dodgeball",
		holdsBall = true,
		combatState = "Aiming",
		chargeAlpha = 0,
		throwCooldown = 0,
		ready = true,
		pendingInput = false,
		releaseActive = false,
		cancelActive = false,
	}
	for key, item in overrides or {} do
		value[key] = item
	end
	return value
end

T.describe("ThrowUXViewModel", function()
	T.it("derives ready, pending, charging, and full charge states", function()
		T.expect(ViewModel.state(input())):toEqual("Ready")
		T.expect(ViewModel.state(input({ pendingInput = true }))):toEqual("PendingInput")
		T.expect(ViewModel.state(input({ combatState = "Charging", chargeAlpha = 0.5 }))):toEqual("Charging")
		T.expect(ViewModel.state(input({ combatState = "Charging", chargeAlpha = 1 }))):toEqual("FullCharge")
	end)

	T.it("prioritizes cancel and release feedback over steady state", function()
		T.expect(ViewModel.state(input({ cancelActive = true, combatState = "Charging" }))):toEqual("Cancelled")
		T.expect(ViewModel.state(input({ releaseActive = true }))):toEqual("Release")
	end)

	T.it("derives recovery and clamps cooldown presentation", function()
		T.expect(ViewModel.state(input({ throwCooldown = 0.2, ready = false }))):toEqual("Recovery")
		T.expect(ViewModel.cooldownAlpha(0.3, 0.6)):toBeNear(0.5)
		T.expect(ViewModel.cooldownAlpha(2, 0.6)):toEqual(1)
	end)
end)

return true
