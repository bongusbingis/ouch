-- Name: OnboardingAnalytics.spec.luau
-- Author: Jack C.
-- Description: Spec for the onboarding funnel vocabulary: fixed step numbers the dashboard is keyed on, low-cardinality properties, and a device dimension that cannot silently split a cohort.
-- Created: 2026-08-27

--!strict

local T = require(script.Parent.TestKit)
local Onboarding = script.Parent.Parent.Game.Onboarding
local OnboardingAnalytics = require(Onboarding.OnboardingAnalytics)
local OnboardingSteps = require(Onboarding.OnboardingSteps)
local AnalyticsConfig = require(script.Parent.Parent.Parent.Config.Analytics)

T.describe("Onboarding funnel", function()
	T.it("has a fixed step number for every step the player can be on", function()
		for _, step in OnboardingSteps.Ordered do
			local funnelStep = OnboardingAnalytics.funnelStepForStep(step.Id)
			T.expect(funnelStep ~= nil):toBeTruthy()
			T.expect((funnelStep :: any).name):toEqual(step.Id)
		end
	end)

	T.it("brackets the steps with a start and a completion", function()
		local steps = AnalyticsConfig.OnboardingFunnelSteps
		T.expect(steps.Started.step):toEqual(1)
		T.expect(steps.Completed.step):toEqual(#OnboardingSteps.Ordered + 2)
	end)

	T.it("numbers the funnel steps in the order the player meets them", function()
		for _, step in OnboardingSteps.Ordered do
			local funnelStep = OnboardingAnalytics.funnelStepForStep(step.Id) :: any
			T.expect(funnelStep.step):toEqual(step.Index + 1)
		end
	end)

	T.it("refuses to invent a step number for something that is not a step", function()
		T.expect(OnboardingAnalytics.funnelStepForStep("Lob")):toBeNil()
		T.expect(OnboardingAnalytics.funnelStepForStep("")):toBeNil()
	end)
end)

T.describe("Onboarding analytics properties", function()
	T.it("clamps the device dimension to the three known classes", function()
		T.expect(OnboardingAnalytics.deviceClass("Touch")):toEqual("Touch")
		T.expect(OnboardingAnalytics.deviceClass("Gamepad")):toEqual("Gamepad")
		T.expect(OnboardingAnalytics.deviceClass("VR")):toEqual("Mouse")
		T.expect(OnboardingAnalytics.deviceClass(nil)):toEqual("Mouse")
		T.expect(OnboardingAnalytics.deviceClass(7)):toEqual("Mouse")
	end)

	T.it("carries the attempts and escalation a step needed", function()
		local fields = OnboardingAnalytics.stepFields({
			stepId = "Hammer",
			durationSeconds = 4.2,
			attempts = 3,
			escalated = true,
			deviceClass = "Touch",
			resumed = false,
		})
		T.expect(fields.stepId):toEqual("Hammer")
		T.expect(fields.attempts):toEqual(3)
		T.expect(fields.escalated):toEqual(true)
		T.expect(fields.deviceClass):toEqual("Touch")
		T.expect(fields.resumed):toEqual(false)
	end)

	T.it("never reports a negative or fractional attempt count", function()
		local fields = OnboardingAnalytics.stepFields({
			stepId = "Hammer",
			durationSeconds = 0,
			attempts = -2.6,
			escalated = false,
			deviceClass = "Mouse",
			resumed = false,
		})
		T.expect(fields.attempts):toEqual(0)
	end)

	T.it("says why a session ended so abandonment is separable from completion", function()
		local fields = OnboardingAnalytics.sessionFields({
			stepId = "ChargedThrow",
			status = "InProgress",
			durationSeconds = 30,
			deviceClass = "Gamepad",
			resumed = true,
			coreComplete = false,
			reason = "PartyMatch",
		})
		T.expect(fields.reason):toEqual("PartyMatch")
		T.expect(fields.stepId):toEqual("ChargedThrow")
		T.expect(fields.coreComplete):toEqual(false)
	end)

	T.it("rounds durations rather than shipping float noise", function()
		T.expect(OnboardingAnalytics.duration(4.126)):toEqual(4.13)
		T.expect(OnboardingAnalytics.duration(-1)):toEqual(0)
		T.expect(OnboardingAnalytics.duration(0 / 0)):toEqual(0)
		T.expect(OnboardingAnalytics.duration(math.huge)):toEqual(0)
	end)
end)

return true
