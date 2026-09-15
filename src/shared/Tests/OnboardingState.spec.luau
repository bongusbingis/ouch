-- Description: Spec for the onboarding status rules: who is eligible, where a partial player resumes, which transitions are legal, that CoreComplete lands exactly on the third mandatory mechanic, and that a completed or skipped player is never forced through training again.

--!strict

local T = require(script.Parent.TestKit)
local OnboardingState = require(script.Parent.Parent.Game.Onboarding.OnboardingState)

local V = 2
local S = OnboardingState.Statuses

local function record(status, checkpoint, skippedAt)
	return { Status = status, Checkpoint = checkpoint or "Intro", Version = V, SkippedAtStep = skippedAt }
end

T.describe("OnboardingState", function()
	T.describe("eligibility", function()
		T.it("admits brand new and partially trained players", function()
			T.expect(OnboardingState.isEligible(record(S.NotStarted))):toEqual(true)
			T.expect(OnboardingState.isEligible(record(S.InProgress, "AvoidBumpers"))):toEqual(true)
		end)

		T.it("never forces a player who already demonstrated the core mechanics", function()
			T.expect(OnboardingState.isEligible(record(S.CoreComplete, "TimeHammer"))):toEqual(false)
		end)

		T.it("never forces a completed or a skipped player", function()
			T.expect(OnboardingState.isEligible(record(S.Completed, "Celebration"))):toEqual(false)
			T.expect(OnboardingState.isEligible(record(S.Skipped, "JumpSweepers", "JumpSweepers"))):toEqual(false)
		end)

		T.it("ignores version, so a future redesign does not re-force old players", function()
			local old = record(S.Completed, "Celebration")
			old.Version = 0
			T.expect(OnboardingState.isEligible(old)):toEqual(false)
		end)
	end)

	T.describe("resume", function()
		T.it("resumes at the step after the last completed checkpoint", function()
			T.expect(OnboardingState.resumeStep(record(S.InProgress, "AvoidBumpers"), true)):toEqual("JumpSweepers")
			T.expect(OnboardingState.resumeStep(record(S.InProgress, "JumpSweepers"), true)):toEqual("TimeHammer")
		end)

		T.it("starts from the beginning when resume is disabled", function()
			T.expect(OnboardingState.resumeStep(record(S.InProgress, "JumpSweepers"), false)):toEqual("Intro")
		end)

		T.it("starts a brand new player at the intro", function()
			T.expect(OnboardingState.resumeStep(record(S.NotStarted), true)):toEqual("Intro")
		end)
	end)

	T.describe("transitions", function()
		T.it("allows only forward-by-one or a restatement of the current step", function()
			T.expect(OnboardingState.canAdvance("AvoidBumpers", "JumpSweepers")):toEqual(true)
			T.expect(OnboardingState.canAdvance("AvoidBumpers", "AvoidBumpers")):toEqual(true)
			T.expect(OnboardingState.canAdvance("AvoidBumpers", "TimeHammer")):toEqual(false)
			T.expect(OnboardingState.canAdvance("JumpSweepers", "AvoidBumpers")):toEqual(false)
			T.expect(OnboardingState.canAdvance("Intro", "Celebration")):toEqual(false)
		end)

		T.it("rejects unknown steps outright", function()
			T.expect(OnboardingState.canAdvance("AvoidBumpers", "Nonsense")):toEqual(false)
			T.expect(OnboardingState.canAdvance("Nonsense", "JumpSweepers")):toEqual(false)
		end)
	end)

	T.describe("checkpoints", function()
		T.it("promotes a new player to in-progress on the first checkpoint", function()
			local next = OnboardingState.withCheckpoint(record(S.NotStarted), "AvoidBumpers")
			T.expect(next.Status):toEqual(S.InProgress)
			T.expect(next.Checkpoint):toEqual("AvoidBumpers")
		end)

		T.it("reaches CoreComplete exactly on the third mandatory mechanic", function()
			local state = OnboardingState.withCheckpoint(record(S.NotStarted), "AvoidBumpers")
			T.expect(state.Status):toEqual(S.InProgress)
			state = OnboardingState.withCheckpoint(state, "JumpSweepers")
			T.expect(state.Status):toEqual(S.InProgress)
			state = OnboardingState.withCheckpoint(state, "TimeHammer")
			T.expect(state.Status):toEqual(S.CoreComplete)
		end)

		T.it("never moves a checkpoint backwards", function()
			local state = OnboardingState.withCheckpoint(record(S.InProgress, "JumpSweepers"), "AvoidBumpers")
			T.expect(state.Checkpoint):toEqual("JumpSweepers")
		end)

		T.it("leaves a completed record's status alone", function()
			local state = OnboardingState.withCheckpoint(record(S.Completed, "Celebration"), "Practice")
			T.expect(state.Status):toEqual(S.Completed)
		end)
	end)

	T.describe("skip", function()
		T.it("records the step the player skipped at", function()
			local state = OnboardingState.withSkip(record(S.InProgress, "AvoidBumpers"), "JumpSweepers")
			T.expect(state.Status):toEqual(S.Skipped)
			T.expect(state.SkippedAtStep):toEqual("JumpSweepers")
		end)

		T.it("does not downgrade a player who already earned CoreComplete", function()
			local state = OnboardingState.withSkip(record(S.CoreComplete, "TimeHammer"), "Practice")
			T.expect(state.Status):toEqual(S.CoreComplete)
			T.expect(state.SkippedAtStep):toEqual("Practice")
		end)

		T.it("leaves a skipped player ineligible on the next join", function()
			local state = OnboardingState.withSkip(record(S.InProgress, "Intro"), "Intro")
			T.expect(OnboardingState.isEligible(state)):toEqual(false)
		end)
	end)

	T.describe("normalize", function()
		T.it("repairs missing, malformed and hostile stored values", function()
			T.expect(OnboardingState.normalize(nil, V).Status):toEqual(S.NotStarted)
			T.expect(OnboardingState.normalize("nonsense", V).Status):toEqual(S.NotStarted)
			T.expect(OnboardingState.normalize({ Status = "Hacked" }, V).Status):toEqual(S.NotStarted)
			T.expect(OnboardingState.normalize({ Status = S.InProgress, Checkpoint = "Nope" }, V).Checkpoint)
				:toEqual("Intro")
			T.expect(OnboardingState.normalize({ Status = S.InProgress, Version = -4 }, V).Version):toEqual(V)
		end)

		T.it("round-trips a valid record unchanged", function()
			local original = record(S.CoreComplete, "TimeHammer")
			local normalized = OnboardingState.normalize(original, V)
			T.expect(normalized.Status):toEqual(S.CoreComplete)
			T.expect(normalized.Checkpoint):toEqual("TimeHammer")
			T.expect(normalized.Version):toEqual(V)
		end)
	end)

	T.describe("completion", function()
		T.it("stamps the completing version so future migrations are explicit", function()
			local state = OnboardingState.withCompletion(record(S.CoreComplete, "TimeHammer"), 7)
			T.expect(state.Status):toEqual(S.Completed)
			T.expect(state.Checkpoint):toEqual("Celebration")
			T.expect(state.Version):toEqual(7)
			T.expect(OnboardingState.isEligible(state)):toEqual(false)
		end)
	end)

	T.describe("core step set", function()
		T.it("treats exactly the three mandatory mechanics as core", function()
			T.expect(OnboardingState.isCoreStep("AvoidBumpers")):toEqual(true)
			T.expect(OnboardingState.isCoreStep("JumpSweepers")):toEqual(true)
			T.expect(OnboardingState.isCoreStep("TimeHammer")):toEqual(true)
			T.expect(OnboardingState.isCoreStep("Practice")):toEqual(false)
			T.expect(OnboardingState.isCoreStep("Intro")):toEqual(false)
		end)
	end)
end)

return true
