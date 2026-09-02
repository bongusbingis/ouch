-- Name: GestureHint.luau
-- Author: Jack C.
-- Description: Places an onboarding touch gesture against the combat input layer's live viewport geometry, clear of the reticle and the swipe zone.
-- Created: 2026-08-26

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config = ReplicatedStorage:WaitForChild("Config")
local OnboardingConfig = require(Config:WaitForChild("Interface"):WaitForChild("Onboarding"))
local ThrowUX = require(Config:WaitForChild("Interface"):WaitForChild("ThrowUX"))
local GestureGlyph = require(script.Parent.GestureGlyph)
local useViewportSize = require(script.Parent.Parent.Parent.Hooks.useViewportSize)
local GestureViewModel = require(script.Parent.Parent.Parent.Models.OnboardingGestureViewModel)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local c = React.createElement

export type Props = {
	Kind: GestureViewModel.Kind,
	DeviceClass: string,
	Label: string?,
}

local function reticleRadius(viewport: Vector2): number
	local reticle = ThrowUX.Reticle
	local diameter =
		math.clamp(math.min(viewport.X, viewport.Y) * reticle.SizeScale, reticle.MinPixels, reticle.MaxPixels)
	return diameter * reticle.FullChargeScale * 0.5
end

return function(props: Props)
	local viewport = useViewportSize()
	if props.DeviceClass ~= "Touch" or viewport.X <= 0 or viewport.Y <= 0 then
		return nil
	end
	-- Read fresh each render rather than memoising: the control rects a prompt
	-- anchors to (the swipe band's free column, the action button) are published
	-- as their UI lays out, and a stale snapshot would strand a prompt at the
	-- fallback position once a control finally registers.
	local geometry = Combat.inputGeometry()

	local sizing = OnboardingConfig.Gesture
	local size = math.clamp(math.min(viewport.X, viewport.Y) * sizing.SizeScale, sizing.MinPixels, sizing.MaxPixels)
	local labelHeight = size * sizing.LabelScale
	local anchor = Vector2.new(0.5, 0.5)
	local position: Vector2

	if props.Kind == "Swipe" then
		-- The flick starts in the free right-hand column of the swipe band, where
		-- the aiming thumb rests -- not the screen centre, which sits over the
		-- joystick and hotbar.
		anchor = Vector2.new(0.5, 1)
		position =
			Vector2.new(geometry.swipeAnchor.X, geometry.swipeRect.maxY - size - geometry.swipeDistancePixels * 0.35)
	elseif props.Kind == "Tap" and geometry.actionButtonRect ~= nil then
		-- The tap action is the on-screen BONK button; crown the real control
		-- instead of floating a ring over the reticle, and stay above the thumb.
		local rect = geometry.actionButtonRect
		anchor = Vector2.new(0.5, 1)
		position = Vector2.new((rect.minX + rect.maxX) / 2, rect.minY - sizing.ClearancePixels)
	else
		local placement = GestureViewModel.placement({
			viewportWidth = viewport.X,
			viewportHeight = viewport.Y,
			pressCenterX = geometry.pressCenter.X,
			pressCenterY = geometry.pressCenter.Y,
			swipeTopY = math.min(geometry.swipeRect.minY, viewport.Y),
			reticleRadius = reticleRadius(viewport),
			glyphSize = size,
			labelHeight = labelHeight,
			clearance = sizing.ClearancePixels,
		})
		position = Vector2.new(placement.x, placement.y)
	end

	return c(GestureGlyph, {
		Kind = props.Kind,
		Label = props.Label,
		HoldSeconds = geometry.holdDelaySeconds,
		TravelPixels = geometry.swipeDistancePixels,
		SizePixels = size,
		Native = {
			AnchorPoint = anchor,
			Position = UDim2.fromOffset(position.X, position.Y),
			ZIndex = 61,
		},
	})
end
