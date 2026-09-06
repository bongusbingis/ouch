-- Offer details, interactive reward previews, and player-specific crate odds.
-- Purchase actions and profile state remain owned by the economy controller.
--!strict

local formatNumber = require(script.Parent.Parent.Models.NumberText)

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ReactSpring = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage.Config.Interface.UI)
local InventoryConfig = require(ReplicatedStorage.Config.Cosmetics.Inventory)
local ShopConfig = require(ReplicatedStorage.Config.Economy.Shop)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local ResponsiveText = require(script.Parent.ResponsiveText)
local AnimatedButton = require(script.Parent.AnimatedButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local c = React.createElement
local colors = UIConfig.ProgressionStyle

local function label(text, position, size, maxSize, color, heading, alignment, wrapped)
	return c(ResponsiveText, {
		MeasurementFont = if heading then Enum.Font.LuckiestGuy else Enum.Font.SourceSansBold,
		MaxTextSize = maxSize,
		Wrapped = wrapped,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = if heading then Enum.Font.LuckiestGuy else Enum.Font.SourceSansBold,
			Text = text,
			TextWrapped = wrapped,
			TextColor3 = color or Color3.new(1, 1, 1),
			TextXAlignment = alignment or Enum.TextXAlignment.Left,
			ZIndex = 105,
		},
	})
end

local function guaranteeText(card)
	local remaining = card.pityRemaining or card.pity or {}
	local entries = {}
	for _, rarity in { "Rare", "Legendary" } do
		local count = remaining[rarity]
		if count then
			local name = if rarity == "Rare" then "Rare+" else "Legendary"
			table.insert(
				entries,
				if count == 1 then name .. " NEXT OPEN" else string.format("%s within %d opens", name, count)
			)
		end
	end
	return table.concat(entries, "  •  ")
end

