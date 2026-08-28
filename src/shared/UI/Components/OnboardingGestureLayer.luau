-- Name: OnboardingGestureLayer.luau
-- Author: Jack C.
-- Description: Draws the lesson's input indicator at the place the input is actually read, asking the combat input layer for its real regions rather than assuming any of them, and clamping the result so it can never sit on the reticle, the instruction panel, or the swipe region.
-- Created: 2026-08-28

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config = ReplicatedStorage:WaitForChild("Config")
local InputConfig = require(Config:WaitForChild("Input"))
local OnboardingConfig = require(Config:WaitForChild("Onboarding"))
local ThrowUX = require(Config:WaitForChild("ThrowUX"))
local GestureGlyph = require(script.Parent.GestureGlyph)
local useViewportSize = require(script.Parent.Parent.Hooks.useViewportSize)
local OnboardingViewModel = require(script.Parent.Parent.Models.OnboardingViewModel)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local c = React.createElement

-- This layer must be mounted in a ScreenGui with ScreenInsets.None. The
-- geometry below is in raw viewport pixels because that is the space the touch
-- classifier works in; drawing it in an inset-adjusted space would put the
-- picture a topbar's height away from where the finger is actually read.
export type Props = {
	Snapshot: any,
}

-- The action whose binding the glyph should draw. FindFirstChild rather than
-- WaitForChild: the context is built for each player at runtime, and a prompt
-- is a nicety that must degrade to its fallback text rather than yield.
local function throwAction(): any
	local context = Players.LocalPlayer:FindFirstChild(InputConfig.ContextName)
	local action = context and context:FindFirstChild("Throw")
	return if action and action:IsA("InputAction") then action else nil
end

-- The reticle's largest on-screen extent, derived the same way the combat HUD
-- sizes it, so the indicator clears it on every viewport instead of clearing a
-- number someone typed once.
local function reticleRadius(viewport: Vector2): number
	local reticle = ThrowUX.Reticle
	local diameter =
		math.clamp(math.min(viewport.X, viewport.Y) * reticle.SizeScale, reticle.MinPixels, reticle.MaxPixels)
	return diameter * reticle.FullChargeScale * 0.5
end

return function(props: Props)
	local snapshot = props.Snapshot
	-- Re-read the regions whenever the viewport changes: a rotation or a window
	-- resize moves every one of them.
	local viewport = useViewportSize()
	local geometry = React.useMemo(function()
		return Combat.inputGeometry()
	end, { viewport })

	local gesture = OnboardingViewModel.gesture(snapshot)
	if gesture == nil or viewport.X <= 0 or viewport.Y <= 0 then
		return nil
	end

	local sizing = OnboardingConfig.UI.Gesture
	local glyphSize =
		math.clamp(math.min(viewport.X, viewport.Y) * sizing.SizeScale, sizing.MinPixels, sizing.MaxPixels)
	local placement = OnboardingViewModel.gesturePlacement({
		viewportWidth = viewport.X,
		viewportHeight = viewport.Y,
		pressCenterX = geometry.pressCenter.X,
		pressCenterY = geometry.pressCenter.Y,
		swipeTopY = if geometry.swipeEnabled then geometry.swipeRect.minY else viewport.Y,
		reticleRadius = reticleRadius(viewport),
		glyphSize = glyphSize,
		labelHeight = glyphSize * sizing.LabelScale,
		clearance = sizing.ClearancePixels,
	})

	local action: any = nil
	if gesture.kind == "Action" or gesture.kind == "ActionHold" then
		action = throwAction()
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Glyph = c(GestureGlyph, {
			Kind = gesture.kind,
			Label = gesture.label,
			InputAction = action,
			FallbackText = gesture.fallback,
			HoldSeconds = geometry.holdDelaySeconds,
			SizePixels = glyphSize,
			Color = sizing.Color,
			InkColor = sizing.InkColor,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(placement.x, placement.y),
				ZIndex = 12,
			},
		}),
	})
end
