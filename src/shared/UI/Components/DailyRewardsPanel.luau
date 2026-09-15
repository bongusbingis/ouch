--!strict
local T = require(script.Parent.Parent.Tokens)
-- Description: Responsive splash card summarizing the seven-day reward cycle and opening the daily reward modal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)
local NumberText = require(script.Parent.Parent.Models.NumberText)

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Palette = require(script.Parent.Parent.EconomyPalette)
local OuchPanel = require(script.Parent.CandyPanel)

local ScrollFrame = require(script.Parent.ScrollFrame)

local c = React.createElement

local DARK = Palette.Ink
local AVAILABLE_COLOR = Palette.Pink
local CLAIMED_SURFACE = Palette.Claimed
local LOCKED_SURFACE = Palette.White

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
	Summary: boolean?,
	Native: { [any]: any }?,
}

local function DayCell(dayProps: { Day: PublicDay, Order: number, Compact: boolean })
	local day = dayProps.Day
	local compact = dayProps.Compact
	local available = day.available
	local claimed = day.claimed and not available
	local backgroundColor = if claimed then CLAIMED_SURFACE elseif available then AVAILABLE_COLOR else LOCKED_SURFACE
	local foregroundColor = Palette.Ink
	local rewardColor = foregroundColor
	local strokeColor = if available then T.Colors.Yellow else Palette.Ink

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
			BackgroundTransparency = if claimed or available then 0 else 0.08,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.92, 0.88),
		}, {
			SizeLimit = c("UISizeConstraint", { MaxSize = Vector2.new(100000, 64) }),
			Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Tile) }),
			Stroke = c("UIStroke", {
				Color = strokeColor,
				Thickness = T.Shape.StrokeInner,
				Transparency = if claimed or available then 0 else 0.35,
			}),
			DayNumber = if claimed
				then c("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://168702841",
					ImageColor3 = Palette.Ink,
					Position = UDim2.fromScale(0.5, 0.27),
					Size = UDim2.fromScale(0.82, 0.34),
					ScaleType = Enum.ScaleType.Fit,
				})
				else c(ResponsiveText, {
					MeasurementFont = Enum.Font.FredokaOne,
					MinTextSize = if compact then 9 else 11,
					MaxTextSize = if compact then 14 else 20,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.5, 0.1),
						Size = UDim2.fromScale(0.9, 0.34),
						Text = if available then "TODAY" else `DAY {day.day}`,
						TextColor3 = foregroundColor,
						TextStrokeColor3 = DARK,
						TextStrokeTransparency = 1,
					},
				}),
			Reward = if day.reward.kind == "Bonks"
				then c(BonksLabel, {
					Framed = true,
					Amount = day.reward.amount or 0,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.7),
						Size = UDim2.fromScale(0.94, 0.38),
					},
					IconSize = UDim2.fromScale(0.2, 0.78),
					TextColor = rewardColor,
					TextStroke = 0,
				})
				else nil,
		}),
	})
end

