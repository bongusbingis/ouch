-- Name: ShopDetailsModal.luau
-- Author: Jack C.
-- Description: Modal showing the full detail for one offer, including crate contents, disclosed odds, and pity information, with the purchase action.
-- Created: 2026-08-23

--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ReactSpring = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react-spring"))
local Motion = require(script.Parent.Parent.Motion)
local InventoryConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Inventory"))
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveText = require(script.Parent.ResponsiveText)
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)

local c = React.createElement

local function pityText(pity: { [string]: number }?): string
	if pity == nil then
		return ""
	end
	local names = {}
	for rarity in pity do
		table.insert(names, rarity)
	end
	table.sort(names)
	local entries = {}
	for _, rarity in names do
		table.insert(entries, `{string.upper(rarity)} GUARANTEED BY {pity[rarity]} OPENS`)
	end
	return table.concat(entries, "  •  ")
end

return function(props)
	local card = props.Card
	local reducedMotion = useReducedMotion()
	local firstButtonRef = React.useRef(nil)
	local previousSelection = React.useRef(nil)
	local styles = ReactSpring.useSpring({
		Scale = if card then 1 else 0.82,
		Rotation = if card then 0 else -2,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	React.useEffect(function()
		if card then
			previousSelection.current = GuiService.SelectedObject
			task.defer(function()
				local button = firstButtonRef.current
				if button and button.Parent and button.Selectable then
					GuiService.SelectedObject = button
				end
			end)
		else
			local previous = previousSelection.current
			previousSelection.current = nil
			if previous and previous.Parent and previous.Visible and previous.Selectable then
				GuiService.SelectedObject = previous
			end
		end
	end, { card })
	if card == nil then
		return nil
	end

	local oddsChildren = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, outcome in card.odds or {} do
		oddsChildren[outcome.itemId] = c("Frame", {
			BackgroundColor3 = InventoryConfig.RarityColors[outcome.rarity] or Color3.new(1, 1, 1),
			BackgroundTransparency = 0.2,
			LayoutOrder = index,
			Size = UDim2.new(1, -6, 0, 27),
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(0.2, 0) }),
			Name = c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = 22,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.03, 0),
					Size = UDim2.fromScale(0.68, 1),
					Text = string.upper(outcome.displayName),
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 104,
				},
			}),
			Chance = c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = 22,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.72, 0),
					Size = UDim2.fromScale(0.25, 1),
					Text = `{outcome.percent}%`,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 104,
				},
			}),
		})
	end

	local hasBonks = card.bonksPrice ~= nil
	local hasRobux = card.productId ~= nil and card.robuxPrice ~= nil
	local bonksText = if card.affordable then `{card.bonksPrice} BONKS` else `NEED {card.bonksPrice} BONKS`
	return c("Frame", {
		Active = true,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 101,
	}, {
		Panel = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://124751224634629",
			Position = UDim2.fromScale(0.5, 0.53),
			Rotation = styles.Rotation,
			ScaleType = Enum.ScaleType.Slice,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			Size = UDim2.fromScale(0.62, 0.68),
			SliceCenter = Rect.new(31, 41, 978, 620),
			SliceScale = 0.5,
			ZIndex = 102,
		}, {
			ModalScale = c("UIScale", { Scale = styles.Scale }),
			Title = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 54,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.045),
					Size = UDim2.fromScale(0.82, 0.1),
					Text = string.upper(card.displayName),
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 104,
				},
			}),
			Preview = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.055, 0.17),
				Size = UDim2.fromScale(0.38, 0.5),
				ZIndex = 103,
			}, {
				Content = c(ShopPreview, {
					Items = card.previewItems,
					Thumbnail = card.thumbnail,
					ZIndex = 103,
				}),
			}),
			Description = c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = 27,
				Wrapped = true,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.46, 0.17),
					Size = UDim2.fromScale(0.48, 0.14),
					Text = string.upper(card.description),
					TextColor3 = Color3.new(1, 1, 1),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					ZIndex = 104,
				},
			}),
			Odds = if card.odds
				then c("ScrollingFrame", {
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.fromOffset(0, 0),
					Position = UDim2.fromScale(0.46, 0.33),
					ScrollBarImageColor3 = Color3.new(1, 1, 1),
					Size = UDim2.fromScale(0.48, 0.32),
					ZIndex = 103,
				}, oddsChildren)
				else nil,
			Pity = if card.pity
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					MaxTextSize = 20,
					Wrapped = true,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/SourceSansPro.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.46, 0.66),
						Size = UDim2.fromScale(0.48, 0.08),
						Text = pityText(card.pity),
						TextColor3 = Color3.fromRGB(255, 235, 130),
						TextWrapped = true,
						ZIndex = 104,
					},
				})
				else nil,
			Close = c(ShopPriceButton, {
				Enabled = true,
				Position = UDim2.fromScale(0.9, 0.16),
				Size = UDim2.fromScale(0.16, 0.08),
				Text = "BACK",
				OnActivated = props.OnClose,
				ZIndex = 105,
			}),
			Buttons = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.08, 0.77),
				Size = UDim2.fromScale(0.84, 0.17),
				ZIndex = 103,
			}, {
				Bonks = if hasBonks
					then c(ShopPriceButton, {
						ButtonRef = firstButtonRef,
						Enabled = card.affordable and not card.pending,
						Position = if hasRobux then UDim2.fromScale(0.25, 1) else UDim2.fromScale(0.38, 1),
						Size = if hasRobux then UDim2.fromScale(0.44, 0.72) else UDim2.fromScale(0.58, 0.72),
						Text = bonksText,
						OnActivated = props.OnPurchaseBonks,
						ZIndex = 104,
					})
					else nil,
				Robux = if hasRobux
					then c(ShopPriceButton, {
						ButtonRef = if hasBonks then nil else firstButtonRef,
						Enabled = not card.pending,
						Position = UDim2.fromScale(0.75, 1),
						Size = UDim2.fromScale(0.44, 0.72),
						Text = `R$ {card.robuxPrice}`,
						OnActivated = props.OnPurchaseRobux,
						ZIndex = 104,
					})
					else nil,
			}),
		}),
	})
end
