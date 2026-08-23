--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local ShopCard = require(script.Parent.ShopCard)
local ShopCountdown = require(script.Parent.ShopCountdown)

local c = React.createElement

return function(props)
	local section = props.Section
	local columns = props.Compact and 2 or 3
	local cardHeight = if props.Compact then 258 else 250
	local gutter = 12
	local rows = math.max(1, math.ceil(#section.cards / columns))
	local contentHeight = if #section.cards == 0 then 62 else rows * cardHeight + math.max(rows - 1, 0) * gutter
	local children = {}
	if #section.cards == 0 then
		children.Empty = c(ResponsiveText, {
			MeasurementFont = Enum.Font.SourceSansBold,
			MaxTextSize = 22,
			Native = {
				BackgroundColor3 = Color3.fromRGB(58, 58, 58),
				BackgroundTransparency = 0.42,
				FontFace = Font.new(
					"rbxasset://fonts/families/SourceSansPro.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Size = UDim2.new(1, 0, 0, 62),
				Text = "NEW ITEMS ARE ON THE WAY!",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 5,
			},
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(0.12, 0) }),
		})
	else
		children.UIGridLayout = c("UIGridLayout", {
			CellPadding = UDim2.fromOffset(gutter, gutter),
			CellSize = UDim2.new(1 / columns, -((columns - 1) * gutter / columns), 0, cardHeight),
			FillDirectionMaxCells = columns,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		for index, card in section.cards do
			children[card.id] = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = index,
				Size = UDim2.fromScale(1, 1),
			}, {
				Card = c(ShopCard, {
					Card = card,
					LayoutOrder = index,
					OnActivated = props.OnCardActivated,
				}),
			})
		end
	end

	return c("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
	}, {
		Header = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 54),
		}, {
			Title = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 32,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Size = UDim2.new(0.68, 0, 0, 38),
					Text = section.title,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
				},
			}, {
				UIStroke = c("UIStroke", {
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.055,
				}),
			}),
			Countdown = if section.countdownAt
				then c(ShopCountdown, {
					ExpiresAt = section.countdownAt,
					Position = UDim2.fromScale(0.7, 0),
					Size = UDim2.new(0.3, 0, 0, 38),
					OnExpired = props.OnExpired,
				})
				else nil,
			Divider = c("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.18,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 42),
				Size = UDim2.new(1, 0, 0, 3),
				ZIndex = 6,
			}),
		}),
		Content = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, contentHeight),
		}, children),
		Spacer = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 22),
		}),
		UIListLayout = c("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end
