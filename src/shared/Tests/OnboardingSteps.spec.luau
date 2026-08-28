-- Name: OnboardingSteps.spec.luau
-- Author: Jack C.
-- Description: Spec for the onboarding step list, which decides what the mandatory onboarding teaches and, through the last core step, what CoreComplete means.
-- Created: 2026-08-27

--!strict

local T = require(script.Parent.TestKit)
local OnboardingSteps = require(script.Parent.Parent.Game.Onboarding.OnboardingSteps)

T.describe("Onboarding steps", function()
	T.it("teaches the three mandatory mechanics and nothing else", function()
		T.expect(#OnboardingSteps.coreIds()):toEqual(3)
		T.expect(table.concat(OnboardingSteps.coreIds(), ",")):toEqual("NormalThrow,Hammer,ChargedThrow")
	end)

	T.it("never teaches a lob, because the game has none", function()
		for _, step in OnboardingSteps.Ordered do
			T.expect(string.find(string.lower(step.Id), "lob") == nil):toBeTruthy()
			T.expect(string.find(string.lower(step.Prompt), "lob") == nil):toBeTruthy()
		end
	end)

	T.it("ends on the short freeform practice, which is not mandatory", function()
		local last = OnboardingSteps.Ordered[#OnboardingSteps.Ordered]
		T.expect(last.Id):toEqual("Practice")
		T.expect(last.Core):toEqual(false)
	end)

	T.it("names the charged throw as the last mandatory mechanic", function()
		T.expect(OnboardingSteps.lastCore().Id):toEqual("ChargedThrow")
	end)

	T.it("keeps every prompt short enough to read at a glance", function()
		for _, step in OnboardingSteps.Ordered do
			T.expect(#step.Prompt <= 16):toBeTruthy()
			T.expect(#step.Success <= 10):toBeTruthy()
		end
	end)

	T.it("indexes the steps in order with no gaps", function()
		for index, step in OnboardingSteps.Ordered do
			T.expect(step.Index):toEqual(index)
		end
	end)

	T.it("walks forwards from any step and stops after the last", function()
		T.expect((OnboardingSteps.after("") :: any).Id):toEqual("NormalThrow")
		T.expect((OnboardingSteps.after("NormalThrow") :: any).Id):toEqual("Hammer")
		T.expect((OnboardingSteps.after("Hammer") :: any).Id):toEqual("ChargedThrow")
		T.expect((OnboardingSteps.after("ChargedThrow") :: any).Id):toEqual("Practice")
		T.expect(OnboardingSteps.after("Practice")):toBeNil()
	end)

	T.it("restarts rather than erroring on a step id it does not know", function()
		T.expect((OnboardingSteps.after("Lob") :: any).Id):toEqual("NormalThrow")
		T.expect(OnboardingSteps.isStep("Lob")):toEqual(false)
	end)
end)

return true
