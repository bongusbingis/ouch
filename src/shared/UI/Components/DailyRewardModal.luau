-- Name: DailyRewardModal.luau
-- Author: Jack C.
-- Description: Animated modal that presents the daily reward claim: spring entrance, 7-day progress strip, reward display, and a dismiss button.
-- Created: 2026-09-01

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Palette = UIConfig.ProgressionStyle

local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)

local c = React.createElement

local CLAIM_COLOR = Palette.Green
local CLAIMED_COLOR = Palette.Raised
local AVAILABLE_GLOW = Palette.Yellow

local CLOSE_BUTTON_ASSET = "rbxassetid://94748581468730"
local CHECK_ICON_ASSET = "rbxassetid://505845268"

export type PublicDay = {
	day: number,
	reward: { kind: string, amount: number?, itemId: string? },
	claimed: boolean,
	available: boolean,
	current: boolean,
}

export type PublicState = {
	canClaim: boolean,
	currentDay: number,
	nextDay: number,
	days: { PublicDay },
	totalClaimed: number,
}

export type Props = {
	Visible: boolean,
	State: PublicState?,
	OnClaim: (() -> ())?,
	Pending: boolean?,
	ErrorText: string?,
	FocusEnabled: boolean?,
	OnClose: (() -> ())?,
}

local function MiniDay(dayProps: { Day: PublicDay, Order: number })
	local day = dayProps.Day
	local claimed = day.claimed and not day.available
	local bgColor = if claimed then CLAIMED_COLOR elseif day.available then AVAILABLE_GLOW else Palette.Ink

	return c("Frame", {
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		LayoutOrder = dayProps.Order,
		Size = UDim2.fromScale(1 / 7 - 0.01, 1),
	}, {
		UICorner = c("UICorner", { CornerRadius = UDim.new(0.2, 0) }),
		DayLabel = if claimed
			then c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = CHECK_ICON_ASSET,
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.8, 0.7),
			})
			else c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.8),
					Text = tostring(day.day),
					TextColor3 = if day.available then Palette.Ink else Color3.new(1, 1, 1),
				},
			}),
	})
end

return function(props: Props)
	local actionRef = React.useRef(nil)
	React.useEffect(function()
		if not props.Visible or props.FocusEnabled == false then
			return
		end
		local previous = GuiService.SelectedObject
		local active = true
		task.defer(function()
			local button = actionRef.current
			if active and button and button.Parent and button.Selectable then
				GuiService.SelectedObject = button
			end
		end)
		return function()
			active = false
			if previous and previous.Parent and previous.Visible and previous.Selectable then
				GuiService.SelectedObject = previous
			end
		end
	end, { props.Visible, props.FocusEnabled })
	local reducedMotion = useReducedMotion()
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local panelSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.DailyReward,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local claimed = props.State ~= nil and not props.State.canClaim
	local styles = ReactSpring.useSpring({
		Scale = if props.Visible then 1 else 0.82,
		Rotation = if props.Visible then 0 else -2,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	local rewardStyles = ReactSpring.useSpring({
		Scale = if claimed then 1.15 else 1,
		config = Motion.Pop,
		immediate = reducedMotion,
	})

	if not props.Visible then
		return nil
	end

	local state = props.State
	if state == nil then
		return nil
	end

	local currentReward: { kind: string, amount: number?, itemId: string? }? = nil
	local currentDayNumber = if state.canClaim then state.nextDay else state.currentDay
	for _, day in state.days do
		if day.day == currentDayNumber then
			currentReward = day.reward
			break
		end
	end

	local miniDays = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.008, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, day in state.days do
		miniDays[`Day{index}`] = c(MiniDay, { Day = day, Order = index })
	end

	local streakText = if claimed then "CLAIMED!" else `DAY {currentDayNumber}`

	return c("TextButton", {
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.35,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 120,
	}, {
		Panel = c("Frame", {
			Active = true,
			ZIndex = 121,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.Surface,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = styles.Rotation,
			Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
		}, {
			ModalScale = c("UIScale", { Scale = styles.Scale }),
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 18) }),
			Outline = c("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3 }),
			HeaderBand = c("Frame", {
				BackgroundColor3 = Palette.Yellow,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 0.17, 0),
			}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }) }),
			Title = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.05),
					Size = UDim2.new(1, -120, 0.12, 0),
					Text = "DAILY REWARD!",
					TextColor3 = Palette.Ink,
					ZIndex = 2,
				},
			}),
			Divider = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Palette.Pink,
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, 0, 0.17, 16),
				Size = UDim2.fromScale(0.88, 0.012),
			}),
			DayStrip = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.17, 26),
				Size = UDim2.fromScale(0.85, 0.1),
			}, miniDays),
			RewardArea = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Palette.Ink,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.48),
				Size = UDim2.fromScale(0.7, 0.25),
			}, {
				RewardScale = c("UIScale", { Scale = rewardStyles.Scale }),
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
				RewardDisplay = if currentReward and currentReward.kind == "Bonks"
					then c(BonksLabel, {
						Amount = currentReward.amount or 0,
						MaxTextSize = 54,
						IconSize = UDim2.fromScale(0.25, 0.8),
					})
					else nil,
			}),
			StreakLabel = c(ResponsiveText, {
				HostName = "Streak",
				MeasurementFont = Enum.Font.LuckiestGuy,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.63),
					Size = UDim2.fromScale(0.8, 0.08),
					Text = props.ErrorText or streakText,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 2,
				},
			}),
			CloseButton = c(AnimatedButton, {
				ButtonRef = actionRef,
				Enabled = props.OnClose ~= nil,
				OnActivated = props.OnClose,
				Native = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 8),
					Size = UDim2.fromOffset(UIConfig.Interaction.MinTargetPx, UIConfig.Interaction.MinTargetPx),
					BackgroundColor3 = Palette.Ink,
					ZIndex = 3,
				},
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Label = c(ResponsiveText, {
					MaxTextSize = 28,
					MeasurementFont = Enum.Font.LuckiestGuy,
					Native = {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = "×",
						TextColor3 = Color3.new(1, 1, 1),
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						ZIndex = 4,
					},
				}),
			}),
			ActionButton = c(AnimatedButton, {
				Style = "Primary",
				Enabled = not props.Pending and (if state.canClaim then props.OnClaim ~= nil else props.OnClose ~= nil),
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					Image = CLOSE_BUTTON_ASSET,
					ImageColor3 = if state.canClaim then CLAIM_COLOR else Color3.new(1, 1, 1),
					Position = UDim2.fromScale(0.5, 0.92),
					ScaleType = Enum.ScaleType.Slice,
					Size = UDim2.fromScale(0.64, 0.16),
					SliceCenter = Rect.new(198, 228, 841, 468),
					SliceScale = 0.2,
				},
				OnActivated = function()
					if state.canClaim then
						if props.OnClaim then
							props.OnClaim()
						end
					elseif props.OnClose then
						props.OnClose()
					end
				end,
			}, {
				UISizeConstraint = c(
					"UISizeConstraint",
					{ MinSize = Vector2.new(0, UIConfig.Interaction.MinTargetPx) }
				),
				TextLabel = c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.5, 0.54),
						Size = UDim2.fromScale(0.7, 0.6),
						Text = if props.Pending
							then "CLAIMING..."
							elseif state.canClaim then "CLAIM REWARD"
							else "AWESOME!",
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 2,
					},
				}),
			}),
		}),
	})
end
