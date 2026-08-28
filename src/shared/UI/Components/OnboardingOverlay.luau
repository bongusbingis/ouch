-- Name: OnboardingOverlay.luau
-- Author: Jack C.
-- Description: The training overlay: the contextual prompt and input glyph, the escalating hint line, the optional mobile swipe tip, the corner skip control, the party-ready choice, and the completion card, all driven from one snapshot.
-- Created: 2026-08-27

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Config = ReplicatedStorage:WaitForChild("Config")
local OnboardingConfig = require(Config:WaitForChild("Onboarding"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local OnboardingViewModel = require(script.Parent.Parent.Models.OnboardingViewModel)

local c = React.createElement

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local INK = Color3.new(1, 1, 1)
local ACCENT = Color3.fromRGB(102, 232, 255)
local SHADOW = Color3.fromRGB(24, 22, 48)

export type Props = {
	Snapshot: any,
	OnSkip: () -> (),
	OnJoinPartyMatch: () -> (),
	OnKeepTraining: () -> (),
}

local function shoutedText(text: string, size: UDim2, position: UDim2, color: Color3, zIndex: number)
	return c(ResponsiveText, {
		MeasurementFont = Enum.Font.LuckiestGuy,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = FONT,
			Position = position,
			Size = size,
			Text = text,
			TextColor3 = color,
			ZIndex = zIndex,
		},
	}, {
		Stroke = c("UIStroke", {
			Color = SHADOW,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.09,
		}),
	})
end

-- The prompt sits high and centred: near enough to the reticle to be read
-- without looking away, far enough from it never to sit under the aim point or
-- a thumb.
local function Prompt(props: { snapshot: any })
	local model = OnboardingViewModel.prompt(props.snapshot)
	local hint = OnboardingViewModel.hintText(props.snapshot)
	local reducedMotion = useReducedMotion()
	local success = props.snapshot.success ~= ""
	local styles = ReactSpring.useSpring({
		Scale = if not model.visible then 0.7 else if success then 1.12 else 1,
		Transparency = if model.visible then 0 else 1,
		config = Motion.Control,
		immediate = reducedMotion,
	})
	if not model.visible then
		return nil
	end
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.62, 0.24),
		ZIndex = 20,
	}, {
		Scale = c("UIScale", { Scale = styles.Scale }),
		Headline = shoutedText(model.headline, UDim2.fromScale(1, 0.5), UDim2.fromScale(0.5, 0.28), INK, 21),
		Glyph = if model.glyph ~= ""
			then c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = SHADOW,
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.56),
				Size = UDim2.fromScale(0.24, 0.24),
				ZIndex = 21,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.28, 0) }),
				Bounds = c("UISizeConstraint", { MaxSize = Vector2.new(220, 74), MinSize = Vector2.new(84, 36) }),
				Stroke = c("UIStroke", {
					Color = ACCENT,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.06,
				}),
				Label = shoutedText(model.glyph, UDim2.fromScale(0.86, 0.72), UDim2.fromScale(0.5, 0.5), ACCENT, 22),
			})
			else nil,
		Caption = if model.caption ~= ""
			then shoutedText(model.caption, UDim2.fromScale(0.8, 0.12), UDim2.fromScale(0.5, 0.87), INK, 21)
			else nil,
		Hint = if hint ~= ""
			then shoutedText(hint, UDim2.fromScale(1, 0.13), UDim2.fromScale(0.5, 1.02), ACCENT, 21)
			else nil,
	})
end

-- Offered, never required: the tap already taught the throw, and this is the
-- second way to do the same thing.
local function SwipeHint(props: { visible: boolean })
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		Offset = if props.visible then 1 else 0,
		Transparency = if props.visible then 0 else 1,
		config = { mass = 1, tension = 260, friction = 22 },
		loop = props.visible and not reducedMotion,
		immediate = reducedMotion,
	})
	if not props.visible then
		return nil
	end
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.fromScale(0.5, 0.16),
		ZIndex = 20,
	}, {
		Label = shoutedText("SWIPE UP TO THROW TOO", UDim2.fromScale(1, 0.45), UDim2.fromScale(0.5, 0.7), INK, 21),
		Finger = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = ACCENT,
			BorderSizePixel = 0,
			Position = styles.Offset:map(function(value: number)
				return UDim2.fromScale(0.5, 0.36 - value * 0.22)
			end),
			Size = UDim2.fromOffset(18, 18),
			ZIndex = 21,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
	})
end

