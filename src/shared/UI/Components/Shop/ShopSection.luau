-- Description: One category block in the storefront dashboard: a compact label, its rotation countdown, and the card grid the resolved layout gives its column.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local SectionHeader = require(script.Parent.Parent.SectionHeader)
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
	local countdownWidth = if props.Width < 250 then 86 else 98
	local children = {}
	if #section.cards == 0 then
		children.Empty = c(ResponsiveText, {
			HostName = "Empty",
			MeasurementFont = UIConfig.Text.BodyFont,
			MaxTextSize = 20,
			Native = {
				BackgroundColor3 = UIConfig.ProgressionStyle.Claimed,
				BackgroundTransparency = 0,
				Font = UIConfig.Text.BodyFont,
				Size = UDim2.fromScale(1, 1),
				Text = "NO OFFERS AVAILABLE",
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeColor3 = UIConfig.ProgressionStyle.Ink,
				TextStrokeTransparency = 0.35,
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
				CardWidth = grid.cardWidth,
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
		Header = c(SectionHeader, {
			Text = section.title,
			TextSize = ShopUI.HeaderTextSize,
			HeightPx = ShopUI.HeaderHeightPx,
			LayoutOrder = 1,
			ZIndex = 5,
			Accessory = if countdownAt
				then c(ShopCountdown, {
					ExpiresAt = countdownAt,
					MaxTextSize = 18,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(countdownWidth, 26),
					OnExpired = props.OnExpired,
				})
				else nil,
			AccessoryWidthPx = countdownWidth,
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
