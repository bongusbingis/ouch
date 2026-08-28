-- Name: OnboardingViewModel.luau
-- Author: Jack C.
-- Description: Turns an onboarding snapshot into exactly what the prompt shows — headline, input glyph, and gesture caption for the device the player is actually holding — so the components stay presentational and the mapping is testable.
-- Created: 2026-08-27

--!strict

local OnboardingSteps = require(script.Parent.Parent.Parent.Game.Onboarding.OnboardingSteps)

local OnboardingViewModel = {}

export type Prompt = {
	-- The shouted verb. Three words at most: the world does the teaching.
	headline: string,
	-- What to press, drawn as a glyph rather than spelled out where possible.
	glyph: string,
	-- One short line under the glyph, only where a gesture needs naming.
	caption: string,
	visible: boolean,
}

-- Input labels come from the real bindings in Config.Input and
-- PlayerModule.Combat.DeviceInput. A prompt that lies about the button is worse
-- than no prompt, so these are kept beside the tests that pin them.
local GLYPHS: { [string]: { [string]: { glyph: string, caption: string } } } = {
	Mouse = {
		Throw = { glyph = "LMB", caption = "CLICK" },
		Charge = { glyph = "LMB", caption = "HOLD" },
		Hammer = { glyph = "LMB", caption = "CLICK" },
		Any = { glyph = "LMB", caption = "" },
	},
	Touch = {
		Throw = { glyph = "TAP", caption = "" },
		Charge = { glyph = "HOLD", caption = "" },
		Hammer = { glyph = "BONK", caption = "TAP THE BUTTON" },
		Any = { glyph = "TAP", caption = "" },
	},
	Gamepad = {
		Throw = { glyph = "RT", caption = "" },
		Charge = { glyph = "RT", caption = "HOLD" },
		Hammer = { glyph = "X", caption = "" },
		Any = { glyph = "RT", caption = "" },
	},
}

local function deviceRow(deviceClass: string)
	return GLYPHS[deviceClass] or GLYPHS.Mouse
end

-- Which input a step is about. The hammer lesson takes the ball away, so on
-- every device the hammer is what a press produces, which is why the melee
-- prompt names the melee control rather than a weapon switch.
local function inputKindFor(stepId: string): string
	if stepId == "Hammer" then
		return "Hammer"
	elseif stepId == "ChargedThrow" then
		return "Charge"
	elseif stepId == "NormalThrow" then
		return "Throw"
	end
	return "Any"
end

export type Snapshot = {
	route: string,
	stepId: string,
	prompt: string,
	success: string,
	hint: string,
	deviceClass: string,
	celebrating: boolean,
}

function OnboardingViewModel.prompt(snapshot: Snapshot): Prompt
	local step = OnboardingSteps.get(snapshot.stepId)
	if snapshot.route ~= "Training" or step == nil or snapshot.celebrating then
		return { headline = "", glyph = "", caption = "", visible = false }
	end
	if snapshot.success ~= "" then
		return { headline = snapshot.success, glyph = "", caption = "", visible = true }
	end
	local row = deviceRow(snapshot.deviceClass)[inputKindFor(step.Id)] or deviceRow(snapshot.deviceClass).Any
	return {
		headline = step.Prompt,
		glyph = row.glyph,
		caption = row.caption,
		visible = true,
	}
end

-- Assistance is expressed as one extra line, never a paragraph, and only once
-- the player has actually been stuck.
function OnboardingViewModel.hintText(snapshot: Snapshot): string
	if snapshot.route ~= "Training" or snapshot.hint == "" then
		return ""
	end
	local step = OnboardingSteps.get(snapshot.stepId)
	if step == nil then
		return ""
	end
	if snapshot.hint == "Escalated" then
		if step.Id == "ChargedThrow" then
			return "HOLD LONGER FOR MORE POWER"
		elseif step.Id == "Hammer" then
			return "GET CLOSE, THEN SWING"
		elseif step.Id == "Practice" then
			return "KNOCK OUT BOTH OF THEM"
		end
		return "AIM AT THE GLOWING TARGET"
	end
	return ""
end

function OnboardingViewModel.skipVisible(snapshot: Snapshot, skipEnabled: boolean): boolean
	return skipEnabled and snapshot.route == "Training" and not snapshot.celebrating
end

function OnboardingViewModel.completedSkills(): { string }
	local labels = { NormalThrow = "THROW", Hammer = "BONK", ChargedThrow = "POWER" }
	local list = {}
	for _, id in OnboardingSteps.coreIds() do
		table.insert(list, labels[id] or id)
	end
	return list
end

return OnboardingViewModel
