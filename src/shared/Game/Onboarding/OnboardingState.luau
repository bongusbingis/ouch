-- Name: OnboardingState.luau
-- Author: Jack C.
-- Description: The pure onboarding status model: eligibility, resume point, and the only legal transitions between NotStarted, InProgress, CoreComplete, Completed, and Skipped.
-- Created: 2026-08-27

--!strict

local OnboardingSteps = require(script.Parent.OnboardingSteps)

export type Status = "NotStarted" | "InProgress" | "CoreComplete" | "Completed" | "Skipped"

-- The shape stored in the profile under Onboarding. Everything the flow needs
-- to resume lives here; nothing else is a second copy of it.
export type Stored = {
	Version: number,
	Status: Status,
	Checkpoint: string,
	SkippedAt: string,
	Sessions: number,
	SwipeThrowLearned: boolean,
	FirstJoinAt: number,
}

local OnboardingState = {}

-- Statuses that mean "this player has already told us they understand, or that
-- they do not want to be told". None of them are ever auto-started again.
local SETTLED: { [string]: boolean } = {
	CoreComplete = true,
	Completed = true,
	Skipped = true,
}

local VALID_STATUS: { [string]: boolean } = {
	NotStarted = true,
	InProgress = true,
	CoreComplete = true,
	Completed = true,
	Skipped = true,
}

function OnboardingState.isStatus(value: any): boolean
	return typeof(value) == "string" and VALID_STATUS[value] == true
end

-- Normalizes whatever is in the profile into something the flow can reason
-- about. A profile written by an older build, or corrupted by hand, resolves to
-- a state that behaves like a fresh player rather than erroring at runtime.
function OnboardingState.normalize(stored: any): Stored
	local source = if typeof(stored) == "table" then stored else {}
	local status = if OnboardingState.isStatus(source.Status) then source.Status else "NotStarted"
	local checkpoint = if typeof(source.Checkpoint) == "string" and OnboardingSteps.isStep(source.Checkpoint)
		then source.Checkpoint
		else ""
	local skippedAt = if typeof(source.SkippedAt) == "string" and OnboardingSteps.isStep(source.SkippedAt)
		then source.SkippedAt
		else ""
	local version = if typeof(source.Version) == "number" and source.Version >= 0 then math.floor(source.Version) else 0
	local sessions = if typeof(source.Sessions) == "number" and source.Sessions >= 0
		then math.floor(source.Sessions)
		else 0
	return {
		Version = version,
		Status = status,
		Checkpoint = checkpoint,
		SkippedAt = skippedAt,
		Sessions = sessions,
		SwipeThrowLearned = source.SwipeThrowLearned == true,
		FirstJoinAt = if typeof(source.FirstJoinAt) == "number" then source.FirstJoinAt else 0,
	}
end

-- Version migration is explicit rather than implicit: a player who settled an
-- older onboarding is left settled. A new version re-teaches nobody unless a
-- future migration deliberately says so.
function OnboardingState.migrate(state: Stored, version: number): Stored
	if state.Version == version then
		return state
	end
	local migrated = table.clone(state)
	migrated.Version = version
	if not SETTLED[state.Status] and state.Version < version then
		-- Partial progress against a different content version cannot be
		-- trusted to line up with the current steps, so it starts over.
		migrated.Status = "NotStarted"
		migrated.Checkpoint = ""
	end
	return migrated
end

function OnboardingState.isEligible(state: Stored, autoStartEnabled: boolean): boolean
	if not autoStartEnabled then
		return false
	end
	return not SETTLED[state.Status]
end

-- Where a session should pick up. Resume is a courtesy, not a requirement: with
-- it off, or with no stored checkpoint, the player starts at the first step.
function OnboardingState.resumeStep(state: Stored, resumeEnabled: boolean): OnboardingSteps.Step
	if not resumeEnabled or state.Status ~= "InProgress" then
		return OnboardingSteps.first()
	end
	return OnboardingSteps.after(state.Checkpoint) or OnboardingSteps.first()
end

function OnboardingState.begin(state: Stored, version: number): Stored
	local next_ = table.clone(state)
	next_.Version = version
	next_.Sessions += 1
	if not SETTLED[state.Status] then
		next_.Status = "InProgress"
	end
	return next_
end

-- Completing a step is the only thing that moves the checkpoint, and completing
-- the last core step is what earns CoreComplete — persisted the instant the
-- player has demonstrated all three mechanics, so a disconnect one second later
-- never costs them the tutorial again.
function OnboardingState.completeStep(state: Stored, stepId: string): Stored
	local step = OnboardingSteps.get(stepId)
	if step == nil then
		return state
	end
	local current = OnboardingSteps.get(state.Checkpoint)
	local next_ = table.clone(state)
	if current == nil or step.Index > current.Index then
		next_.Checkpoint = step.Id
	end
	if state.Status == "Completed" or state.Status == "Skipped" then
		return next_
	end
	if step.Id == OnboardingSteps.lastCore().Id then
		next_.Status = "CoreComplete"
	elseif state.Status ~= "CoreComplete" then
		next_.Status = "InProgress"
	end
	return next_
end

function OnboardingState.complete(state: Stored): Stored
	local next_ = table.clone(state)
	next_.Status = "Completed"
	local last = OnboardingSteps.Ordered[#OnboardingSteps.Ordered]
	next_.Checkpoint = last.Id
	return next_
end

-- A deliberate skip is remembered with the step it happened on, which is the
-- single most useful number in the funnel. Skipping never rolls back progress
-- the player already earned.
function OnboardingState.skip(state: Stored, stepId: string?): Stored
	local next_ = table.clone(state)
	if state.Status == "Completed" then
		return next_
	end
	next_.Status = if state.Status == "CoreComplete" then "CoreComplete" else "Skipped"
	if next_.Status == "Skipped" then
		next_.SkippedAt = if OnboardingSteps.isStep(stepId) then stepId :: string else ""
	end
	return next_
end

-- Voluntary replay: the player asked for training again. It never rewrites what
-- they have already earned, so replaying cannot demote a Completed player.
function OnboardingState.replay(state: Stored): Stored
	local next_ = table.clone(state)
	next_.Checkpoint = ""
	return next_
end

function OnboardingState.hasCore(state: Stored): boolean
	return state.Status == "CoreComplete" or state.Status == "Completed"
end

return OnboardingState
