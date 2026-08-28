-- Name: OnboardingOverlay.luau
-- Author: Jack C.
-- Description: The training chrome: the instruction panel, the corner skip control, the party-ready choice, and the completion card, all in the game's own panel and button treatment.
-- Created: 2026-08-27

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Config = ReplicatedStorage:WaitForChild("Config")
local OnboardingConfig = require(Config:WaitForChild("Onboarding"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local NotificationModal = require(script.Parent.NotificationModal)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local OnboardingViewModel = require(script.Parent.Parent.Models.OnboardingViewModel)

local c = React.createElement

-- The game's own kit. Every surface here is the same nine-slice panel and
-- button art the loading screen, the notification modal and the shop use, so
-- training does not read as a different product.
local PANEL_IMAGE = "rbxassetid://124751224634629"
local PANEL_SLICE = Rect.new(31, 41, 978, 620)
local BLUE_BUTTON = "rbxassetid://136021539696619"
local BUTTON_SLICE = Rect.new(198, 228, 841, 468)
local INK = Color3.fromRGB(24, 41, 48)
local HIGHLIGHT = Color3.fromRGB(255, 224, 78)
local HEADLINE_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

export type Props = {
	Snapshot: any,
	OnSkip: () -> (),
	OnJoinPartyMatch: () -> (),
	OnKeepTraining: () -> (),
}

local function textStroke(thickness: number)
	return c("UIStroke", {
		Color = INK,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = thickness,
		Transparency = 0.08,
	})
end

local function headline(text: string, maxTextSize: number, position: UDim2, size: UDim2, zIndex: number)
	return c(ResponsiveText, {
		HostName = "Headline",
		MeasurementFont = Enum.Font.LuckiestGuy,
		MaxTextSize = maxTextSize,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = HEADLINE_FONT,
			Position = position,
			Size = size,
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = zIndex,
		},
	}, { Stroke = textStroke(0.045) })
end

-- One panel, top-centre, holding the verb and at most one clarifying line. The
-- world does the teaching; this only names the action.
local function InstructionPanel(props: { snapshot: any })
	local model = OnboardingViewModel.prompt(props.snapshot)
	local hint = OnboardingViewModel.hintText(props.snapshot)
	local reducedMotion = useReducedMotion()
	local success = props.snapshot.success ~= ""
	local layout = OnboardingConfig.UI.Panel
	local styles = ReactSpring.useSpring({
		Scale = if not model.visible then 0.78 else if success then 1.06 else 1,
		Rotation = if success then -1.5 else 0,
		config = Motion.Control,
		immediate = reducedMotion,
	})
	if not model.visible then
		return nil
	end
	return c("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Image = PANEL_IMAGE,
		ImageColor3 = if success then HIGHLIGHT else Color3.new(1, 1, 1),
		Position = UDim2.fromScale(0.5, layout.TopScale),
		Rotation = styles.Rotation,
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(layout.WidthScale, layout.HeightScale),
		SliceCenter = PANEL_SLICE,
		SliceScale = 0.35,
		ZIndex = 20,
	}, {
		Scale = c("UIScale", { Scale = styles.Scale }),
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = layout.AspectRatio }),
		Bounds = c("UISizeConstraint", {
			MaxSize = layout.MaxPixels,
			MinSize = layout.MinPixels,
		}),
		Headline = headline(
			model.headline,
			58,
			UDim2.fromScale(0.5, if hint ~= "" then 0.4 else 0.5),
			UDim2.fromScale(0.86, 0.42),
			21
		),
		Hint = if hint ~= ""
			then c(ResponsiveText, {
				HostName = "Hint",
				MeasurementFont = Enum.Font.Highway,
				MaxTextSize = 30,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = BODY_FONT,
					Position = UDim2.fromScale(0.5, 0.72),
					Size = UDim2.fromScale(0.84, 0.2),
					Text = hint,
					TextColor3 = HIGHLIGHT,
					ZIndex = 21,
				},
			}, { Stroke = textStroke(0.06) })
			else nil,
	})
end

