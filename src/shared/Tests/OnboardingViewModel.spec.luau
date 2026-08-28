-- Name: OnboardingViewModel.spec.luau
-- Author: Jack C.
-- Description: Spec for what the training UI shows: the headline on the panel, the gesture notation for the device actually in the player's hands, and the hint that only appears once they are stuck.
-- Created: 2026-08-27

--!strict

local T = require(script.Parent.TestKit)
local OnboardingViewModel = require(script.Parent.Parent.UI.Models.OnboardingViewModel)
local OnboardingConfig = require(script.Parent.Parent.Parent.Config.Onboarding)
local ThrowUX = require(script.Parent.Parent.Parent.Config.ThrowUX)

local function snapshot(overrides)
	local base = {
		route = "Training",
		stepId = "NormalThrow",
		prompt = "",
		success = "",
		hint = "",
		deviceClass = "Mouse",
		celebrating = false,
		partyReady = false,
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

	T.it("replaces the prompt with the success beat while it is on screen", function()
		T.expect(OnboardingViewModel.prompt(snapshot({ success = "NICE!" })).headline):toEqual("NICE!")
	end)

	T.it("shows nothing outside training, during the celebration, or on an unknown step", function()
		T.expect(OnboardingViewModel.prompt(snapshot({ route = "Lobby" })).visible):toEqual(false)
		T.expect(OnboardingViewModel.prompt(snapshot({ celebrating = true })).visible):toEqual(false)
		T.expect(OnboardingViewModel.prompt(snapshot({ stepId = "Lob" })).visible):toEqual(false)
	end)

	T.it("gets out of the way of the party choice", function()
		T.expect(OnboardingViewModel.prompt(snapshot({ partyReady = true })).visible):toEqual(false)
	end)
end)

T.describe("Onboarding gesture indicator", function()
	T.it("draws a tap for a touch player and never a mouse button", function()
		local gesture = OnboardingViewModel.gesture(snapshot({ deviceClass = "Touch" }))
		T.expect((gesture :: any).kind):toEqual("Tap")
		T.expect((gesture :: any).label):toEqual("TAP")
	end)

	T.it("draws the held ring on the charge lesson for a touch player", function()
		local gesture = OnboardingViewModel.gesture(snapshot({ deviceClass = "Touch", stepId = "ChargedThrow" }))
		T.expect((gesture :: any).kind):toEqual("Hold")
		T.expect((gesture :: any).label):toEqual("HOLD")
	end)

	T.it("hands the glyph to the engine's binding art on mouse and gamepad", function()
		T.expect((OnboardingViewModel.gesture(snapshot()) :: any).kind):toEqual("Action")
		T.expect((OnboardingViewModel.gesture(snapshot({ deviceClass = "Gamepad" })) :: any).kind):toEqual("Action")
	end)

	T.it("wraps that glyph in the held ring on the charge lesson", function()
		for _, device in { "Mouse", "Gamepad" } do
			local gesture = OnboardingViewModel.gesture(snapshot({ deviceClass = device, stepId = "ChargedThrow" }))
			T.expect((gesture :: any).kind):toEqual("ActionHold")
			T.expect((gesture :: any).label):toEqual("HOLD")
		end
	end)

	T.it("names the verb in the language of the device being used", function()
		T.expect((OnboardingViewModel.gesture(snapshot({ deviceClass = "Mouse" })) :: any).label):toEqual("CLICK")
		T.expect((OnboardingViewModel.gesture(snapshot({ deviceClass = "Gamepad" })) :: any).label):toEqual("PRESS")
	end)

	T.it("carries a fallback for when the engine cannot resolve a glyph", function()
		T.expect((OnboardingViewModel.gesture(snapshot({ deviceClass = "Mouse" })) :: any).fallback):toEqual("LMB")
		T.expect((OnboardingViewModel.gesture(snapshot({ deviceClass = "Gamepad" })) :: any).fallback):toEqual("RT")
	end)

	T.it("teaches the same primary attack input on every lesson but the charge", function()
		for _, stepId in { "NormalThrow", "Hammer", "Practice" } do
			T.expect((OnboardingViewModel.gesture(snapshot({ stepId = stepId })) :: any).kind):toEqual("Action")
		end
	end)

	T.it("falls back to the mouse row for a device it does not know", function()
		T.expect((OnboardingViewModel.gesture(snapshot({ deviceClass = "Telepathy" })) :: any).fallback):toEqual("LMB")
	end)

	T.it("shows nothing while the success beat plays, so the payoff is not covered", function()
		T.expect(OnboardingViewModel.gesture(snapshot({ success = "NICE!" }))):toBeNil()
	end)

	T.it("shows nothing outside training, during the celebration, or under the party choice", function()
		T.expect(OnboardingViewModel.gesture(snapshot({ route = "Lobby" }))):toBeNil()
		T.expect(OnboardingViewModel.gesture(snapshot({ celebrating = true }))):toBeNil()
		T.expect(OnboardingViewModel.gesture(snapshot({ partyReady = true }))):toBeNil()
	end)
end)

