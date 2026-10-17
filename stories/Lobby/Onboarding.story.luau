--[[
    The training prompt (OnboardingOverlay): the candy card at the top of the screen with the
    lesson title and instruction, the lesson progress, and the separate SKIP button. Its copy
    comes from OnboardingViewModel, which words the jump instruction and SKIP per input device, so
    the one obstacle lesson is shown on Touch, Keyboard and Gamepad side by side, then every other
    step of the lesson list (Intro -> NormalThrow -> Dodge -> Hammer -> ChargedThrow -> Practice ->
    Celebration) and the retry / success / hint variants.

    The overlay positions itself on the safe area of the viewport, so every state is a Screen
    frame. SKIP prints. Migrated from OnboardingOverlay.story (Cue / Step / DeviceClass attributes
    -> states).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local OnboardingOverlay = require(StoryRoot.Components:WaitForChild("Onboarding"):WaitForChild("OnboardingOverlay"))

local c = React.createElement

local function overlay(step: string, device: string, extra: { [string]: any }?): any
	local snapshot: { [string]: any } = {
		active = true,
		cue = step,
		step = step,
		deviceClass = device,
		hintLevel = 0,
	}
	for key, value in extra or {} do
		snapshot[key] = value
	end
	return c(OnboardingOverlay, { Snapshot = snapshot, OnSkip = Fixtures.log("Onboarding", "OnSkip") })
end

local function state(name: string, note: string?, element: any): any
	return { Name = name, Note = note, Screen = true, Fit = 1 / 3, Element = element }
end

return StoryRoot.story({
	Title = "Onboarding",
	Summary = "OnboardingOverlay per input device and per lesson step, plus retry, success and hint copy.",
	States = {
		state("Dodge — touch", "Tap jump / SKIP.", overlay("Dodge", "Touch", { hintLevel = 1 })),
		state("Dodge — keyboard", "Press Space / X SKIP.", overlay("Dodge", "Keyboard", { hintLevel = 1 })),
		state("Dodge — gamepad", "Press A / B SKIP.", overlay("Dodge", "Gamepad", { hintLevel = 1 })),
		state("Intro", nil, overlay("Intro", "Keyboard")),
		state("Throw", nil, overlay("NormalThrow", "Keyboard")),
		state("Hammer", nil, overlay("Hammer", "Keyboard")),
		state("Charged throw", nil, overlay("ChargedThrow", "Keyboard")),
		state("Practice", nil, overlay("Practice", "Keyboard")),
		state("Celebration", "All five lessons done.", overlay("Celebration", "Keyboard")),
		state("Retrying", "TRY AGAIN!", overlay("Dodge", "Touch", { retrying = true })),
		state("Succeeded", "NICE!", overlay("NormalThrow", "Touch", { succeeded = true })),
		state("Hint", "After a stall: hint copy.", overlay("Hammer", "Touch", { hintLevel = 2 })),
	},
})
