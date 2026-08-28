-- Name: GestureGlyph.luau
-- Author: Jack C.
-- Description: The one way this game draws "do this input": a dot for a tap, a ringed dot for a hold, a dot with a trail and chevron for a swipe, and the platform's own key glyph for a button, so every prompt in the game speaks the same visual language.
-- Created: 2026-08-28

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local ResponsiveText = require(script.Parent.ResponsiveText)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)

local c = React.createElement

-- The notation is the established one for touch documentation (Villamor,
-- Willis and Wroblewski's touch gesture guide, and the UXmatters gesture
-- language): a dot is a contact point, a ring around it means the contact is
-- held, and a trail with a head shows the direction it travels. Nothing here
-- invents a symbol a player would have to be taught separately.

export type Kind = "Tap" | "Hold" | "Swipe" | "Action" | "ActionHold"

export type Props = {
	Kind: Kind,
	-- Word under the glyph. Keep it to one.
	Label: string?,
	-- Action kinds only: the InputAction whose current binding should be drawn.
	InputAction: any?,
	-- Action kind fallback when the engine cannot resolve a glyph.
	FallbackText: string?,
	-- Swipe kind only: how far the trail runs, in pixels. Pass the real
	-- recognition distance so the picture is not a guess.
	TravelPixels: number?,
	-- Hold kinds only: how long the ring takes to close, in seconds.
	HoldSeconds: number?,
	Color: Color3?,
	InkColor: Color3?,
	-- Diameter of the contact dot's frame, in pixels.
	SizePixels: number?,
	Native: { [any]: any }?,
}

-- Ramps to full over the first `hold` of the cycle and rests there, so a loop
-- reads as "do the thing, then a beat, then again" without a second animation.
local function rampThenHold(hold: number): (number) -> number
	local clamped = math.clamp(hold, 0.05, 1)
	return function(t: number): number
		return math.min(t / clamped, 1)
	end
end

local DEFAULT_SIZE = 54
local DEFAULT_COLOR = Color3.fromRGB(255, 224, 78)
local DEFAULT_INK = Color3.fromRGB(24, 41, 48)
local LABEL_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")

-- InputActionLabel resolves a binding to the glyph for whatever device is in
-- the player's hands right now, including Xbox versus PlayStation art, and
-- re-resolves on a device switch with no scripting. It is only absent on a
-- client older than the input-action release, so the probe decides once.
local inputActionLabelSupported: boolean? = nil

local function supportsInputActionLabel(): boolean
	if inputActionLabelSupported == nil then
		local ok, instance = pcall(Instance.new, "InputActionLabel")
		inputActionLabelSupported = ok
		if ok and instance then
			(instance :: Instance):Destroy()
		end
	end
	return inputActionLabelSupported == true
end

local function circle(props: { [any]: any }, children: { [any]: any }?): any
	local merged = table.clone(props)
	local kids = table.clone(children or {})
	kids.Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) })
	return c("Frame", merged, kids)
end

local function outline(color: Color3, thickness: number, transparency: number?): any
	return c("UIStroke", {
		Color = color,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness,
		Transparency = transparency or 0,
	})
end

local function label(text: string, ink: Color3): any
	return c(ResponsiveText, {
		MeasurementFont = Enum.Font.LuckiestGuy,
		MaxTextSize = 26,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = LABEL_FONT,
			Position = UDim2.fromScale(0.5, 1.1),
			Size = UDim2.fromScale(2.6, 0.42),
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 3,
		},
	}, {
		Stroke = outline(ink, 0.12, 0.05),
	})
end

-- A tap is a contact and a release, so the ring leaves the dot and fades: the
-- ripple a screen gives back when it is touched.
local function Tap(props: { color: Color3, ink: Color3, reducedMotion: boolean })
	local styles = ReactSpring.useSpring({
		from = { Pulse = 0 },
		to = { Pulse = 1 },
		loop = not props.reducedMotion,
		config = { duration = 1.15, easing = rampThenHold(0.7) },
		immediate = props.reducedMotion,
	})
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Ripple = circle({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = styles.Pulse:map(function(value: number)
				local scale = 0.62 + value * 1.1
				return UDim2.fromScale(scale, scale)
			end),
			ZIndex = 1,
		}, {
			Stroke = c("UIStroke", {
				Color = props.color,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.07,
				Transparency = styles.Pulse:map(function(value: number)
					return math.clamp(value * value, 0, 1)
				end),
			}),
		}),
		Dot = circle({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = props.color,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = styles.Pulse:map(function(value: number)
				local squash = 1 - 0.14 * math.max(1 - value * 6, 0)
				return UDim2.fromScale(0.58 * squash, 0.58 * squash)
			end),
			ZIndex = 2,
		}, { Stroke = outline(props.ink, 0.14) }),
	})
end

