-- Name: OnboardingViewModel.spec.luau
-- Author: Jack C.
-- Description: Spec for what the training prompt shows: the right control for the device actually in the player's hands, the success beat, and the hint that only appears once they are stuck.
-- Created: 2026-08-27

--!strict

local T = require(script.Parent.TestKit)
local OnboardingViewModel = require(script.Parent.Parent.UI.Models.OnboardingViewModel)

local function snapshot(overrides)
	local base = {
		route = "Training",
		stepId = "NormalThrow",
		prompt = "",
		success = "",
		hint = "",
		deviceClass = "Mouse",
		celebrating = false,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

T.describe("Onboarding prompts", function()
	T.it("shouts the verb rather than explaining it", function()
		T.expect(OnboardingViewModel.prompt(snapshot()).headline):toEqual("THROW!")
		T.expect(OnboardingViewModel.prompt(snapshot({ stepId = "Hammer" })).headline):toEqual("BONK!")
		T.expect(OnboardingViewModel.prompt(snapshot({ stepId = "ChargedThrow" })).headline):toEqual("HOLD FOR POWER!")
	end)

	T.it("shows the mouse control to a mouse player", function()
		T.expect(OnboardingViewModel.prompt(snapshot()).glyph):toEqual("LMB")
	end)

	T.it("shows a tap to a touch player and never a mouse button", function()
		local prompt = OnboardingViewModel.prompt(snapshot({ deviceClass = "Touch" }))
		T.expect(prompt.glyph):toEqual("TAP")
	end)

	T.it("shows the controller trigger to a gamepad player", function()
		T.expect(OnboardingViewModel.prompt(snapshot({ deviceClass = "Gamepad" })).glyph):toEqual("RT")
		T.expect(OnboardingViewModel.prompt(snapshot({ deviceClass = "Gamepad", stepId = "Hammer" })).glyph)
			:toEqual("X")
	end)

	T.it("tells the charge step to hold on every device", function()
		for _, device in { "Mouse", "Touch", "Gamepad" } do
			local prompt = OnboardingViewModel.prompt(snapshot({ deviceClass = device, stepId = "ChargedThrow" }))
			local holds = prompt.glyph == "HOLD" or prompt.caption == "HOLD"
			T.expect(holds):toBeTruthy()
		end
	end)

	T.it("falls back to the mouse row for a device it does not know", function()
		T.expect(OnboardingViewModel.prompt(snapshot({ deviceClass = "Telepathy" })).glyph):toEqual("LMB")
	end)

	T.it("replaces the prompt with the success beat while it is on screen", function()
		local prompt = OnboardingViewModel.prompt(snapshot({ success = "NICE!" }))
		T.expect(prompt.headline):toEqual("NICE!")
		T.expect(prompt.glyph):toEqual("")
	end)

	T.it("shows nothing outside training, during the celebration, or on an unknown step", function()
		T.expect(OnboardingViewModel.prompt(snapshot({ route = "Lobby" })).visible):toEqual(false)
		T.expect(OnboardingViewModel.prompt(snapshot({ celebrating = true })).visible):toEqual(false)
		T.expect(OnboardingViewModel.prompt(snapshot({ stepId = "Lob" })).visible):toEqual(false)
	end)
end)

T.describe("Onboarding assistance", function()
	T.it("stays silent until the player is actually stuck", function()
		T.expect(OnboardingViewModel.hintText(snapshot())):toEqual("")
		T.expect(OnboardingViewModel.hintText(snapshot({ hint = "Nudge" }))):toEqual("")
	end)

	T.it("says one short line once assistance escalates", function()
		local text = OnboardingViewModel.hintText(snapshot({ hint = "Escalated" }))
		T.expect(#text > 0):toBeTruthy()
		T.expect(#text < 40):toBeTruthy()
	end)

	T.it("names the mechanic the player is failing at", function()
		T.expect(OnboardingViewModel.hintText(snapshot({ hint = "Escalated", stepId = "ChargedThrow" })))
			:toEqual("HOLD LONGER FOR MORE POWER")
	end)

	T.it("says nothing at all once the player has left training", function()
		T.expect(OnboardingViewModel.hintText(snapshot({ route = "Lobby", hint = "Escalated" }))):toEqual("")
	end)
end)

T.describe("Onboarding chrome", function()
	T.it("offers skip during training and nowhere else", function()
		T.expect(OnboardingViewModel.skipVisible(snapshot(), true)):toBeTruthy()
		T.expect(OnboardingViewModel.skipVisible(snapshot({ route = "Lobby" }), true)):toEqual(false)
		T.expect(OnboardingViewModel.skipVisible(snapshot({ celebrating = true }), true)):toEqual(false)
		T.expect(OnboardingViewModel.skipVisible(snapshot(), false)):toEqual(false)
	end)

	T.it("lists exactly the three mandatory mechanics on the completion card", function()
		local skills = OnboardingViewModel.completedSkills()
		T.expect(#skills):toEqual(3)
		T.expect(skills[1]):toEqual("THROW")
		T.expect(skills[2]):toEqual("BONK")
		T.expect(skills[3]):toEqual("POWER")
	end)
end)

return true
