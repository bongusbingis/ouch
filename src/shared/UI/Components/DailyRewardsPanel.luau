-- Name: DailyRewardsPanel.luau
-- Author: Jack C.
-- Description: Responsive splash card summarizing the seven-day reward cycle and opening the daily reward modal.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)

local c = React.createElement

local PANEL_NINE_SLICE = "rbxassetid://124751224634629"
local PANEL_SLICE_CENTER = Rect.new(31, 41, 978, 620)
local CLAIM_BUTTON_ASSET = "rbxassetid://94748581468730"

local DARK = Color3.fromRGB(24, 41, 48)
local CLAIM_COLOR = Color3.fromRGB(154, 233, 91)
local AVAILABLE_COLOR = Color3.fromRGB(255, 211, 51)
local CLAIMED_SURFACE = Color3.fromRGB(39, 78, 90)
local LOCKED_SURFACE = Color3.fromRGB(23, 88, 105)

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
	State: PublicState?,
	OnClaim: (() -> ())?,
	Compact: boolean?,
	Native: { [any]: any }?,
}

local function DayCell(dayProps: { Day: PublicDay, Order: number, Compact: boolean })
	local day = dayProps.Day
	local compact = dayProps.Compact
	local available = day.available and not day.claimed
	local backgroundColor = if day.claimed then CLAIMED_SURFACE elseif available then AVAILABLE_COLOR else LOCKED_SURFACE
	local foregroundColor = if available then DARK else Color3.new(1, 1, 1)
	local rewardColor = if available then DARK elseif day.claimed then Color3.fromRGB(188, 207, 212) else AVAILABLE_COLOR
	local strokeColor = if day.claimed then CLAIM_COLOR elseif available then AVAILABLE_COLOR else Color3.new(1, 1, 1)

	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = dayProps.Order,
		Size = UDim2.fromScale(1 / 7 - 0.009, 1),
	}, {
		Background = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = if available then 0 else 0.08,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.94, 0.92),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.14, 0) }),
			Stroke = c("UIStroke", {
				Color = strokeColor,
				Thickness = if available then 2 else 1,
				Transparency = if day.claimed or available then 0.15 else 0.62,
			}),
			DayNumber = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MinTextSize = if compact then 9 else 11,
				MaxTextSize = if compact then 14 else 20,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, if compact then 0.05 else 0.08),
					Size = UDim2.fromScale(0.9, if compact then 0.38 else 0.24),
					Text = if compact then `D{day.day}` else `DAY {day.day}`,
					TextColor3 = foregroundColor,
				},
			}),
			Reward = if day.reward.kind == "Bonks"
				then c(BonksLabel, {
					Amount = day.reward.amount or 0,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, if compact then 0.7 else 0.57),
						Size = UDim2.fromScale(0.94, if compact then 0.48 else 0.35),
					},
					IconSize = UDim2.fromScale(if compact then 0.3 else 0.27, 0.78),
					TextColor = rewardColor,
				})
				else nil,
			Status = if not compact and (day.claimed or available)
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					MinTextSize = 10,
					MaxTextSize = 15,
					Native = {
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
						Position = UDim2.fromScale(0.5, 0.94),
						Size = UDim2.fromScale(0.9, 0.18),
						Text = if day.claimed then "CLAIMED" else "TODAY",
						TextColor3 = if day.claimed then CLAIM_COLOR else DARK,
					},
				})
				else nil,
		}),
	})
end

return function(props: Props)
	local state = props.State
	if state == nil then
		return nil
	end

	local compact = props.Compact == true
	local dayCells = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.006, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for index, day in state.days do
		dayCells[`Day{index}`] = c(DayCell, {
			Day = day,
			Order = index,
			Compact = compact,
		})
	end

	local native = {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Image = PANEL_NINE_SLICE,
		Position = UDim2.fromScale(0, 0),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(1, 1),
		SliceCenter = PANEL_SLICE_CENTER,
		SliceScale = if compact then 0.35 else 0.5,
	}
	if props.Native then
		for key, value in props.Native do
			native[key] = value
		end
	end

	return c("ImageLabel", native, {
		Header = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, if compact then 0.04 else 0.06),
			Size = UDim2.fromScale(if compact then 0.94 else 0.9, if compact then 0.28 else 0.22),
		}, {
			Title = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				MinTextSize = if compact then 10 else 14,
				MaxTextSize = if compact then 19 else 32,
				Native = {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromScale(if state.canClaim then 0.67 else 1, 0.95),
					Text = "DAILY REWARDS",
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextStrokeColor3 = DARK,
					TextStrokeTransparency = 0.72,
					ZIndex = 2,
				},
			}),
			ClaimButton = if state.canClaim
				then c(AnimatedButton, {
					Style = "Primary",
					Native = {
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						Image = CLAIM_BUTTON_ASSET,
						ImageColor3 = CLAIM_COLOR,
						Position = UDim2.fromScale(1, 0.5),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromScale(0.29, 0.9),
						SliceCenter = Rect.new(198, 228, 841, 468),
						SliceScale = 0.2,
					},
					OnActivated = props.OnClaim,
				}, {
					Aspect = c("UIAspectRatioConstraint", { AspectRatio = 4.35 }),
					TextLabel = c(ResponsiveText, {
						MeasurementFont = Enum.Font.LuckiestGuy,
						MinTextSize = if compact then 9 else 12,
						MaxTextSize = if compact then 15 else 22,
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
							Position = UDim2.fromScale(0.5, 0.54),
							Size = UDim2.fromScale(0.76, 0.58),
							Text = "CLAIM",
							TextColor3 = Color3.new(1, 1, 1),
							ZIndex = 2,
						},
					}),
				})
				else nil,
		}),
		DaysGrid = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, if compact then 0.67 else 0.66),
			Size = UDim2.fromScale(if compact then 0.96 else 0.92, if compact then 0.58 else 0.62),
		}, dayCells),
	})
end
