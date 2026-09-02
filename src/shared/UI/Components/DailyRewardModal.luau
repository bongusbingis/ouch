-- Name: DailyRewardModal.luau
-- Author: Jack C.
-- Description: Animated modal that presents the daily reward claim: spring entrance, 7-day progress strip, reward display, and a dismiss button.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)

local c = React.createElement

local PANEL_NINE_SLICE = "rbxassetid://124751224634629"
local PANEL_SLICE_CENTER = Rect.new(31, 41, 978, 620)
local PANEL_SLICE_SCALE = 0.5

local CLAIM_COLOR = Color3.fromRGB(154, 233, 91)
local CLAIMED_COLOR = Color3.fromRGB(100, 100, 100)
local AVAILABLE_GLOW = Color3.fromRGB(255, 211, 51)

local CLOSE_BUTTON_ASSET = "rbxassetid://94748581468730"

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
	OnClose: (() -> ())?,
}

local function MiniDay(dayProps: { Day: PublicDay, Order: number })
	local day = dayProps.Day
	local bgColor = if day.claimed
		then CLAIMED_COLOR
		elseif day.current then AVAILABLE_GLOW
		else Color3.fromRGB(80, 80, 80)
	local transparency = if day.claimed or day.current then 0 else 0.4

	return c("Frame", {
		BackgroundColor3 = bgColor,
		BackgroundTransparency = transparency,
		LayoutOrder = dayProps.Order,
		Size = UDim2.fromScale(1 / 7 - 0.01, 1),
	}, {
		UICorner = c("UICorner", { CornerRadius = UDim.new(0.2, 0) }),
		DayLabel = c(ResponsiveText, {
			MeasurementFont = Enum.Font.SourceSansBold,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.8),
				Text = if day.claimed then "✓" else tostring(day.day),
				TextColor3 = Color3.new(1, 1, 1),
			},
		}),
	})
end

return function(props: Props)
	local reducedMotion = useReducedMotion()
	local claimed, setClaimed = React.useState(false)
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

	React.useEffect(function()
		if props.Visible then
			setClaimed(false)
		end
	end, { props.Visible })

	if not props.Visible then
		return nil
	end

	local state = props.State
	if state == nil then
		return nil
	end

	local currentReward: { kind: string, amount: number?, itemId: string? }? = nil
	local currentDayNumber = state.nextDay
	for _, day in state.days do
		if day.current or day.available then
			currentReward = day.reward
			currentDayNumber = day.day
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

	return c("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = PANEL_NINE_SLICE,
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = styles.Rotation,
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(0.35, 0.45),
		SliceCenter = PANEL_SLICE_CENTER,
		SliceScale = PANEL_SLICE_SCALE,
	}, {
		ModalScale = c("UIScale", { Scale = styles.Scale }),
		Title = c(ResponsiveText, {
			HostName = "Title",
			MeasurementFont = Enum.Font.LuckiestGuy,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0.05),
				Size = UDim2.fromScale(0.9, 0.12),
				Text = "DAILY REWARD!",
				TextColor3 = AVAILABLE_GLOW,
				ZIndex = 2,
			},
		}),
		Divider = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.18),
			Size = UDim2.fromScale(0.8, 0.008),
		}),
		DayStrip = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.21),
			Size = UDim2.fromScale(0.85, 0.1),
		}, miniDays),
		RewardArea = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromScale(0.7, 0.25),
		}, {
			RewardScale = c("UIScale", { Scale = rewardStyles.Scale }),
			RewardDisplay = if currentReward and currentReward.kind == "Bonks"
				then c(BonksLabel, {
					Amount = currentReward.amount or 0,
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
				Text = streakText,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 2,
			},
		}),
		ActionButton = c(AnimatedButton, {
			Style = "Primary",
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Image = CLOSE_BUTTON_ASSET,
				ImageColor3 = if state.canClaim and not claimed then CLAIM_COLOR else Color3.new(1, 1, 1),
				Position = UDim2.fromScale(0.5, 0.92),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(0.5, 0.14),
				SliceCenter = Rect.new(198, 228, 841, 468),
				SliceScale = 0.2,
			},
			OnActivated = function()
				if state.canClaim and not claimed then
					setClaimed(true)
					if props.OnClaim then
						props.OnClaim()
					end
				else
					if props.OnClose then
						props.OnClose()
					end
				end
			end,
		}, {
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 4.35 }),
			TextLabel = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.54),
					Size = UDim2.fromScale(0.7, 0.6),
					Text = if state.canClaim and not claimed then "CLAIM!" else "AWESOME!",
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 2,
				},
			}),
		}),
	})
end
