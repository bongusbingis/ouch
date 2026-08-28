-- Name: OnboardingSteps.luau
-- Author: Jack C.
-- Description: The ordered onboarding step definitions — ids, prompts, and what each step demands of the player — shared by the server flow, the client UI, and analytics so all three name the same thing.
-- Created: 2026-08-27

--!strict

export type StepId = "NormalThrow" | "Hammer" | "ChargedThrow" | "Practice"

export type Step = {
	Id: StepId,
	-- 1-based, and the funnel step number. Never reorder without bumping
	-- Config.Onboarding.Version: the analytics history is keyed on this.
	Index: number,
	-- Shouted, three words at most. The world teaches; the text only names
	-- the verb.
	Prompt: string,
	Success: string,
	-- Which intent completes the step. The server checks the sim event, not
	-- the button, so a step can only be passed by actually doing the thing.
	Demands: "DodgeballElim" | "HammerElim" | "ChargedElim" | "Knockouts",
	-- Which weapon the step is about, for the device prompt glyph.
	Weapon: "Dodgeball" | "Hammer" | "Any",
	-- Steps up to and including this one are what CoreComplete means.
	Core: boolean,
}

local ordered: { Step } = {
	{
		Id = "NormalThrow",
		Index = 1,
		Prompt = "THROW!",
		Success = "NICE!",
		Demands = "DodgeballElim",
		Weapon = "Dodgeball",
		Core = true,
	},
	{
		Id = "Hammer",
		Index = 2,
		Prompt = "BONK!",
		Success = "OOF!",
		Demands = "HammerElim",
		Weapon = "Hammer",
		Core = true,
	},
	{
		Id = "ChargedThrow",
		Index = 3,
		Prompt = "HOLD FOR POWER!",
		Success = "BOOM!",
		Demands = "ChargedElim",
		Weapon = "Dodgeball",
		Core = true,
	},
	{
		Id = "Practice",
		Index = 4,
		Prompt = "KNOCK THEM OUT!",
		Success = "READY!",
		Demands = "Knockouts",
		Weapon = "Any",
		Core = false,
	},
}

local byId: { [string]: Step } = {}
for _, step in ordered do
	byId[step.Id] = step
end

local OnboardingSteps = {}

OnboardingSteps.Ordered = table.freeze(ordered)

function OnboardingSteps.get(id: string?): Step?
	return if id == nil then nil else byId[id]
end

function OnboardingSteps.isStep(id: string?): boolean
	return id ~= nil and byId[id] ~= nil
end

function OnboardingSteps.first(): Step
	return ordered[1]
end

function OnboardingSteps.after(id: string?): Step?
	if id == nil or id == "" then
		return ordered[1]
	end
	local step = byId[id]
	if step == nil then
		return ordered[1]
	end
	return ordered[step.Index + 1]
end

-- The last step whose completion means the player has demonstrated every
-- mandatory mechanic. Reaching it is what persists CoreComplete.
function OnboardingSteps.lastCore(): Step
	local last = ordered[1]
	for _, step in ordered do
		if step.Core then
			last = step
		end
	end
	return last
end

function OnboardingSteps.coreIds(): { string }
	local ids = {}
	for _, step in ordered do
		if step.Core then
			table.insert(ids, step.Id)
		end
	end
	return ids
end

return OnboardingSteps
