-- Description: Pure onboarding status rules: which stored state makes a player eligible, which step a partial player resumes at, which step transitions are legal, and what a stored record normalizes to. Shared so the server's persistence and the client's routing can never disagree about who sees training.

--!strict

local OnboardingState = {}

export type Status = "NotStarted" | "InProgress" | "CoreComplete" | "Completed" | "Skipped"
export type Step = "Intro" | "NormalThrow" | "Hammer" | "ChargedThrow" | "Practice" | "Celebration"

export type Record = {
	Status: Status,
	Checkpoint: Step,
	Version: number,
	SkippedAtStep: Step?,
}

OnboardingState.Statuses = table.freeze({
	NotStarted = "NotStarted",
	InProgress = "InProgress",
	CoreComplete = "CoreComplete",
	Completed = "Completed",
	Skipped = "Skipped",
})

-- Ordered: index is progression order, and the three mandatory mechanics are
-- NormalThrow through ChargedThrow. Reaching the end of ChargedThrow is what
-- CoreComplete means.
local ORDER: { Step } = { "Intro", "NormalThrow", "Hammer", "ChargedThrow", "Practice", "Celebration" }
local INDEX: { [string]: number } = {}
for index, step in ORDER do
	INDEX[step] = index
end

local CORE_STEPS: { Step } = { "NormalThrow", "Hammer", "ChargedThrow" }

OnboardingState.Steps = table.freeze(ORDER)
OnboardingState.CoreSteps = table.freeze(CORE_STEPS)

function OnboardingState.isStep(value: any): boolean
	return typeof(value) == "string" and INDEX[value] ~= nil
end

function OnboardingState.stepIndex(step: Step): number
	return INDEX[step] or 1
end

function OnboardingState.isCoreStep(step: Step): boolean
	return table.find(CORE_STEPS, step) ~= nil
end

function OnboardingState.nextStep(step: Step): Step?
	return ORDER[(INDEX[step] or 0) + 1]
end

-- A transition is legal if it moves forward by exactly one step, or restates
-- the current step. Anything else is a client claiming progress it did not
-- earn, or a stale message arriving out of order.
function OnboardingState.canAdvance(from: Step, to: Step): boolean
	local fromIndex = INDEX[from]
	local toIndex = INDEX[to]
	if fromIndex == nil or toIndex == nil then
		return false
	end
	return toIndex == fromIndex or toIndex == fromIndex + 1
end

function OnboardingState.blank(version: number): Record
	return {
		Status = OnboardingState.Statuses.NotStarted,
		Checkpoint = "Intro",
		Version = version,
		SkippedAtStep = nil,
	}
end

function OnboardingState.normalize(stored: any, version: number): Record
	if typeof(stored) ~= "table" then
		return OnboardingState.blank(version)
	end
	local status = stored.Status
	if OnboardingState.Statuses[status] == nil then
		status = OnboardingState.Statuses.NotStarted
	end
	local checkpoint = if OnboardingState.isStep(stored.Checkpoint) then stored.Checkpoint else "Intro"
	local storedVersion = if typeof(stored.Version) == "number" and stored.Version >= 0
		then math.floor(stored.Version)
		else version
	local skippedAt = if OnboardingState.isStep(stored.SkippedAtStep) then stored.SkippedAtStep else nil
	return {
		Status = status,
		Checkpoint = checkpoint,
		Version = storedVersion,
		SkippedAtStep = skippedAt,
	}
end

-- Deliberately ignores Version: a player who finished onboarding once is never
-- dragged through a later revision of it automatically.
function OnboardingState.isEligible(record: Record): boolean
	local status = record.Status
	return status == OnboardingState.Statuses.NotStarted or status == OnboardingState.Statuses.InProgress
end

function OnboardingState.resumeStep(record: Record, resumeEnabled: boolean): Step
	if not resumeEnabled or record.Status ~= OnboardingState.Statuses.InProgress then
		return "Intro"
	end
	local checkpoint = record.Checkpoint
	if not OnboardingState.isStep(checkpoint) then
		return "Intro"
	end
	-- A checkpoint records the last step the player finished, so resuming means
	-- picking up at the step after it.
	return OnboardingState.nextStep(checkpoint) or "Practice"
end

function OnboardingState.withCheckpoint(record: Record, step: Step): Record
	local next: Record = table.clone(record)
	if OnboardingState.stepIndex(step) > OnboardingState.stepIndex(record.Checkpoint) then
		next.Checkpoint = step
	end
	if next.Status == OnboardingState.Statuses.NotStarted then
		next.Status = OnboardingState.Statuses.InProgress
	end
	if step == "ChargedThrow" and next.Status == OnboardingState.Statuses.InProgress then
		next.Status = OnboardingState.Statuses.CoreComplete
	end
	return next
end

function OnboardingState.withSkip(record: Record, atStep: Step): Record
	local next: Record = table.clone(record)
	-- A player who already demonstrated everything keeps the stronger status;
	-- skipping the victory lap is not the same as skipping the lesson.
	if next.Status ~= OnboardingState.Statuses.CoreComplete and next.Status ~= OnboardingState.Statuses.Completed then
		next.Status = OnboardingState.Statuses.Skipped
	end
	next.SkippedAtStep = atStep
	return next
end

function OnboardingState.withCompletion(record: Record, version: number): Record
	local next: Record = table.clone(record)
	next.Status = OnboardingState.Statuses.Completed
	next.Checkpoint = "Celebration"
	next.Version = version
	return next
end

return table.freeze(OnboardingState)
