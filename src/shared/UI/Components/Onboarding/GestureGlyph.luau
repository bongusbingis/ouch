-- Description: Draws the shared touch contact, hold, and swipe notation in the game's teal accent. Physical gestures only -- bound-key prompts are shown inline by the surface that needs them.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local useLoopPhase = require(script.Parent.Parent.Parent.Hooks.useLoopPhase)
local useReducedMotion = require(script.Parent.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

local c = React.createElement

local ACCENT = Color3.fromRGB(97, 255, 237)
local INK = Color3.fromRGB(24, 41, 48)
local LABEL_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")

export type Kind = "Tap" | "Hold" | "Swipe"

export type Props = {
	Kind: Kind,
	Label: string?,
	TravelPixels: number?,
	HoldSeconds: number?,
	SizePixels: number?,
	Native: { [any]: any }?,
}

local DEFAULT_SIZE = 56
local PERIOD_SECONDS = 1.9

local function easeOut(alpha: number): number
	return 1 - (1 - alpha) ^ 3
end

local function circle(props: { [any]: any }, children: { [any]: any }?): any
	local kids = table.clone(children or {})
	kids.Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) })
	return c("Frame", props, kids)
end

local function stroke(color: Color3, thickness: number, transparency: any?): any
	return c("UIStroke", {
		Color = color,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness,
		Transparency = transparency,
	})
end

local function tapFrame(phase: number)
	local press = math.clamp(phase / 0.3, 0, 1)
	local ripple = math.clamp((phase - 0.3) / 0.5, 0, 1)
	return {
		dot = 1 - 0.26 * math.sin(press * math.pi),
		ring = 0.62 + easeOut(ripple) * 1.3,
		fade = if ripple <= 0 then 1 else 0.2 + ripple * 0.8,
	}
end

local function holdFrame(phase: number, closeAt: number)
	local close = math.clamp(phase / math.max(closeAt, 0.05), 0, 1)
	return {
		dot = 1 + 0.2 * close,
		ring = 2 - 0.95 * close,
		fade = 0.1,
	}
end

local function contactDot(): any
	return circle({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		ZIndex = 4,
	}, { Stroke = stroke(INK, 0.16) })
end

local function Contact(props: { kind: Kind, seconds: number, reducedMotion: boolean })
	local phase = useLoopPhase(PERIOD_SECONDS, props.reducedMotion)
	local held = props.kind == "Hold"
	local closeAt = math.clamp(props.seconds / PERIOD_SECONDS, 0.08, 0.7)
	local function frame(value: number)
		return if held then holdFrame(value, closeAt) else tapFrame(value)
	end
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Track = if held
			then circle({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(2, 2),
				ZIndex = 1,
			}, { Stroke = stroke(ACCENT, 0.03, 0.78) })
			else nil,
		Ring = circle({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = phase:map(function(value: number)
				local scale = frame(value).ring
				return UDim2.fromScale(scale, scale)
			end),
			ZIndex = 2,
		}, {
			Stroke = stroke(
				ACCENT,
				if held then 0.058 else 0.05,
				phase:map(function(value: number)
					return frame(value).fade
				end)
			),
		}),
		Center = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
		}, {
			Scale = c("UIScale", {
				Scale = phase:map(function(value: number)
					return frame(value).dot
				end),
			}),
			Body = contactDot(),
		}),
	})
end

local function chevron(): any
	local function bar(rotation: number, anchorX: number)
		return c("Frame", {
			AnchorPoint = Vector2.new(anchorX, 1),
			BackgroundColor3 = ACCENT,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Rotation = rotation,
			Size = UDim2.fromScale(0.58, 0.22),
			ZIndex = 4,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = stroke(INK, 0.5),
		})
	end
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1.1, 0.58),
		ZIndex = 4,
	}, { Left = bar(-42, 1), Right = bar(42, 0) })
end

local function Swipe(props: { travel: number, reducedMotion: boolean })
	local phase = useLoopPhase(PERIOD_SECONDS, props.reducedMotion)
	local function progress(value: number): number
		return easeOut(math.clamp(value / 0.65, 0, 1))
	end
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, math.max(props.travel, 1)),
	}, {
		Trail = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = ACCENT,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Size = phase:map(function(value: number)
				return UDim2.fromScale(0.22, progress(value))
			end),
			ZIndex = 1,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Head = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = phase:map(function(value: number)
				return UDim2.fromScale(0.5, 1 - progress(value))
			end),
			Size = UDim2.fromScale(1, 0),
			ZIndex = 2,
		}, {
			Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Dot = contactDot(),
		}),
		Chevron = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(1, 0),
			ZIndex = 3,
		}, {
			Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Mark = chevron(),
		}),
	})
end

return function(props: Props)
	local reducedMotion = useReducedMotion()
	local size = props.SizePixels or DEFAULT_SIZE
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.Size = UDim2.fromOffset(size, size)
	if native.AnchorPoint == nil then
		native.AnchorPoint = Vector2.new(0.5, 0.5)
	end

	local body
	if props.Kind == "Swipe" then
		body = c(Swipe, { travel = props.TravelPixels or size * 2, reducedMotion = reducedMotion })
	else
		body = c(Contact, {
			kind = props.Kind,
			seconds = props.HoldSeconds or 0.35,
			reducedMotion = reducedMotion,
		})
	end

	return c("Frame", native, {
		Body = body,
		Label = if props.Label and props.Label ~= ""
			then c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = 18,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = LABEL_FONT,
					Position = UDim2.fromScale(0.5, 1.2),
					Size = UDim2.fromScale(2.4, 0.5),
					Text = props.Label,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 6,
				},
			}, {
				Stroke = stroke(INK, 0.08),
				Padding = c("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
			})
			else nil,
	})
end