return function(props: Props)
	local state = props.State
	local gridRef = React.useRef(nil)
	local scrollHint, setScrollHint = React.useState(nil :: string?)
	local scrollAvailable = state ~= nil and props.Summary ~= true
	React.useEffect(function()
		if not scrollAvailable then
			setScrollHint(nil)
			return
		end
		local grid = gridRef.current
		if not grid then
			return
		end
		local function updateHint()
			local window = grid.AbsoluteWindowSize.X
			local overflow = grid.AbsoluteCanvasSize.X - window
			setScrollHint(
				if window <= 0 or overflow <= 1
					then nil
					elseif overflow - grid.CanvasPosition.X > 1 then "SCROLL →"
					else "SCROLL ←"
			)
		end
		local connections = {}
		for _, property in { "AbsoluteCanvasSize", "AbsoluteWindowSize", "CanvasPosition" } do
			table.insert(connections, grid:GetPropertyChangedSignal(property):Connect(updateHint))
		end
		updateHint()
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { scrollAvailable })
	if state == nil then
		return nil
	end

	local compact = props.Compact == true
	local hint = if scrollAvailable then scrollHint else nil
	local headerHeight = 48
	local claimWidth = if compact then 72 else 88
	local summaryText = "VIEW DAILY REWARDS"
	if props.Summary then
		local currentDay = if state.canClaim then state.nextDay else state.currentDay
		for _, day in state.days do
			if day.day == currentDay then
				summaryText = if day.reward.kind == "Bonks"
					then `DAY {day.day} • {NumberText(day.reward.amount or 0)} BONKS`
					else `DAY {day.day} • REWARD`
				break
			end
		end
	end
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
		BackgroundColor3 = Palette.Panel,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
	}
	if props.Native then
		for key, value in props.Native do
			native[key] = value
		end
	end

	return c(OuchPanel, { Native = native, Padding = 0 }, {
		Header = c("Frame", {
			ZIndex = 2,
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.new(1, -UIConfig.Panel.InsetPx * 2, 0, headerHeight),
		}, {
			Title = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.FredokaOne,
				MinTextSize = 14,
				MaxTextSize = if compact then UIConfig.Text.LabelPx else UIConfig.Text.HeaderPx,
				Wrapped = compact,
				Native = {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = if hint then UDim2.fromOffset(0, 20) else UDim2.fromScale(0, 0.5),
					Size = if hint
						then UDim2.new(1, if props.OnClaim then -claimWidth - 16 else 0, 0, if compact then 40 else 32)
						else UDim2.new(
							1,
							if props.OnClaim then -claimWidth - 16 else 0,
							1,
							if compact then -8 else -16
						),
					Text = "DAILY REWARDS",
					TextWrapped = compact,
					TextColor3 = T.Colors.Ink,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextStrokeColor3 = DARK,
					TextStrokeTransparency = 1,
					ZIndex = 2,
				},
			}),
			ScrollHint = if hint
				then c("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 40),
					Size = UDim2.new(1, if props.OnClaim then -claimWidth - 16 else 0, 0, 14),
					Font = T.Type.Label,
					Text = hint,
					TextSize = 14,
					TextColor3 = T.Colors.Ink,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 2,
				})
				else nil,
			ClaimButton = if props.OnClaim ~= nil
				then c(ShopPriceButton, {
					Enabled = true,
					Color = if state.canClaim then Palette.Pink else Palette.Cyan,
					Compact = true,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -4, 0.5, 2),
					Size = UDim2.fromOffset(claimWidth, UIConfig.Interaction.MinTargetPx),
					Text = if state.canClaim then "CLAIM" else "VIEW",
					TextSize = if compact then 16 else 20,
					OnActivated = props.OnClaim,
					ZIndex = 2,
				})
				else nil,
		}),
		Summary = if props.Summary
			then c("Frame", {
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromOffset(12, 72),
				Size = UDim2.new(1, -24, 1, -76),
			}, {
				Text = c(ResponsiveText, {
					MeasurementFont = T.Type.Label,
					MinTextSize = 14,
					MaxTextSize = 18,
					Native = {
						BackgroundTransparency = 1,
						Font = T.Type.Label,
						Size = UDim2.new(1, 0, 0, 32),
						Text = summaryText,
						TextColor3 = T.Colors.Ink,
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				}),
			})
			else nil,
		DaysGrid = if not props.Summary
			then c(ScrollFrame, {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollRef = gridRef,
				Active = true,
				ClipsDescendants = true,
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				CanvasSize = UDim2.new(),
				ScrollingDirection = Enum.ScrollingDirection.X,
				ScrollBarThickness = if compact then 3 else 0,
				ScrollBarImageColor3 = Palette.Ink,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, headerHeight + 12),
				Size = UDim2.new(1, -32, 1, -headerHeight - 28),
			}, dayCells)
			else nil,
	})
end
