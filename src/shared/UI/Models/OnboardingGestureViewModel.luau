--!strict

-- Maps onboarding cues to touch gesture notation and places prompts clear of
-- combat UI. Gestures demonstrate a physical screen action, so they are drawn
-- only on touch; mouse and gamepad players read the bound control inline on the
-- onboarding panel instead of a floating diagram.

local OnboardingGestureViewModel = {}

export type Kind = "Tap" | "Hold" | "Swipe"

export type Gesture = {
	kind: Kind,
	label: string,
}

export type PlacementInput = {
	viewportWidth: number,
	viewportHeight: number,
	pressCenterX: number,
	pressCenterY: number,
	swipeTopY: number,
	reticleRadius: number,
	glyphSize: number,
	labelHeight: number,
	clearance: number,
}

export type Placement = { x: number, y: number, beside: boolean }

function OnboardingGestureViewModel.forCue(cue: string, deviceClass: string): Gesture?
	if deviceClass ~= "Touch" then
		return nil
	end
	-- The base throw is taught as the upward swipe, not the tap: swipe is the
	-- expressive throw input (it carries aim), and it matches the live HUD's own
	-- "SWIPE UP TO THROW" hint. A tap still throws; it is just not what we teach.
	-- Swipe is drawn in the empty bottom band and keeps its word; the reticle-side
	-- hold/tap cues are wordless, since the top banner already names the action and
	-- a second label would just crowd the aim point.
	if cue == "Throw" then
		return { kind = "Swipe", label = "SWIPE UP" }
	end
	if cue == "Charge" then
		return { kind = "Hold", label = "" }
	end
	if cue == "Bonk" then
		return { kind = "Tap", label = "" }
	end
	return nil
end

function OnboardingGestureViewModel.placement(input: PlacementInput): Placement
	local half = input.glyphSize / 2
	local assembly = half + input.labelHeight
	local lowest = input.swipeTopY - assembly - input.clearance
	local below = input.pressCenterY + input.reticleRadius + half + input.clearance

	if below <= lowest then
		return { x = input.pressCenterX, y = below, beside = false }
	end

	local y = math.min(input.pressCenterY, math.max(lowest, half + input.clearance))
	local offset = input.reticleRadius + half + input.clearance
	local x = input.pressCenterX + offset
	local rightLimit = input.viewportWidth - half - input.clearance
	if x > rightLimit then
		x = math.max(input.pressCenterX - offset, half + input.clearance)
	end
	return { x = x, y = y, beside = true }
end

return OnboardingGestureViewModel
