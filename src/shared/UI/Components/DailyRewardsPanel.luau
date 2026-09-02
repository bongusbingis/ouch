-- Name: DailyRewardsPanel.luau
-- Author: Jack C.
-- Description: Splash screen panel showing the 7-day daily reward cycle with claimed/available/locked states and a claim button that opens the reward modal.
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
local LOCKED_TRANSPARENCY = 0.45

local CLAIM_BUTTON_ASSET = "rbxassetid://94748581468730"

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
}

local function DayCell(dayProps: { Day: PublicDay, Order: number })
	local day = dayProps.Day
	local reducedMotion = useReducedMotion()
	local glowStyles = ReactSpring.useSpring({
		from = { Scale = 1 },
		to = if day.available and not day.claimed then { Scale = 1.08 } else { Scale = 1 },
		config = Motion.Pop,
		loop = if day.available and not day.claimed then true else false,
		immediate = reducedMotion,
	})

	local borderColor = if day.claimed
		then CLAIMED_COLOR
		elseif day.available then AVAILABLE_GLOW
		else Color3.new(1, 1, 1)
	local transparency = if day.claimed then 0.3 elseif not day.available then LOCKED_TRANSPARENCY else 0

	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = dayProps.Order,
		Size = UDim2.fromScale(1 / 7 - 0.01, 1),
	}, {
		CellScale = if day.available and not day.claimed
			then c("UIScale", { Scale = glowStyles.Scale })
			else nil,
		Background = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = borderColor,
			BackgroundTransparency = transparency,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.92, 0.95),
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(0.15, 0) }),
			UIStroke = if day.available and not day.claimed
				then c("UIStroke", {
					Color = AVAILABLE_GLOW,
					Thickness = 2,
					Transparency = 0.2,
				})
				else nil,
			DayNumber = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.06),
					Size = UDim2.fromScale(0.9, 0.25),
					Text = `DAY {day.day}`,
					TextColor3 = Color3.new(1, 1, 1),
				},
			}),
			Reward = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.58),
				Size = UDim2.fromScale(0.9, 0.4),
			}, {
				BonksLabel = if day.reward.kind == "Bonks"
					then c(BonksLabel, {
						Amount = day.reward.amount or 0,
						IconSize = UDim2.fromScale(0.35, 0.7),
					})
					else nil,
			}),
			Checkmark = if day.claimed
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					Native = {
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.5, 0.95),
						Size = UDim2.fromScale(0.6, 0.2),
						Text = "✓",
						TextColor3 = CLAIM_COLOR,
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

	local dayCells = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.005, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, day in state.days do
		dayCells[`Day{index}`] = c(DayCell, { Day = day, Order = index })
	end

	return c("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Image = PANEL_NINE_SLICE,
		Position = UDim2.fromScale(0.015, 0.44),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(0.32, 0.35),
		SliceCenter = PANEL_SLICE_CENTER,
		SliceScale = PANEL_SLICE_SCALE,
	}, {
		UIPadding = c("UIPadding", {
			PaddingTop = UDim.new(0.04, 0),
			PaddingBottom = UDim.new(0.04, 0),
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.03, 0),
		}),
		Title = c(ResponsiveText, {
			HostName = "Title",
			MeasurementFont = Enum.Font.LuckiestGuy,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.9, 0.15),
				Text = "DAILY REWARDS",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 2,
			},
		}),
		DaysGrid = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.55),
		}, dayCells),
		ClaimButton = if state.canClaim
			then c(AnimatedButton, {
				Style = "Primary",
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					Image = CLAIM_BUTTON_ASSET,
					ImageColor3 = CLAIM_COLOR,
					Position = UDim2.fromScale(0.5, 1),
					ScaleType = Enum.ScaleType.Slice,
					Size = UDim2.fromScale(0.5, 0.2),
					SliceCenter = Rect.new(198, 228, 841, 468),
					SliceScale = 0.2,
				},
				OnActivated = props.OnClaim,
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
						Text = "CLAIM",
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 2,
					},
				}),
			})
			else nil,
	})
end
