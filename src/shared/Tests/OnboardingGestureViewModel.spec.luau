--!strict

local T = require(script.Parent.TestKit)
local ViewModel = require(script.Parent.Parent.UI.Models.OnboardingGestureViewModel)

T.describe("Onboarding gesture notation", function()
	T.it("teaches the swipe-up throw, hold charge, and tap bonk on touch", function()
		T.expect((ViewModel.forCue("Throw", "Touch") :: any).kind):toEqual("Swipe")
		T.expect((ViewModel.forCue("Throw", "Touch") :: any).label):toEqual("SWIPE UP")
		T.expect((ViewModel.forCue("Charge", "Touch") :: any).kind):toEqual("Hold")
		T.expect((ViewModel.forCue("Bonk", "Touch") :: any).kind):toEqual("Tap")
	end)

	T.it("draws no floating gesture on mouse or gamepad", function()
		T.expect(ViewModel.forCue("Throw", "Mouse")):toBeNil()
		T.expect(ViewModel.forCue("Charge", "Gamepad")):toBeNil()
		T.expect(ViewModel.forCue("Bonk", "Mouse")):toBeNil()
	end)

	T.it("does not teach Roblox movement controls", function()
		T.expect(ViewModel.forCue("Cross", "Mouse")):toBeNil()
		T.expect(ViewModel.forCue("Cross", "Gamepad")):toBeNil()
		T.expect(ViewModel.forCue("Cross", "Touch")):toBeNil()
	end)

	T.it("does not invent gestures for non-interactive cues", function()
		T.expect(ViewModel.forCue("Brawl", "Touch")):toBeNil()
	end)
end)

local VIEWPORTS = {
	{ w = 1920, h = 1080 },
	{ w = 1366, h = 768 },
	{ w = 896, h = 414 },
	{ w = 844, h = 390 },
	{ w = 1180, h = 820 },
	{ w = 820, h = 1180 },
}

local function inputFor(view)
	local shortest = math.min(view.w, view.h)
	return {
		viewportWidth = view.w,
		viewportHeight = view.h,
		pressCenterX = view.w / 2,
		pressCenterY = (36 + view.h) / 2,
		swipeTopY = view.h * 0.72,
		reticleRadius = math.clamp(shortest * 0.08, 34, 68),
		glyphSize = math.clamp(shortest * 0.055, 36, 56),
		labelHeight = math.clamp(shortest * 0.055, 36, 56) * 0.5,
		clearance = 14,
	}
end

T.describe("Onboarding gesture placement", function()
	T.it("clears the reticle, swipe region, and screen edge", function()
		for _, viewport in VIEWPORTS do
			local input = inputFor(viewport)
			local placement = ViewModel.placement(input)
			local half = input.glyphSize / 2
			local dx = math.abs(placement.x - input.pressCenterX)
			local dy = math.abs(placement.y - input.pressCenterY)
			T.expect(dx >= input.reticleRadius + half or dy >= input.reticleRadius + half):toBeTruthy()
			T.expect(placement.y + half + input.labelHeight <= input.swipeTopY):toBeTruthy()
			T.expect(placement.x - half >= 0 and placement.x + half <= viewport.w):toBeTruthy()
			T.expect(placement.y - half >= 0 and placement.y + half <= viewport.h):toBeTruthy()
		end
	end)

	T.it("moves beside the reticle on short phone viewports", function()
		T.expect(ViewModel.placement(inputFor(VIEWPORTS[3])).beside):toBeTruthy()
		T.expect(ViewModel.placement(inputFor(VIEWPORTS[4])).beside):toBeTruthy()
	end)
end)

return true
