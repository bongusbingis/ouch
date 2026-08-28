-- Name: OnboardingAnalytics.luau
-- Author: Jack C.
-- Description: Pure builders for the onboarding funnel: which fixed step number an event belongs to and which low-cardinality properties travel with it, so no call site invents an event name or a free-form string.
-- Created: 2026-08-27

--!strict

local AnalyticsConfig = require(script.Parent.Parent.Parent.Parent.Config.Analytics)
local OnboardingSteps = require(script.Parent.OnboardingSteps)

local OnboardingAnalytics = {}

export type StepMetrics = {
	stepId: string,
	-- Seconds from the step's prompt appearing to it completing or being left.
	durationSeconds: number,
	-- Throws, swings, or charged releases the player spent on it.
	attempts: number,
	-- Whether the extra help ever appeared, which separates "hard" from "slow".
	escalated: boolean,
	deviceClass: string,
	resumed: boolean,
}

local DEVICE_CLASSES: { [string]: boolean } = { Mouse = true, Touch = true, Gamepad = true }

-- Device class is the axis every onboarding comparison is sliced by, so it is
-- clamped to the known set rather than passed through: an unexpected value
-- would silently split every cohort in the dashboard.
function OnboardingAnalytics.deviceClass(value: any): string
	return if typeof(value) == "string" and DEVICE_CLASSES[value] then value else "Mouse"
end

function OnboardingAnalytics.funnelStep(key: string): { step: number, name: string }?
	return (AnalyticsConfig.OnboardingFunnelSteps :: any)[key]
end

-- Step ids double as funnel step keys, which is the whole reason the step list
-- and the funnel table are kept in the same order.
function OnboardingAnalytics.funnelStepForStep(stepId: string): { step: number, name: string }?
	if not OnboardingSteps.isStep(stepId) then
		return nil
	end
	return OnboardingAnalytics.funnelStep(stepId)
end

function OnboardingAnalytics.stepFields(metrics: StepMetrics): { [string]: any }
	return {
		stepId = metrics.stepId,
		attempts = math.max(math.floor(metrics.attempts), 0),
		escalated = metrics.escalated,
		deviceClass = OnboardingAnalytics.deviceClass(metrics.deviceClass),
		resumed = metrics.resumed,
	}
end

export type SessionMetrics = {
	-- The step the player was on when the session ended, whatever ended it.
	stepId: string,
	status: string,
	durationSeconds: number,
	deviceClass: string,
	resumed: boolean,
	coreComplete: boolean,
	-- Why the session ended: the only values that ever appear here.
	reason: "Completed" | "Skipped" | "PartyMatch" | "Left" | "Timeout" | "Error",
}

function OnboardingAnalytics.sessionFields(metrics: SessionMetrics): { [string]: any }
	return {
		stepId = metrics.stepId,
		status = metrics.status,
		deviceClass = OnboardingAnalytics.deviceClass(metrics.deviceClass),
		resumed = metrics.resumed,
		coreComplete = metrics.coreComplete,
		reason = metrics.reason,
	}
end

-- Durations are the event value rather than a field, because that is the shape
-- the analytics dashboard aggregates on.
function OnboardingAnalytics.duration(seconds: number): number
	if seconds ~= seconds or seconds == math.huge or seconds < 0 then
		return 0
	end
	return math.floor(seconds * 100 + 0.5) / 100
end

return OnboardingAnalytics
