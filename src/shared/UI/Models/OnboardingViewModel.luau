-- Name: OnboardingViewModel.luau
-- Author: Jack C.
-- Description: Turns an onboarding snapshot into what the training UI shows — the headline on the panel, the escalating hint line, and which gesture indicator belongs to the device in the player's hands — so the components stay presentational and the mapping is testable.
-- Created: 2026-08-27

--!strict

local OnboardingSteps = require(script.Parent.Parent.Parent.Game.Onboarding.OnboardingSteps)

local OnboardingViewModel = {}

export type Prompt = {
	-- The shouted verb. Three words at most: the world does the teaching.
	headline: string,
	visible: boolean,
}

export type Gesture = {
	-- Which notation the indicator draws. Action kinds hand the drawing to the
	-- engine's own key glyph for the connected device.
	kind: "Tap" | "Hold" | "Action" | "ActionHold",
	-- The verb under the glyph, in the language of the device being used.
	label: string,
	-- Shown only if the engine cannot resolve a glyph for the binding.
	fallback: string,
}

export type Snapshot = {
	route: string,
	stepId: string,
	prompt: string,
	success: string,
	hint: string,
	deviceClass: string,
	celebrating: boolean,
	partyReady: boolean?,
}

-- The verb each device's players use for their primary attack, and the text to
-- fall back to if the engine has no glyph for the binding. The glyph itself
-- comes from the real binding, never from this table.
local DEVICES: { [string]: { press: string, hold: string, fallback: string, touch: boolean } } = {
	Mouse = { press = "CLICK", hold = "HOLD", fallback = "LMB", touch = false },
	Gamepad = { press = "PRESS", hold = "HOLD", fallback = "RT", touch = false },
	Touch = { press = "TAP", hold = "HOLD", fallback = "TAP", touch = true },
}

local function deviceRow(deviceClass: string)
	return DEVICES[deviceClass] or DEVICES.Mouse
end

-- Every lesson is performed with the same primary attack input; the hammer
-- lesson takes the ball away and equips the hammer server-side, so a press
-- swings rather than throws without the player learning a second control.
local function isHoldStep(stepId: string): boolean
	return stepId == "ChargedThrow"
end

local function active(snapshot: Snapshot): OnboardingSteps.Step?
	if snapshot.route ~= "Training" or snapshot.celebrating or snapshot.partyReady == true then
		return nil
	end
	return OnboardingSteps.get(snapshot.stepId)
end

function OnboardingViewModel.prompt(snapshot: Snapshot): Prompt
	local step = active(snapshot)
	if step == nil then
		return { headline = "", visible = false }
	end
	if snapshot.success ~= "" then
		return { headline = snapshot.success, visible = true }
	end
	return { headline = step.Prompt, visible = true }
end

-- Nothing is drawn over the world while the success beat is playing: the
-- player has just done the thing, and the next instruction has not arrived.
function OnboardingViewModel.gesture(snapshot: Snapshot): Gesture?
	local step = active(snapshot)
	if step == nil or snapshot.success ~= "" then
		return nil
	end
	local row = deviceRow(snapshot.deviceClass)
	local hold = isHoldStep(step.Id)
	local kind: "Tap" | "Hold" | "Action" | "ActionHold"
	if row.touch then
		kind = if hold then "Hold" else "Tap"
	else
		kind = if hold then "ActionHold" else "Action"
	end
	return {
		kind = kind,
		label = if hold then row.hold else row.press,
		fallback = row.fallback,
	}
end

-- Assistance is one extra line, never a paragraph, and only once the player has
-- actually been stuck.
function OnboardingViewModel.hintText(snapshot: Snapshot): string
	local step = active(snapshot)
	if step == nil or snapshot.hint ~= "Escalated" then
		return ""
	end
	if step.Id == "ChargedThrow" then
		return "HOLD LONGER FOR MORE POWER"
	elseif step.Id == "Hammer" then
		return "GET CLOSE, THEN SWING"
	elseif step.Id == "Practice" then
		return "KNOCK OUT BOTH OF THEM"
	end
	return "AIM AT THE GLOWING TARGET"
end

export type PlacementInput = {
	viewportWidth: number,
	viewportHeight: number,
	-- Middle of the region a tap or a hold is actually read in.
	pressCenterX: number,
	pressCenterY: number,
	-- Top edge of the region a swipe has to start inside.
	swipeTopY: number,
	-- Largest on-screen extent of the reticle, as a radius.
	reticleRadius: number,
	glyphSize: number,
	labelHeight: number,
	clearance: number,
}

export type Placement = { x: number, y: number, beside: boolean }

-- Where the indicator sits. It belongs in the region the input is read in, and
-- it may not cover the reticle, run into the swipe region, or leave the screen.
-- Below the reticle is preferred because that is the direction the eye already
-- travels; a short viewport has no room there, so it goes beside it instead,
-- which is still inside the same region and still clear of everything.
function OnboardingViewModel.gesturePlacement(input: PlacementInput): Placement
	local half = input.glyphSize / 2
	local assembly = half + input.labelHeight
	local ceiling = input.swipeTopY - assembly - input.clearance
	local below = input.pressCenterY + input.reticleRadius + half + input.clearance

	if below <= ceiling then
		return { x = input.pressCenterX, y = below, beside = false }
	end

	-- No room underneath. Sit level with the press centre and step sideways far
	-- enough to clear the reticle, clamped to stay on screen.
	local y = math.min(input.pressCenterY, math.max(ceiling, half + input.clearance))
	local offset = input.reticleRadius + half + input.clearance
	local x = input.pressCenterX + offset
	local rightLimit = input.viewportWidth - half - input.clearance
	if x > rightLimit then
		x = math.max(input.pressCenterX - offset, half + input.clearance)
	end
	return { x = x, y = y, beside = true }
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