-- Discoverable, never dominant. Two presses: the first arms it, the second
-- inside the confirm window commits, so a stray tap costs nothing.
local function SkipControl(props: { visible: boolean, onSkip: () -> () })
	local armed, setArmed = React.useState(false)
	local armRevision = React.useRef(0)
	React.useEffect(function()
		if not props.visible and armed then
			setArmed(false)
		end
	end, { props.visible })
	if not props.visible then
		return nil
	end
	local inset = OnboardingConfig.UI.SkipCornerInset
	return c(AnimatedButton, {
		Style = "Standard",
		Native = {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = SHADOW,
			BackgroundTransparency = if armed then 0.05 else 0.45,
			BorderSizePixel = 0,
			Image = "",
			Position = UDim2.fromScale(1 - inset, inset),
			Size = UDim2.fromScale(0.13, 0.062),
			ZIndex = 30,
		},
		OnActivated = function()
			if armed then
				props.onSkip()
				return
			end
			setArmed(true)
			armRevision.current += 1
			local revision = armRevision.current
			task.delay(OnboardingConfig.Eligibility.SkipConfirmSeconds, function()
				if armRevision.current == revision then
					setArmed(false)
				end
			end)
		end,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0.35, 0) }),
		Bounds = c("UISizeConstraint", { MaxSize = Vector2.new(200, 56), MinSize = Vector2.new(92, 30) }),
		Stroke = c("UIStroke", {
			Color = if armed then ACCENT else INK,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.05,
		}),
		Label = shoutedText(
			if armed then "SKIP?" else "SKIP",
			UDim2.fromScale(0.82, 0.66),
			UDim2.fromScale(0.5, 0.54),
			if armed then ACCENT else INK,
			31
		),
	})
end

-- A real match always outranks training. The player is asked rather than
-- yanked, and the harder choice is never the default focus.
local function PartyReady(props: { visible: boolean, onJoin: () -> (), onKeep: () -> () })
	local joinRef = React.useRef(nil)
	React.useEffect(function()
		if not props.visible then
			return
		end
		task.defer(function()
			local button = joinRef.current
			if button and button.Parent and button.Visible and button.Selectable then
				GuiService.SelectedObject = button
			end
		end)
	end, { props.visible })
	if not props.visible then
		return nil
	end
	local function choice(text: string, order: number, color: Color3, onActivated: () -> (), buttonRef: any?)
		return c(AnimatedButton, {
			ButtonRef = buttonRef,
			Style = "Primary",
			Native = {
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Image = "",
				LayoutOrder = order,
				Size = UDim2.fromScale(0.46, 1),
				ZIndex = 41,
			},
			OnActivated = onActivated,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
			Label = shoutedText(text, UDim2.fromScale(0.86, 0.6), UDim2.fromScale(0.5, 0.5), INK, 42),
		})
	end
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = SHADOW,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.56, 0.2),
		ZIndex = 40,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0.12, 0) }),
		Bounds = c("UISizeConstraint", { MaxSize = Vector2.new(720, 190) }),
		Title = shoutedText("YOUR PARTY IS READY!", UDim2.fromScale(0.9, 0.34), UDim2.fromScale(0.5, 0.26), INK, 41),
		Buttons = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.92),
			Size = UDim2.fromScale(0.9, 0.42),
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.04, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Join = choice("JOIN MATCH", 1, Color3.fromRGB(76, 196, 122), props.onJoin, joinRef),
			Keep = choice("KEEP TRAINING", 2, Color3.fromRGB(96, 92, 140), props.onKeep),
		}),
	})
end

local function Completion(props: { visible: boolean })
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		Scale = if props.visible then 1 else 0.6,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	if not props.visible then
		return nil
	end
	local skills = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.04, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, label in OnboardingViewModel.completedSkills() do
		skills[`Skill{index}`] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Size = UDim2.fromScale(0.28, 1),
		}, {
			Label = shoutedText(`✓ {label}`, UDim2.fromScale(1, 0.8), UDim2.fromScale(0.5, 0.5), ACCENT, 51),
		})
	end
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.7, 0.4),
		ZIndex = 50,
	}, {
		Scale = c("UIScale", { Scale = styles.Scale }),
		Headline = shoutedText("READY!", UDim2.fromScale(1, 0.55), UDim2.fromScale(0.5, 0.36), INK, 51),
		Skills = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.72),
			Size = UDim2.fromScale(0.92, 0.2),
		}, skills),
	})
end

return function(props: Props)
	local snapshot = props.Snapshot
	if snapshot.route ~= "Training" then
		return nil
	end
	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Prompt = c(Prompt, { snapshot = snapshot }),
		SwipeHint = c(SwipeHint, { visible = snapshot.swipeHint }),
		Skip = c(SkipControl, {
			visible = OnboardingViewModel.skipVisible(snapshot, OnboardingConfig.Eligibility.SkipEnabled),
			onSkip = props.OnSkip,
		}),
		PartyReady = c(PartyReady, {
			visible = snapshot.partyReady,
			onJoin = props.OnJoinPartyMatch,
			onKeep = props.OnKeepTraining,
		}),
		Completion = c(Completion, { visible = snapshot.celebrating }),
	})
end
