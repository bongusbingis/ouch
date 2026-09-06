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

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Palette = UIConfig.ProgressionStyle

local c = React.createElement

local CHECK_ICON_ASSET = "rbxassetid://505845268"

local DARK = Palette.Ink
local CLAIM_COLOR = Palette.Green
local AVAILABLE_COLOR = Palette.Yellow
local CLAIMED_SURFACE = Palette.Raised
local LOCKED_SURFACE = Palette.Ink

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
	local available = day.available
	local claimed = day.claimed and not available
	local backgroundColor = if claimed then CLAIMED_SURFACE elseif available then AVAILABLE_COLOR else LOCKED_SURFACE
	local foregroundColor = if available then DARK else Color3.new(1, 1, 1)
	local rewardColor = if available then DARK elseif claimed then Palette.Muted else AVAILABLE_COLOR
	local strokeColor = if claimed then CLAIM_COLOR elseif available then AVAILABLE_COLOR else Color3.new(1, 1, 1)

	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = dayProps.Order,
		Size = if compact
			then UDim2.new(0, UIConfig.Layout.DailyCell.MinWidthPx, 1, -4)
			else UDim2.fromScale(1 / 7 - 0.009, 1),
	}, {
		Background = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = if available then 0 else 0.08,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = if available then -3 else 0,
			Size = UDim2.fromScale(0.92, if available then 0.96 else 0.88),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.14, 0) }),
			Stroke = c("UIStroke", {
				Color = strokeColor,
				Thickness = if available then 3 else 1,
				Transparency = if claimed or available then 0 else 0.72,
			}),
			DayNumber = if compact and claimed
				then c("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Image = CHECK_ICON_ASSET,
					Position = UDim2.fromScale(0.5, 0.05),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.9, 0.38),
				})
				else c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					MinTextSize = if compact then 9 else 11,
					MaxTextSize = if compact then 14 else 20,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.5, if compact then 0.05 else 0.08),
						Size = UDim2.fromScale(0.9, if compact then 0.38 else 0.24),
						Text = if compact and available then "NOW" else `DAY {day.day}`,
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
					IconSize = UDim2.fromScale(0.2, 0.78),
					TextColor = rewardColor,
				})
				else nil,
			Status = if not compact and (claimed or available)
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
						Text = if claimed then "CLAIMED" else "TODAY",
						TextColor3 = if claimed then CLAIM_COLOR else DARK,
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
			HorizontalAlignment = if compact then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center,
			Padding = if compact then UDim.new(0, 4) else UDim.new(0.006, 0),
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
		BackgroundTransparency = 0,
		BackgroundColor3 = Palette.Surface,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
	}
	if props.Native then
		for key, value in props.Native do
			native[key] = value
		end
	end

	return c("Frame", native, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Outline = c("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }),
		HeaderBand = c("Frame", {
			BackgroundColor3 = Palette.Yellow,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 44),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
		}),
		Header = c("Frame", {
			ZIndex = 2,
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.new(1, -24, 0, 44),
		}, {
			Title = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				MinTextSize = if compact then 10 else 14,
				MaxTextSize = if compact then 20 else 26,
				Native = {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.new(1, if props.OnClaim then -100 else 0, 1, -8),
					Text = "DAILY REWARDS",
					TextColor3 = DARK,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextStrokeColor3 = DARK,
					TextStrokeTransparency = 1,
					ZIndex = 2,
				},
			}),
			ClaimButton = if props.OnClaim ~= nil
				then c(AnimatedButton, {
					Style = "Primary",
					Enabled = props.OnClaim ~= nil,
					Native = {
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 0,
						BackgroundColor3 = CLAIM_COLOR,
						Image = "",
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(92, 44),
					},
					OnActivated = props.OnClaim,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = c("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }),
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
							Text = "VIEW",
							TextColor3 = Color3.new(1, 1, 1),
							ZIndex = 2,
						},
					}),
				})
				else nil,
		}),
		DaysGrid = c("ScrollingFrame", {
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = if compact then 3 else 0,
			ScrollBarImageColor3 = Palette.Yellow,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, 26),
			Size = UDim2.new(1, -16, 1, -58),
		}, dayCells),
	})
end