-- A hold is a contact that stays down, so a ring closes onto whatever sits in
-- the middle over exactly the time the input layer waits before a press becomes
-- a charge. The centre is a dot on touch and the platform's key glyph on a
-- mouse or a pad, because the notation is about the duration, not the button.
local function HoldRing(props: { color: Color3, seconds: number, reducedMotion: boolean, center: any })
	local seconds = math.max(props.seconds, 0.05)
	local cycle = seconds + 0.5
	local styles = ReactSpring.useSpring({
		from = { Close = 0 },
		to = { Close = 1 },
		loop = not props.reducedMotion,
		config = { duration = cycle, easing = rampThenHold(seconds / cycle) },
		immediate = props.reducedMotion,
	})
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Track = circle({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(2, 2),
			ZIndex = 1,
		}, { Stroke = outline(props.color, 0.04, 0.62) }),
		Closing = circle({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = styles.Close:map(function(value: number)
				local scale = 2 - 0.45 * math.clamp(value, 0, 1)
				return UDim2.fromScale(scale, scale)
			end),
			ZIndex = 2,
		}, {
			Stroke = c("UIStroke", {
				Color = props.color,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.08,
			}),
		}),
		Center = props.center,
	})
end

local function holdDot(color: Color3, ink: Color3): any
	return circle({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		ZIndex = 3,
	}, { Stroke = outline(ink, 0.14) })
end

-- Two rounded bars meeting at a point: a chevron, drawn rather than imported so
-- it inherits the same stroke weight as everything around it.
local function chevron(color: Color3, ink: Color3): any
	local function bar(rotation: number, anchorX: number)
		return c("Frame", {
			AnchorPoint = Vector2.new(anchorX, 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Rotation = rotation,
			Size = UDim2.fromScale(0.62, 0.24),
			ZIndex = 3,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = outline(ink, 0.5),
		})
	end
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1.15, 0.62),
		ZIndex = 3,
	}, {
		Left = bar(-42, 1),
		Right = bar(42, 0),
	})
end

-- A swipe is a contact that travels, so the dot runs the real recognition
-- distance along a trail and the chevron marks the end of the stroke.
local function Swipe(props: { color: Color3, ink: Color3, travel: number, reducedMotion: boolean })
	local styles = ReactSpring.useSpring({
		from = { Travel = 0 },
		to = { Travel = 1 },
		loop = not props.reducedMotion,
		config = { duration = 1.15, easing = rampThenHold(0.66) },
		immediate = props.reducedMotion,
	})
	local travel = math.max(props.travel, 1)
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, travel),
	}, {
		Trail = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = props.color,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Size = styles.Travel:map(function(value: number)
				return UDim2.new(0.24, 0, math.clamp(value, 0, 1), 0)
			end),
			ZIndex = 1,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Head = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = styles.Travel:map(function(value: number)
				return UDim2.fromScale(0.5, 1 - math.clamp(value, 0, 1))
			end),
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 2,
		}, {
			Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Dot = circle({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = props.color,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.62, 0.62),
				ZIndex = 2,
			}, { Stroke = outline(props.ink, 0.14) }),
		}),
		Chevron = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 3,
		}, {
			Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Mark = chevron(props.color, props.ink),
		}),
	})
end

-- The platform's own key art, on a plate that matches the game's buttons. The
-- engine picks the glyph for the device in the player's hands, so a controller
-- player never sees a mouse instruction and a DualSense never shows Xbox faces.
local function actionPlate(props: { action: any, fallback: string, color: Color3, ink: Color3, scale: number })
	local resolved = props.action ~= nil and supportsInputActionLabel()
	return circle({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = props.ink,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(props.scale, props.scale),
		ZIndex = 3,
	}, {
		Stroke = outline(props.color, 0.075),
		Glyph = if resolved
			then c("InputActionLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = LABEL_FONT,
				ImageColor3 = Color3.new(1, 1, 1),
				InputAction = props.action,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.68, 0.68),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 3,
			})
			else c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 30,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = LABEL_FONT,
					Position = UDim2.fromScale(0.5, 0.54),
					Size = UDim2.fromScale(0.78, 0.5),
					Text = props.fallback,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 3,
				},
			}),
	})
end

return function(props: Props)
	local reducedMotion = useReducedMotion()
	local color = props.Color or DEFAULT_COLOR
	local ink = props.InkColor or DEFAULT_INK
	local size = props.SizePixels or DEFAULT_SIZE
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.Size = UDim2.fromOffset(size, size)
	if native.AnchorPoint == nil then
		native.AnchorPoint = Vector2.new(0.5, 0.5)
	end

	local isAction = props.Kind == "Action" or props.Kind == "ActionHold"
	local centre = if isAction
		then actionPlate({
			action = props.InputAction,
			fallback = props.FallbackText or "",
			color = color,
			ink = ink,
			scale = if props.Kind == "ActionHold" then 1.1 else 1.45,
		})
		else holdDot(color, ink)

	local body
	if props.Kind == "Tap" then
		body = c(Tap, { color = color, ink = ink, reducedMotion = reducedMotion })
	elseif props.Kind == "Hold" or props.Kind == "ActionHold" then
		body = c(HoldRing, {
			color = color,
			seconds = props.HoldSeconds or 0.35,
			reducedMotion = reducedMotion,
			center = centre,
		})
	elseif props.Kind == "Swipe" then
		body = c(Swipe, {
			color = color,
			ink = ink,
			travel = props.TravelPixels or size * 2,
			reducedMotion = reducedMotion,
		})
	else
		body = centre
	end

	return c("Frame", native, {
		Body = body,
		Label = if props.Label and props.Label ~= "" then label(props.Label, ink) else nil,
	})
end
