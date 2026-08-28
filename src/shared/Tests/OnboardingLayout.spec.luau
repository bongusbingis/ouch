-- Name: OnboardingLayout.spec.luau
-- Author: Jack C.
-- Description: Spec for the training ring geometry, which is what keeps two onboarding players from ever sharing a space and what makes the first throw a gimme and the charge throw a stretch.
-- Created: 2026-08-27

--!strict

local T = require(script.Parent.TestKit)
local Onboarding = script.Parent.Parent.Game.Onboarding
local OnboardingLayout = require(Onboarding.OnboardingLayout)
local OnboardingConfig = require(script.Parent.Parent.Parent.Config.Onboarding)

T.describe("Onboarding ring allocation", function()
	T.it("gives every slot its own place in the world", function()
		local seen = {}
		for slot = 1, 12 do
			local key = tostring(OnboardingLayout.slotOrigin(slot))
			T.expect(seen[key]):toBeNil()
			seen[key] = true
		end
	end)

	T.it("separates neighbouring rings by more than their own diameter", function()
		local separation = vector.magnitude(OnboardingLayout.slotOrigin(2) - OnboardingLayout.slotOrigin(1))
		T.expect(separation > OnboardingConfig.Training.RingRadius * 2):toBeTruthy()
	end)

	T.it("separates rings on different rows too", function()
		local perRow = OnboardingConfig.Training.SlotsPerRow
		local separation = vector.magnitude(OnboardingLayout.slotOrigin(perRow + 1) - OnboardingLayout.slotOrigin(1))
		T.expect(separation > OnboardingConfig.Training.RingRadius * 2):toBeTruthy()
	end)

	T.it("clamps a nonsense slot rather than placing a ring at a nonsense point", function()
		T.expect(tostring(OnboardingLayout.slotOrigin(0))):toEqual(tostring(OnboardingLayout.slotOrigin(1)))
		T.expect(tostring(OnboardingLayout.slotOrigin(-5))):toEqual(tostring(OnboardingLayout.slotOrigin(1)))
	end)
end)

T.describe("Onboarding targets", function()
	T.it("puts every lesson target inside its own ring", function()
		for _, stepId in { "NormalThrow", "Hammer", "ChargedThrow" } do
			local position = OnboardingLayout.targetPosition(3, stepId)
			T.expect(position ~= nil):toBeTruthy()
			T.expect(OnboardingLayout.isInsideRing(3, position :: vector)):toBeTruthy()
		end
	end)

	T.it("puts the melee dummy within hammer reach of the spawn", function()
		local spawn = OnboardingLayout.frame(1).spawn
		local target = OnboardingLayout.targetPosition(1, "Hammer") :: vector
		T.expect(vector.magnitude(target - spawn) <= OnboardingConfig.Training.HammerApproachStuds + 1):toBeTruthy()
	end)

	T.it("puts the charge target far enough away to make holding matter", function()
		local spawn = OnboardingLayout.frame(1).spawn
		local normal = OnboardingLayout.targetPosition(1, "NormalThrow") :: vector
		local charged = OnboardingLayout.targetPosition(1, "ChargedThrow") :: vector
		T.expect(vector.magnitude(charged - spawn) > vector.magnitude(normal - spawn) * 2):toBeTruthy()
	end)

	T.it("has no target for the freeform practice step", function()
		T.expect(OnboardingLayout.targetPosition(1, "Practice")):toBeNil()
	end)

	T.it("spreads the practice bots apart inside the ring", function()
		local a = OnboardingLayout.practicePosition(1, 1, 2)
		local b = OnboardingLayout.practicePosition(1, 2, 2)
		T.expect(vector.magnitude(a - b) > 6):toBeTruthy()
		T.expect(OnboardingLayout.isInsideRing(1, a)):toBeTruthy()
		T.expect(OnboardingLayout.isInsideRing(1, b)):toBeTruthy()
	end)
end)

T.describe("Onboarding fall recovery", function()
	T.it("sits below the ring floor so standing in it is never a fall", function()
		T.expect(OnboardingLayout.fallHeight(2) < OnboardingLayout.frame(2).spawn.y):toBeTruthy()
	end)

	T.it("tracks its own slot rather than a fixed world height", function()
		T.expect(OnboardingLayout.fallHeight(1) == OnboardingLayout.fallHeight(9)):toBeTruthy()
		T.expect(OnboardingLayout.isInsideRing(1, OnboardingLayout.slotOrigin(2))):toEqual(false)
	end)
end)

return true
