-- Name: OnboardingState.spec.luau
-- Author: Jack C.
-- Description: Spec for the onboarding status model, which decides whether a returning player is forced back through training: eligibility, resume point, the CoreComplete moment, skip, and version migration.
-- Created: 2026-08-27

--!strict

local T = require(script.Parent.TestKit)
local Onboarding = script.Parent.Parent.Game.Onboarding
local OnboardingState = require(Onboarding.OnboardingState)
local OnboardingSteps = require(Onboarding.OnboardingSteps)

local VERSION = 1

local function fresh()
	return OnboardingState.normalize(nil)
end

T.describe("Onboarding eligibility", function()
	T.it("starts a brand-new player in training", function()
		T.expect(OnboardingState.isEligible(fresh(), true)):toBeTruthy()
	end)

	T.it("never forces a player who finished", function()
		local state = OnboardingState.complete(fresh())
		T.expect(OnboardingState.isEligible(state, true)):toEqual(false)
	end)

	T.it("never forces a player who chose to skip", function()
		local state = OnboardingState.skip(fresh(), "Hammer")
		T.expect(state.Status):toEqual("Skipped")
		T.expect(OnboardingState.isEligible(state, true)):toEqual(false)
	end)

	T.it("never forces a player who already demonstrated the three mechanics", function()
		local state = fresh()
		for _, id in OnboardingSteps.coreIds() do
			state = OnboardingState.completeStep(state, id)
		end
		T.expect(state.Status):toEqual("CoreComplete")
		T.expect(OnboardingState.isEligible(state, true)):toEqual(false)
	end)

	T.it("still forces a player who left partway through", function()
		local state = OnboardingState.completeStep(fresh(), "NormalThrow")
		T.expect(state.Status):toEqual("InProgress")
		T.expect(OnboardingState.isEligible(state, true)):toBeTruthy()
	end)

	T.it("routes everyone to the lobby when auto-start is off", function()
		T.expect(OnboardingState.isEligible(fresh(), false)):toEqual(false)
	end)
end)

T.describe("Onboarding resume", function()
	T.it("starts a fresh player at the first step", function()
		T.expect(OnboardingState.resumeStep(fresh(), true).Id):toEqual(OnboardingSteps.first().Id)
	end)

	T.it("resumes at the step after the last one completed", function()
		local state = OnboardingState.completeStep(fresh(), "NormalThrow")
		T.expect(OnboardingState.resumeStep(state, true).Id):toEqual("Hammer")
	end)

	T.it("restarts from the beginning when resume is disabled", function()
		local state = OnboardingState.completeStep(fresh(), "Hammer")
		T.expect(OnboardingState.resumeStep(state, false).Id):toEqual("NormalThrow")
	end)

	T.it("ignores a checkpoint that names a step that no longer exists", function()
		local state = OnboardingState.normalize({ Status = "InProgress", Checkpoint = "Lob" })
		T.expect(state.Checkpoint):toEqual("")
		T.expect(OnboardingState.resumeStep(state, true).Id):toEqual("NormalThrow")
	end)
end)

T.describe("Onboarding progress", function()
	T.it("reaches CoreComplete the moment the last mandatory mechanic lands", function()
		local last = OnboardingSteps.lastCore()
		local state = OnboardingState.completeStep(fresh(), last.Id)
		T.expect(state.Status):toEqual("CoreComplete")
		T.expect(OnboardingState.hasCore(state)):toBeTruthy()
	end)

	T.it("does not demote a CoreComplete player when the practice step completes", function()
		local state = OnboardingState.completeStep(fresh(), OnboardingSteps.lastCore().Id)
		state = OnboardingState.completeStep(state, "Practice")
		T.expect(state.Status):toEqual("CoreComplete")
		T.expect(state.Checkpoint):toEqual("Practice")
	end)

	T.it("never moves the checkpoint backwards", function()
		local state = OnboardingState.completeStep(fresh(), "ChargedThrow")
		state = OnboardingState.completeStep(state, "NormalThrow")
		T.expect(state.Checkpoint):toEqual("ChargedThrow")
	end)

	T.it("keeps CoreComplete rather than downgrading it to Skipped", function()
		local state = OnboardingState.completeStep(fresh(), OnboardingSteps.lastCore().Id)
		state = OnboardingState.skip(state, "Practice")
		T.expect(state.Status):toEqual("CoreComplete")
	end)

	T.it("records where the player skipped", function()
		local state = OnboardingState.skip(fresh(), "ChargedThrow")
		T.expect(state.SkippedAt):toEqual("ChargedThrow")
	end)

	T.it("counts each session it starts", function()
		local state = OnboardingState.begin(fresh(), VERSION)
		state = OnboardingState.begin(state, VERSION)
		T.expect(state.Sessions):toEqual(2)
		T.expect(state.Status):toEqual("InProgress")
	end)

	T.it("does not reopen a settled status when a session begins", function()
		local state = OnboardingState.begin(OnboardingState.complete(fresh()), VERSION)
		T.expect(state.Status):toEqual("Completed")
	end)

	T.it("clears only the checkpoint on a voluntary replay", function()
		local state = OnboardingState.replay(OnboardingState.complete(fresh()))
		T.expect(state.Status):toEqual("Completed")
		T.expect(state.Checkpoint):toEqual("")
	end)
end)

T.describe("Onboarding versioning", function()
	T.it("leaves a settled player settled across a version bump", function()
		local state = OnboardingState.complete(fresh())
		state.Version = 1
		local migrated = OnboardingState.migrate(state, 2)
		T.expect(migrated.Status):toEqual("Completed")
		T.expect(migrated.Version):toEqual(2)
		T.expect(OnboardingState.isEligible(migrated, true)):toEqual(false)
	end)

	T.it("discards partial progress that belongs to an older version", function()
		local state = OnboardingState.completeStep(fresh(), "Hammer")
		state.Version = 1
		local migrated = OnboardingState.migrate(state, 2)
		T.expect(migrated.Status):toEqual("NotStarted")
		T.expect(migrated.Checkpoint):toEqual("")
	end)
end)

T.describe("Onboarding state normalization", function()
	T.it("treats a missing branch as a brand-new player", function()
		local state = fresh()
		T.expect(state.Status):toEqual("NotStarted")
		T.expect(state.Checkpoint):toEqual("")
		T.expect(state.Sessions):toEqual(0)
	end)

	T.it("rejects a status that is not one the flow can be in", function()
		local state = OnboardingState.normalize({ Status = "Whatever" })
		T.expect(state.Status):toEqual("NotStarted")
	end)

	T.it("rejects a negative or fractional session count", function()
		T.expect(OnboardingState.normalize({ Sessions = -4 }).Sessions):toEqual(0)
		T.expect(OnboardingState.normalize({ Sessions = 2.7 }).Sessions):toEqual(2)
	end)
end)

return true
