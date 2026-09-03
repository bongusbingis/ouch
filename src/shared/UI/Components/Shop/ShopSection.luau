-- Name: ShopSection.luau
-- Author: Jack C.
-- Description: One category block in the storefront dashboard: a compact label, its rotation countdown, and the card grid the resolved layout gives its column.
-- Created: 2026-08-23

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local ShopCard = require(script.Parent.ShopCard)
local ShopCountdown = require(script.Parent.ShopCountdown)

local c = React.createElement

local ShopUI = UIConfig.Layout.Shop

export type Props = {
	Section: any,
	Class: any,
	Grid: any,
	Position: UDim2,
	Width: number,
	Height: number,
	LayoutOrder: number?,
	OnCardActivated: (any) -> (),
	OnExpired: (() -> ())?,
}

return function(props: Props)
	local section = props.Section
	local grid = props.Grid
	local countdownAt = section.countdownAt
	local children = {}
	if #section.cards == 0 then
		children.Empty = c(ResponsiveText, {
			HostName = "Empty",
			MeasurementFont = Enum.Font.SourceSansBold,
			MaxTextSize = 20,
			Native = {
				BackgroundColor3 = Color3.fromRGB(58, 58, 58),
				BackgroundTransparency = 0.42,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Size = UDim2.fromScale(1, 1),
				Text = "NEW ITEMS ARE ON THE WAY!",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 5,
			},
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(0.16, 0) }),
		})
	else
		children.UIGridLayout = c("UIGridLayout", {
			CellPadding = UDim2.fromOffset(ShopUI.CardGapPx, ShopUI.CardGapPx),
			CellSize = UDim2.fromOffset(grid.cardWidth, grid.cardHeight),
			FillDirectionMaxCells = grid.columns,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		for index, card in section.cards do
			children[card.id] = c(ShopCard, {
				Card = card,
				CardHeight = grid.cardHeight,
				Class = props.Class,
				LayoutOrder = index,
				OnActivated = props.OnCardActivated,
			})
		end
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = UDim2.fromOffset(props.Width, props.Height),
	}, {
		-- A section label, not a second page title: it names the block and gets
		-- out of the way of the cards underneath it.
		Header = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, ShopUI.HeaderHeightPx),
		}, {
			Title = c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = ShopUI.HeaderTextSize,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Size = UDim2.new(if countdownAt then 0.62 else 1, 0, 0, ShopUI.HeaderHeightPx - 6),
					Text = section.title,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
				},
			}, {
				UIStroke = c("UIStroke", {
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.06,
				}),
			}),
			Countdown = if countdownAt
				then c(ShopCountdown, {
					ExpiresAt = countdownAt,
					MaxTextSize = ShopUI.HeaderTextSize - 4,
					Position = UDim2.fromScale(0.64, 0),
					Size = UDim2.new(0.36, 0, 0, ShopUI.HeaderHeightPx - 6),
					OnExpired = props.OnExpired,
				})
				else nil,
		}),
		Content = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 1, -ShopUI.HeaderHeightPx),
		}, children),
		UIListLayout = c("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end