return function(props)
	local safe = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safe.size, UIConfig.Layout.PortraitMaxAspect)
	local size = ResponsiveLayout.panelSize(
		safe.size,
		UIConfig.Layout.Panels.ShopDetails,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local card = props.Card
	local selectedId, setSelectedId = React.useState(nil)
	local firstRef, robuxRef, closeRef = React.useRef(nil), React.useRef(nil), React.useRef(nil)
	local panelRef = React.useRef(nil)
	local reducedMotion = useReducedMotion()
	local styles = ReactSpring.useSpring({
		Scale = if card then 1 else 0.9,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
	React.useEffect(function()
		setSelectedId(nil)
	end, { if card then card.id else "" })
	React.useEffect(function()
		if card == nil then
			return
		end
		local previous = GuiService.SelectedObject
		return function()
			if previous and previous.Parent and previous.Visible and previous.Selectable then
				GuiService.SelectedObject = previous
			end
		end
	end, { card ~= nil })
	React.useEffect(function()
		if card == nil or props.FocusEnabled == false then
			return
		end
		local active = true
		local queued = false
		local function focus()
			queued = false
			if not active then
				return
			end
			local selected = GuiService.SelectedObject
			local panel = panelRef.current
			local ancestor: Instance? = panel
			while ancestor do
				if ancestor:IsA("GuiObject") and not ancestor.Visible then
					return
				end
				ancestor = ancestor.Parent
			end
			local ownRoot = if panel then panel:FindFirstAncestorWhichIsA("ScreenGui") else nil
			local selectedRoot = if selected then selected:FindFirstAncestorWhichIsA("ScreenGui") else nil
			if
				ownRoot and (not ownRoot.Enabled or (selectedRoot and selectedRoot.DisplayOrder > ownRoot.DisplayOrder))
			then
				return
			end
			if selected and selected.Selectable and panelRef.current and selected:IsDescendantOf(panelRef.current) then
				return
			end
			for _, reference in { firstRef, robuxRef, closeRef } do
				local button = reference.current
				if button and button.Parent and button.Visible and button.Selectable then
					GuiService.SelectedObject = button
					break
				end
			end
		end
		local connection = GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
			if not queued then
				queued = true
				task.delay(0, focus)
			end
		end)
		task.defer(focus)
		return function()
			active = false
			connection:Disconnect()
		end
	end, { card, props.FocusEnabled })
	if card == nil then
		return nil
	end

	local isCrate = card.kind == "Crate"
	local isEmoteCollection = card.kind == "GamePass"
		and card.previewItems[1] ~= nil
		and card.previewItems[1].category == "EmoteAssets"
	local short = not portrait and size.Y < 420
	local hasBonks = card.bonksPrice ~= nil
	local hasRobux = (card.productId ~= nil or card.passId ~= nil) and card.robuxPrice ~= nil
	local quantities = if isCrate and hasBonks then card.openQuantities or { 1 } else if hasBonks then { 1 } else {}
	local slots = #quantities + (if hasRobux then 1 else 0)
	local columns = if portrait then math.min(2, math.max(1, slots)) else math.max(1, slots)
	local rows = math.max(1, math.ceil(slots / columns))
	local buttonHeight = if short then 48 else if portrait then 54 else 60
	local footerCopyHeight = if isCrate then (if short then 23 else 45) else 12
	local footerHeight = rows * (buttonHeight + 6) + footerCopyHeight
	local inset = if short then 12 else 16
	local bodyTop = if short then 52 else 64
	local bodyHeight = size.Y - bodyTop - footerHeight - inset
	local previewHeight = if portrait then math.min(120, bodyHeight * 0.31) else bodyHeight
	local listTop = if portrait then previewHeight + 8 else 0
	local listX = if portrait then 0 else 0.35
	local listWidth = if portrait then 1 else 0.65
	local selected = nil
	for _, outcome in card.odds or {} do
		if outcome.itemId == selectedId then
			selected = outcome
			break
		end
	end
	if isEmoteCollection then
		local entry = card.previewItems[1]
		for _, item in card.previewItems do
			if item.itemId == selectedId then
				entry = item
				break
			end
		end
		selected = { displayName = entry.definition.DisplayName, preview = entry }
	end
	local styleButtons = {}
	if isEmoteCollection then
		styleButtons.Layout = c("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		for index, item in card.previewItems do
			styleButtons[item.itemId] = c(AnimatedButton, {
				Enabled = true,
				OnActivated = function()
					setSelectedId(item.itemId)
				end,
				Native = {
					BackgroundColor3 = if selected.preview.itemId == item.itemId then colors.Surface else colors.Ink,
					BorderSizePixel = 0,
					Size = UDim2.new(1, -8, 0, 44),
					LayoutOrder = index,
					ZIndex = 104,
				},
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Name = label(
					item.definition.DisplayName,
					UDim2.fromOffset(12, 0),
					UDim2.new(1, -24, 1, 0),
					23,
					if selected.preview.itemId == item.itemId then colors.Yellow else nil,
					true
				),
			})
		end
	end
	local previews = if selected and selected.preview then { selected.preview } else card.previewItems
	local contents = {
		Layout = c(
			"UIListLayout",
			{ Padding = UDim.new(0, if short then 4 else 6), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Padding = c(
			"UIPadding",
			{ PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 8) }
		),
	}
	local lastRarity = nil
	for index, outcome in card.odds or {} do
		local rarityColor = InventoryConfig.RarityColors[outcome.rarity] or colors.Cyan
		if lastRarity ~= outcome.rarity then
			contents["Rarity" .. outcome.rarity] = c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, if short then 18 else 24),
				LayoutOrder = index * 2,
			}, {
				Name = label(
					string.upper(outcome.rarity),
					UDim2.fromOffset(4, 0),
					UDim2.fromScale(1, 1),
					19,
					rarityColor,
					true
				),
			})
			lastRarity = outcome.rarity
		end
		local chosen = selectedId == outcome.itemId
		local refund = if outcome.owned
			then `OWNED  •  +{formatNumber(outcome.bonksRefund or 0)} Bonks`
			else `Repeat reward: +{formatNumber(outcome.bonksRefund or 0)} Bonks`
		contents[outcome.itemId] = c(AnimatedButton, {
			Enabled = true,
			OnActivated = function()
				setSelectedId(outcome.itemId)
			end,
			Native = {
				BackgroundColor3 = if chosen then colors.Surface else colors.Ink,
				BackgroundTransparency = if chosen then 0 else 0.25,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, if short then 44 else 50),
				LayoutOrder = index * 2 + 1,
				ZIndex = 104,
			},
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Accent = c("Frame", {
				BackgroundColor3 = rarityColor,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 4, 1, -12),
				Position = UDim2.fromOffset(0, 6),
				ZIndex = 105,
			}),
			Name = label(
				outcome.displayName,
				UDim2.fromOffset(12, 3),
				UDim2.new(1, -94, 0, if short then 20 else 24),
				20,
				nil,
				false
			),
			Refund = label(
				refund,
				UDim2.fromOffset(12, if short then 23 else 27),
				UDim2.new(1, -94, 0, 18),
				14,
				colors.Muted,
				false
			),
			Chance = label(
				tostring(outcome.percent) .. "%",
				UDim2.new(1, -80, 0, 3),
				UDim2.fromOffset(70, 24),
				21,
				colors.Yellow,
				false,
				Enum.TextXAlignment.Right
			),
			BaseChance = if outcome.basePercent and outcome.basePercent ~= outcome.percent
				then label(
					"Base " .. outcome.basePercent .. "%",
					UDim2.new(1, -80, 0, if short then 23 else 27),
					UDim2.fromOffset(70, 18),
					13,
					colors.Muted,
					false,
					Enum.TextXAlignment.Right
				)
				else nil,
		})
	end

	local buttons = {}
	local function position(index)
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		return UDim2.new((column + 0.5) / columns, 0, 0, row * (buttonHeight + 6) + buttonHeight)
	end
	for index, quantity in quantities do
		local amount = card.bonksPrice * quantity
		buttons["Open" .. quantity] = c(ShopPriceButton, {
			ButtonRef = if index == 1 then firstRef else nil,
			Enabled = card.status == "Active"
				and (card.bonksAvailable or (if card.affordable then amount else 0)) >= amount
				and not card.pending,
			Position = position(index),
			Size = UDim2.new(1 / columns, -8, 0, buttonHeight),
			Text = if isCrate then "OPEN " .. quantity else "GET ITEM",
			SubBonks = amount,
			OnActivated = function()
				props.OnPurchaseBonks(quantity)
			end,
			ZIndex = 105,
		})
	end
	if hasRobux then
		buttons.Robux = c(ShopPriceButton, {
			ButtonRef = robuxRef,
			Enabled = card.status == "Active" and not card.pending,
			Red = true,
			Position = position(slots),
			Size = UDim2.new(1 / columns, -8, 0, buttonHeight),
			Text = if isCrate then "OPEN 1" else if card.passId then "GET PASS" else "GET ITEM",
			SubText = ShopConfig.RobuxSymbol .. formatNumber(card.robuxPrice),
			OnActivated = props.OnPurchaseRobux,
			ZIndex = 105,
		})
	end

	return c("TextButton", {
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		Active = true,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 101,
	}, {
		Panel = c("ImageLabel", {
			ref = panelRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundTransparency = 1,
			Image = "rbxassetid://124751224634629",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(31, 41, 978, 620),
			SliceScale = 0.5,
			ZIndex = 102,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		}, {
			Scale = c("UIScale", { Scale = styles.Scale }),
			Title = label(
				string.upper(card.displayName) .. (if isCrate then " CRATE" else ""),
				UDim2.fromOffset(inset, 10),
				UDim2.new(1, -112, 0, 40),
				38,
				nil,
				true
			),
			Close = c(ShopPriceButton, {
				ButtonRef = closeRef,
				Text = "BACK",
				Enabled = true,
				Position = UDim2.new(1, -48, 0, 53),
				Size = UDim2.fromOffset(80, 44),
				OnActivated = props.OnClose,
				ZIndex = 106,
			}),
			Body = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(inset, bodyTop),
				Size = UDim2.new(1, -inset * 2, 0, bodyHeight),
				ZIndex = 103,
			}, {
				Preview = c("Frame", {
					BackgroundColor3 = colors.Ink,
					BackgroundTransparency = 0.35,
					BorderSizePixel = 0,
					Size = if portrait then UDim2.new(1, 0, 0, previewHeight) else UDim2.fromScale(0.32, 1),
					ZIndex = 103,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
					Art = c("Frame", {
						BackgroundTransparency = 1,
						Size = if portrait then UDim2.fromScale(0.4, 1) else UDim2.fromScale(1, 0.65),
						ZIndex = 103,
					}, {
						Content = c(ShopPreview, {
							Items = previews,
							Thumbnail = if selected then nil else card.thumbnail,
							ZIndex = 103,
						}),
					}),
					Name = label(
						if selected then selected.displayName else card.description,
						if portrait then UDim2.new(0.43, 0, 0, 8) else UDim2.new(0, 10, 0.66, 0),
						if portrait then UDim2.fromScale(0.53, 0.65) else UDim2.new(1, -20, 0.24, 0),
						22,
						nil,
						false,
						nil,
						true
					),
					Hint = if short
						then nil
						else label(
							if isCrate
								then "Select a reward to preview"
								else if isEmoteCollection then "Equip in Backpack → Emotes" else "Yours to keep",
							if portrait then UDim2.new(0.43, 0, 1, -27) else UDim2.new(0, 10, 1, -32),
							if portrait then UDim2.new(0.53, 0, 0, 22) else UDim2.new(1, -20, 0, 22),
							15,
							colors.Muted,
							false
						),
				}),
				Contents = if isCrate
					then c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.new(listX, 0, 0, listTop),
						Size = UDim2.new(listWidth, 0, 1, -listTop),
						ZIndex = 103,
					}, {
						Heading = label("REWARDS", UDim2.fromOffset(3, 0), UDim2.new(0.52, 0, 0, 26), 22, nil, true),
						OddsHeading = label(
							"NEXT OPEN ODDS",
							UDim2.fromScale(0.52, 0),
							UDim2.new(0.48, -8, 0, 26),
							15,
							colors.Muted,
							false,
							Enum.TextXAlignment.Right
						),
						List = c("ScrollingFrame", {
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
							CanvasSize = UDim2.new(),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							Position = UDim2.fromOffset(0, 28),
							Size = UDim2.new(1, 0, 1, -28),
							ScrollBarThickness = 4,
							ScrollBarImageColor3 = colors.Cyan,
							ZIndex = 103,
						}, contents),
					})
					else c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.new(listX, 0, 0, listTop),
						Size = UDim2.new(listWidth, 0, 1, -listTop),
						ZIndex = 103,
					}, {
						Heading = label(
							if isEmoteCollection then "THREE VICTORY EMOTES" else "YOURS TO KEEP",
							UDim2.fromOffset(0, 0),
							UDim2.new(1, 0, 0, 32),
							26,
							colors.Yellow,
							true
						),
						Description = label(
							card.description,
							UDim2.fromOffset(0, 40),
							UDim2.fromScale(1, 0.4),
							24,
							nil,
							false,
							nil,
							true
						),
						Items = if isEmoteCollection
							then c("ScrollingFrame", {
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								Position = UDim2.fromScale(0, if short then 0.48 else 0.5),
								Size = UDim2.fromScale(1, if short then 0.52 else 0.5),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								CanvasSize = UDim2.new(),
								ScrollBarThickness = 3,
								ZIndex = 103,
							}, styleButtons)
							else c("Frame", {
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0, 0.5),
								Size = UDim2.fromScale(1, 0.5),
								ZIndex = 103,
							}, {
								Preview = c(
									ShopPreview,
									{ Items = card.previewItems, Placeholder = "PERMANENT BOOST", ZIndex = 103 }
								),
							}),
					}),
			}),
			Footer = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, inset, 1, -footerHeight - inset),
				Size = UDim2.new(1, -inset * 2, 0, footerHeight),
				ZIndex = 103,
			}, {
				Guarantee = if isCrate
					then label(
						guaranteeText(card),
						UDim2.fromOffset(0, 0),
						UDim2.new(1, 0, 0, 23),
						17,
						colors.Yellow,
						false
					)
					else nil,
				Rule = if isCrate and not short
					then label(
						"Each open updates the guarantee. Repeats give Bonks.",
						UDim2.fromOffset(0, 23),
						UDim2.new(1, 0, 0, 18),
						14,
						colors.Muted,
						false
					)
					else nil,
				Buttons = c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, footerCopyHeight),
					Size = UDim2.new(1, 0, 0, rows * (buttonHeight + 6)),
					ZIndex = 104,
				}, buttons),
				Pending = if card.pending
					then label(
						if isCrate then "OPENING…" else "PROCESSING…",
						UDim2.fromOffset(0, -20),
						UDim2.new(1, 0, 0, 20),
						16,
						colors.Cyan,
						false,
						Enum.TextXAlignment.Right
					)
					else nil,
				Balance = if hasBonks and not isCrate
					then c(BonksLabel, {
						Amount = card.bonksAvailable or 0,
						MaxTextSize = 18,
						Native = { Size = UDim2.fromOffset(100, 20), ZIndex = 104 },
					})
					else nil,
			}),
		}),
	})
end
