-- Name: GestureHint.luau
-- Author: Jack C.
-- Description: Animated demonstration of the input a training step is asking for, shown where the player would actually perform it. Mimes a tap, a hold, or a movement input, styled per device, so a first-time player is shown the control rather than only told its name.
-- Created: 2026-08-26

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local useReducedMotion = require(script.Parent.Parent.Parent.Hooks.useReducedMotion)
local useLoopPhase = require(script.Parent.Parent.Parent.Hooks.useLoopPhase)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

local c = React.createElement

local ACCENT = Color3.fromRGB(97, 255, 237)
local SURFACE = Color3.fromRGB(52, 52, 52)
local PERIOD_SECONDS = 1.8

export type Gesture = "Tap" | "Hold" | "Move"

export type Props = {
	Gesture: Gesture,
	DeviceClass: string,
	Label: string?,
}

local DEVICE_SURFACE: { [string]: string } = {
	Touch = "TAP HERE",
	Mouse = "CLICK",
	Gamepad = "TRIGGER",
}

local function easeOut(alpha: number): number
	return 1 - (1 - alpha) ^ 3
end

-- Each gesture is described as pure functions of a 0..1 loop phase, so the
-- animation is data rather than a chain of tweens.
local function tapFrame(phase: number)
	local press = math.clamp(phase / 0.35, 0, 1)
	local ripple = math.clamp((phase - 0.35) / 0.55, 0, 1)
	return {
		dot = 1 - 0.28 * math.sin(press * math.pi),
		ring = 0.55 + easeOut(ripple) * 1.35,
		ringFade = if ripple <= 0 then 1 else 0.25 + ripple * 0.75,
		offset = 0,
	}
end

local function holdFrame(phase: number)
	local charge = math.clamp(phase / 0.7, 0, 1)
	local release = math.clamp((phase - 0.7) / 0.3, 0, 1)
	return {
		dot = 1 + 0.16 * charge - 0.3 * math.sin(release * math.pi),
		ring = 0.55 + charge * 0.9,
		ringFade = 0.2 + release * 0.8,
		offset = 0,
	}
end

local function moveFrame(phase: number)
	local sweep = math.sin(phase * math.pi * 2)
	return {
		dot = 1,
		ring = 1.5,
		ringFade = 0.55,
		offset = sweep * 0.3,
	}
end

local FRAMES: { [string]: (number) -> { dot: number, ring: number, ringFade: number, offset: number } } = {
	Tap = tapFrame,
	Hold = holdFrame,
	Move = moveFrame,
}

return function(props: Props)
	local reducedMotion = useReducedMotion()
	local phase = useLoopPhase(PERIOD_SECONDS, reducedMotion)
	local frame = FRAMES[props.Gesture] or tapFrame
	local label = props.Label or DEVICE_SURFACE[props.DeviceClass] or DEVICE_SURFACE.Mouse

	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromScale(0.22, 0.2),
		ZIndex = 61,
	}, {
		Sizer = c("UISizeConstraint", { MinSize = Vector2.new(120, 108), MaxSize = Vector2.new(240, 216) }),
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1.1, AspectType = Enum.AspectType.FitWithinMaxSize }),

		Ripple = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = phase:map(function(value: number)
				return UDim2.fromScale(0.5 + frame(value).offset, 0.44)
			end),
			Size = phase:map(function(value: number)
				local scale = frame(value).ring * 0.44
				return UDim2.fromScale(scale, scale)
			end),
			ZIndex = 61,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = c("UIStroke", {
				Color = ACCENT,
				Thickness = 3,
				Transparency = phase:map(function(value: number)
					return frame(value).ringFade
				end),
			}),
		}),

		Dot = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = ACCENT,
			BackgroundTransparency = 0.1,
			Position = phase:map(function(value: number)
				return UDim2.fromScale(0.5 + frame(value).offset, 0.44)
			end),
			Size = phase:map(function(value: number)
				local scale = frame(value).dot * 0.3
				return UDim2.fromScale(scale, scale)
			end),
			ZIndex = 62,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),

		Caption = c(ResponsiveText, {
			MeasurementFont = Enum.Font.SourceSansBold,
			MaxTextSize = 18,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = SURFACE,
				BackgroundTransparency = 0.3,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(0.94, 0.22),
				Text = label,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 62,
			},
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Padding = c("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
		}),
	})
end
