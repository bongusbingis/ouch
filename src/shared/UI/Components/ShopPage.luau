--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ActivityDots = require(script.Parent.ActivityDots)
local ResponsiveText = require(script.Parent.ResponsiveText)
local ShopCard = require(script.Parent.Shop.ShopCard)
local ShopCountdown = require(script.Parent.Shop.ShopCountdown)
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopSection = require(script.Parent.Shop.ShopSection)

local c = React.createElement

return function(props)
	local compact, setCompact = React.useState(false)
	local model = props.Model
	local heroHeight = if compact then 470 else 255
	local content = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = c("UIPadding", {
			PaddingBottom = UDim.new(0, 24),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 20),
		}),
	}
	if #model.hero > 0 then
		local heroChildren = {}
		for index, card in model.hero do
			local position
			local size
			if compact then
				position = UDim2.fromOffset(0, (index - 1) * 235)
				size = UDim2.new(1, 0, 0, 223)
			else
				position = if index == 1 then UDim2.fromScale(0, 0) else UDim2.fromScale(0.615, 0)
				size = if index == 1 then UDim2.fromScale(0.6, 1) else UDim2.fromScale(0.385, 1)
			end
			local expiresAt = if card.kind == "Bundle" then model.bundleExpireAt else model.featuredExpireAt
			heroChildren[card.id] = c("Frame", {
				BackgroundTransparency = 1,
				Position = position,
				Size = size,
			}, {
				Card = c(ShopCard, { Card = card, OnActivated = props.OnCardActivated }),
				Countdown = if expiresAt
					then c(ShopCountdown, {
						ExpiresAt = expiresAt,
						Position = UDim2.fromScale(0.66, 0.04),
						Size = UDim2.fromScale(0.28, 0.1),
						OnExpired = props.OnRefresh,
						ZIndex = 10,
					})
					else nil,
			})
		end
		content.Featured = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, heroHeight),
		}, heroChildren)
	end
	if model.status == "Loading" or model.status == "Idle" or model.status == "Error" then
		content.Status = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 130),
		}, {
			Text = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 36,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.1, 0.08),
					Size = UDim2.fromScale(0.8, 0.42),
					Text = if model.status == "Error" then "SHOP UNAVAILABLE" else "LOADING SHOP",
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 6,
				},
			}),
			Retry = if model.status == "Error"
				then c(ShopPriceButton, {
					Enabled = true,
					Position = UDim2.fromScale(0.5, 0.94),
					Size = UDim2.fromScale(0.3, 0.35),
					Text = "RETRY",
					OnActivated = props.OnRefresh,
				})
				else nil,
			Activity = if model.status ~= "Error"
				then c(ActivityDots, {
					Active = true,
					Native = {
						Position = UDim2.fromScale(0.5, 0.68),
						Size = UDim2.fromScale(0.1, 0.2),
						ZIndex = 6,
					},
				})
				else nil,
		})
	end
	for index, section in model.sections do
		content[section.id] = c(ShopSection, {
			Compact = compact,
			LayoutOrder = index + 1,
			Section = section,
			OnCardActivated = props.OnCardActivated,
			OnExpired = props.OnRefresh,
		})
	end

	return c("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://136021539696619",
		LayoutOrder = 5,
		Position = props.Position or UDim2.fromScale(-0.005, 0.127),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(0.602, 0.748),
		SliceCenter = Rect.new(224, 202, 770, 474),
		SliceScale = 0.06,
	}, {
		Title = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 62,
			Native = {
				BackgroundColor3 = Color3.fromRGB(63, 63, 63),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.291804, 0.0540634),
				Size = UDim2.fromScale(0.398251, 0.0898091),
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Text = "SHOP",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 5,
			},
		}),
		Bonks = c(ResponsiveText, {
			MeasurementFont = Enum.Font.LuckiestGuy,
			MaxTextSize = 36,
			Native = {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 211, 51),
				BorderSizePixel = 0,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.954, 0.1),
				Size = UDim2.fromScale(0.245, 0.078),
				Text = `{model.bonks} BONKS`,
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 5,
			},
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(0.25, 0) }),
			UIStroke = c("UIStroke", {
				Color = Color3.fromRGB(61, 61, 61),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.045,
			}),
		}),
		Main = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.575),
			Size = UDim2.fromScale(0.93, 0.78),
		}, {
			Content = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.fromOffset(0, 0),
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
				Position = UDim2.fromScale(0.025, 0),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarImageColor3 = Color3.new(1, 1, 1),
				ScrollBarImageTransparency = 0.1,
				ScrollBarThickness = if compact then 5 else 7,
				Size = UDim2.fromScale(0.95, 0.93),
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				[React.Change.AbsoluteSize] = function(instance)
					setCompact(instance.AbsoluteSize.X < 820)
				end,
			}, content),
		}),
		UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 1.08 }),
	})
end