-- Every viewport the game is actually played on. The placement rule is checked
-- against all of them rather than eyeballed on one.
local VIEWPORTS = {
	{ name = "desktop", w = 1920, h = 1080 },
	{ name = "laptop", w = 1366, h = 768 },
	{ name = "phone landscape", w = 896, h = 414 },
	{ name = "small phone landscape", w = 844, h = 390 },
	{ name = "tablet", w = 1180, h = 820 },
	{ name = "tablet portrait", w = 820, h = 1180 },
}

local INSET = 36

-- Sizes come from the same config the component reads, so tuning one cannot
-- quietly invalidate what this proves.
local function placementFor(view)
	local sizing = OnboardingConfig.UI.Gesture
	local reticleConfig = ThrowUX.Reticle
	local shortest = math.min(view.w, view.h)
	local glyph = math.clamp(shortest * sizing.SizeScale, sizing.MinPixels, sizing.MaxPixels)
	local reticle = math.clamp(shortest * reticleConfig.SizeScale, reticleConfig.MinPixels, reticleConfig.MaxPixels)
		* reticleConfig.FullChargeScale
		/ 2
	local input = {
		viewportWidth = view.w,
		viewportHeight = view.h,
		pressCenterX = view.w / 2,
		pressCenterY = (INSET + view.h) / 2,
		swipeTopY = view.h - view.h * 0.28,
		reticleRadius = reticle,
		glyphSize = glyph,
		labelHeight = glyph * sizing.LabelScale,
		clearance = sizing.ClearancePixels,
	}
	return OnboardingViewModel.gesturePlacement(input), input
end

T.describe("Onboarding gesture placement", function()
	T.it("never runs into the region a swipe has to start in", function()
		for _, view in VIEWPORTS do
			local placement, input = placementFor(view)
			local bottom = placement.y + input.glyphSize / 2 + input.labelHeight
			T.expect(bottom <= input.swipeTopY):toBeTruthy()
		end
	end)

	T.it("never covers the reticle", function()
		for _, view in VIEWPORTS do
			local placement, input = placementFor(view)
			local dx = math.abs(placement.x - input.pressCenterX)
			local dy = math.abs(placement.y - input.pressCenterY)
			local clears = dx >= input.reticleRadius + input.glyphSize / 2
				or dy >= input.reticleRadius + input.glyphSize / 2
			T.expect(clears):toBeTruthy()
		end
	end)

	T.it("stays on screen", function()
		for _, view in VIEWPORTS do
			local placement, input = placementFor(view)
			local half = input.glyphSize / 2
			T.expect(placement.x - half >= 0):toBeTruthy()
			T.expect(placement.x + half <= view.w):toBeTruthy()
			T.expect(placement.y - half >= 0):toBeTruthy()
			T.expect(placement.y + half <= view.h):toBeTruthy()
		end
	end)

	T.it("sits under the reticle wherever there is room for it", function()
		for _, view in { VIEWPORTS[1], VIEWPORTS[2], VIEWPORTS[5], VIEWPORTS[6] } do
			local placement = placementFor(view)
			T.expect(placement.beside):toEqual(false)
			T.expect(placement.x):toEqual(view.w / 2)
		end
	end)

	T.it("steps beside the reticle on a viewport too short to fit below it", function()
		for _, view in { VIEWPORTS[3], VIEWPORTS[4] } do
			local placement, input = placementFor(view)
			T.expect(placement.beside):toBeTruthy()
			T.expect(math.abs(placement.x - input.pressCenterX) > input.reticleRadius):toBeTruthy()
		end
	end)

	T.it("steps to the far side rather than off screen on a narrow viewport", function()
		local input = {
			viewportWidth = 240,
			viewportHeight = 200,
			pressCenterX = 230,
			pressCenterY = 100,
			swipeTopY = 150,
			reticleRadius = 30,
			glyphSize = 44,
			labelHeight = 24,
			clearance = 16,
		}
		local placement = OnboardingViewModel.gesturePlacement(input)
		T.expect(placement.x + input.glyphSize / 2 <= input.viewportWidth):toBeTruthy()
		T.expect(placement.x - input.glyphSize / 2 >= 0):toBeTruthy()
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