-- Discoverable without competing. The first press arms it, a second press
-- inside the confirm window commits, so a stray tap never costs the tutorial.
local function SkipControl(props: { visible: boolean, onSkip: () -> () })
	local armed, setArmed = React.useState(false)
	local armRevision = React.useRef(0)
	React.useEffect(function()
		if not props.visible and armed then
			setArmed(false)
		end
	end, { props.visible })
	React.useEffect(function()
		return function()
			armRevision.current += 1
		end
	end, {})
	if not props.visible then
		return nil
	end
	local inset = OnboardingConfig.UI.SkipCornerInset
	return c(AnimatedButton, {
		Style = "Standard",
		Native = {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Image = BLUE_BUTTON,
			ImageColor3 = if armed then HIGHLIGHT else Color3.new(1, 1, 1),
			Position = UDim2.fromScale(1 - inset, inset),
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(0.135, 0.09),
			SliceCenter = BUTTON_SLICE,
			SliceScale = 0.12,
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
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = 3.1 }),
		Bounds = c("UISizeConstraint", { MaxSize = Vector2.new(220, 71), MinSize = Vector2.new(104, 34) }),
		Label = headline(
			if armed then "SKIP?" else "SKIP",
			26,
			UDim2.fromScale(0.5, 0.56),
			UDim2.fromScale(0.78, 0.56),
			31
		),
	})
end

local function Completion(props: { visible: boolean })
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		Scale = if props.visible then 1 else 0.62,
		Rotation = if props.visible then 0 else -3,
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
			Padding = UDim.new(0.03, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, skill in OnboardingViewModel.completedSkills() do
		skills[`Skill{index}`] = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = BLUE_BUTTON,
			ImageColor3 = HIGHLIGHT,
			LayoutOrder = index,
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(0.3, 1),
			SliceCenter = BUTTON_SLICE,
			SliceScale = 0.1,
			ZIndex = 51,
		}, {
			Label = headline(skill, 26, UDim2.fromScale(0.5, 0.56), UDim2.fromScale(0.82, 0.5), 52),
		})
	end
	return c("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = PANEL_IMAGE,
		Position = UDim2.fromScale(0.5, 0.47),
		Rotation = styles.Rotation,
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(0.42, 0.28),
		SliceCenter = PANEL_SLICE,
		SliceScale = 0.4,
		ZIndex = 50,
	}, {
		Scale = c("UIScale", { Scale = styles.Scale }),
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = 2.3 }),
		Bounds = c("UISizeConstraint", { MaxSize = Vector2.new(860, 374), MinSize = Vector2.new(360, 157) }),
		Headline = headline("READY!", 78, UDim2.fromScale(0.5, 0.33), UDim2.fromScale(0.8, 0.34), 51),
		Skills = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.86),
			Size = UDim2.fromScale(0.86, 0.24),
			ZIndex = 51,
		}, skills),
	})
end

-- A real match outranks training, so the choice is put in the game's own
-- confirmation modal rather than in a bespoke bar that would sit on top of the
-- jump button and the thumbstick.
local function partyRequest()
	return {
		Title = "YOUR PARTY IS READY!",
		Description = "YOUR PARTY IS HEADING INTO A MATCH.",
		Buttons = {
			{ Color = "Blue" :: "Blue", Text = "JOIN MATCH", Value = true },
			{ Color = "Red" :: "Red", Text = "KEEP TRAINING", Value = false },
		},
	}
end

return function(props: Props)
	local snapshot = props.Snapshot
	if snapshot.route ~= "Training" then
		return nil
	end
	local partyOpen = snapshot.partyReady == true
	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Panel = if partyOpen then nil else c(InstructionPanel, { snapshot = snapshot }),
		Skip = c(SkipControl, {
			visible = OnboardingViewModel.skipVisible(snapshot, OnboardingConfig.Eligibility.SkipEnabled)
				and not partyOpen,
			onSkip = props.OnSkip,
		}),
		Completion = c(Completion, { visible = snapshot.celebrating and not partyOpen }),
		PartyReady = c(NotificationModal, {
			Request = if partyOpen then partyRequest() else nil,
			OnChoose = function(joinMatch)
				if joinMatch then
					props.OnJoinPartyMatch()
				else
					props.OnKeepTraining()
				end
			end,
		}),
	})
end
