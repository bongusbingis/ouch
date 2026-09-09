-- Offer details, interactive reward previews, and player-specific crate odds.
-- Purchase actions and profile state remain owned by the economy controller.
--!strict

local formatNumber = require(script.Parent.Parent.Models.NumberText)

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ReactSpring = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Shop"))
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local ResponsiveText = require(script.Parent.ResponsiveText)
local AnimatedButton = require(script.Parent.AnimatedButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local CosmeticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic")
)
local Selection = require(script.Parent.Parent.Services.Selection)
local DeviceClass = require(script.Parent.Parent.Parent.Game.Input.DeviceClass)
local ScrollFrame = require(script.Parent.ScrollFrame)
local modalSurface = require(script.Parent.ModalSurface)

local c = React.createElement
local colors = UIConfig.ProgressionStyle

local function label(text, position, size, maxSize, color, heading, alignment, wrapped, order)
	return c(ResponsiveText, {
		MeasurementFont = if heading then Enum.Font.LuckiestGuy else UIConfig.Text.BodyFont,
		MaxTextSize = maxSize,
		Wrapped = wrapped,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = if heading then Enum.Font.LuckiestGuy else UIConfig.Text.BodyFont,
			Text = text,
			TextWrapped = wrapped,
			TextColor3 = color or Color3.new(1, 1, 1),
			TextXAlignment = alignment or Enum.TextXAlignment.Left,
			ZIndex = 105,
			LayoutOrder = order,
		},
	}, {
		Outline = c("UIStroke", {
			Color = colors.Ink,
			Thickness = if heading then 0.045 else 0.035,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		}),
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

local function ItemDetails(props)
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
	local inventoryRef = React.useRef(nil)
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
		local panel = panelRef.current
		return function()
			local selected = GuiService.SelectedObject
			if
				DeviceClass.current() == "Gamepad"
				and (selected == nil or (panel and selected:IsDescendantOf(panel)))
				and Selection.isSelectable(previous)
			then
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
			if not active or DeviceClass.current() ~= "Gamepad" then
				return
			end
			local selected = GuiService.SelectedObject
			if selected and not selected:IsDescendantOf(Players.LocalPlayer.PlayerGui) then
				return
			end
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
				Selection.scrollIntoView(selected)
				return
			end
			for _, reference in { firstRef, robuxRef, inventoryRef, closeRef } do
				local button = reference.current
				if Selection.isSelectable(button) then
					GuiService.SelectedObject = button
					break
				end
			end
		end
		local function scheduleFocus()
			if not queued then
				queued = true
				task.delay(0, focus)
			end
		end
		local connection = GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(scheduleFocus)
		local disconnect = DeviceClass.observe(function(input)
			if input == "Gamepad" then
				scheduleFocus()
			end
		end)
		return function()
			active = false
			connection:Disconnect()
			disconnect()
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
	local hasBonks = card.bonksPrice ~= nil and not card.owned
	local hasRobux = not card.owned and (card.productId ~= nil or card.passId ~= nil) and card.robuxPrice ~= nil
	local quantities = if isCrate and hasBonks then card.openQuantities or { 1 } else if hasBonks then { 1 } else {}
	local balance = card.bonksAvailable or 0
	local minimumPrice = math.huge
	for _, quantity in quantities do
		minimumPrice = math.min(minimumPrice, card.bonksPrice * quantity)
	end
	local shortfall = if minimumPrice < math.huge then math.max(0, minimumPrice - balance) else 0
	local statusText = if card.pending
		then (if isCrate then "OPENING…" else "PROCESSING…")
		else if card.owned
			then "OWNED"
			else if card.status == "Loading"
				then "LOADING PRICE…"
				else if card.status == "Preview"
					then "COMING SOON"
					else if card.status == "Unavailable"
						then "UNAVAILABLE"
						else if shortfall > 0 then `NEED {formatNumber(shortfall)} MORE BONKS` else ""
	local selected = nil
	for _, outcome in card.odds or {} do
		if outcome.itemId == selectedId then
			selected = outcome
			break
		end
	end
	if not isCrate and #card.previewItems > 0 then
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
	local listedItems = card.previewItems
	if card.definition.Contents then
		listedItems = {}
		for _, pieceId in card.definition.Contents do
			local definition = Cosmetics.Items[pieceId]
			table.insert(listedItems, {
				itemId = pieceId,
				definition = definition,
				owned = CosmeticsLogic.isOwned(Cosmetics.Items, props.Owned or {}, pieceId),
			})
		end
	end
	if not isCrate then
		styleButtons.Layout = c("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		for index, item in listedItems do
			styleButtons[item.itemId or item.category] = c(AnimatedButton, {
				Enabled = item.definition.CostumePiece == nil,
				OnActivated = function()
					setSelectedId(item.itemId)
				end,
				Native = {
					BackgroundColor3 = if selected.preview.itemId == item.itemId
						then colors.Pink
						else colors.PanelRaised,
					BorderSizePixel = 0,
					Size = UDim2.new(1, -8, 0, 44),
					LayoutOrder = index,
					ZIndex = 104,
				},
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Name = label(
					item.definition.DisplayName
						.. (
							if item.owned
								then (if card.kind == "Bundle"
									then ` · +{Cosmetics.Rarities[item.definition.Rarity].DupeBonks or 0} Bonks (owned)`
									else " · OWNED")
								else ""
						),
					UDim2.fromOffset(12, 0),
					UDim2.new(1, -24, 1, 0),
					23,
					if selected.preview.itemId == item.itemId then colors.Yellow else nil,
					false,
					nil,
					true
				),
			})
		end
	end
	local previews = if selected and selected.preview then { selected.preview } else card.previewItems
	local preview = previews[1]
	local isEffect = preview
		and (not isCrate or selected ~= nil)
		and (preview.category == "ImpactEffectAssets" or preview.category == "ElimEffectAssets")
	local compactEffect = short and isEffect
	local previewOwned = preview
		and (preview.itemId == nil or CosmeticsLogic.isOwned(Cosmetics.Items, props.Owned or {}, preview.itemId))
	local equipped = preview and ((props.Equipped or {})[preview.category] or "") == (preview.itemId or "")
	local hasEquip = not isCrate and previewOwned and props.OnEquipItem ~= nil
	local hasInventory = not isCrate and previewOwned and props.OnViewInventory ~= nil
	local slots = #quantities
		+ (if hasRobux then 1 else 0)
		+ (if hasEquip then 1 else 0)
		+ (if hasInventory then 1 else 0)
	local columns = if portrait then math.min(2, math.max(1, slots)) else math.max(1, slots)
	local rows = math.max(1, math.ceil(slots / columns))
	local buttonHeight = if short then 52 else if portrait then 60 else 68
	local summaryHeight = if hasBonks or statusText ~= "" then 26 else 0
	local guarantee = if isCrate then guaranteeText(card) else ""
	local guaranteeHeight = if guarantee ~= "" then 23 else 0
	local ruleHeight = if isCrate and not short then 20 else 0
	local footerCopyHeight = summaryHeight + guaranteeHeight + ruleHeight + 4
	local actionHeight = if slots > 0 then rows * (buttonHeight + 6) else 0
	local footerHeight = actionHeight + footerCopyHeight
	local inset = if short then 12 else 16
	local balanceWidth = if short then 214 else 252
	local actionWidth = math.min(size.X - inset * 2, columns * (UIConfig.Layout.ShopDetailsActionMaxWidthPx + 8))
	local bodyTop = if short then 52 else 64
	local bodyHeight = size.Y - bodyTop - footerHeight - inset
	local previewHeight = if portrait then math.min(132, math.max(104, bodyHeight * 0.31)) else bodyHeight
	local listTop = if portrait then previewHeight + 8 else 0
	local listX = if portrait then 0 else 0.35
	local listWidth = if portrait then 1 else 0.65
	local nameHeight = if short then 36 else 52
	local previewFooter = if isEffect then 56 else if short or (not isCrate and not isEmoteCollection) then 8 else 34
	local artHeight = math.max(44, bodyHeight - nameHeight - previewFooter - 16)
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
			else `Duplicate: +{formatNumber(outcome.bonksRefund or 0)} Bonks`
		contents[outcome.itemId] = c(AnimatedButton, {
			Enabled = true,
			OnActivated = function()
				setSelectedId(outcome.itemId)
			end,
			Native = {
				BackgroundColor3 = if chosen then colors.Pink else colors.PanelRaised,
				BackgroundTransparency = 0,
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
				colors.White,
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
					colors.White,
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
			Red = true,
			Enabled = card.status == "Active"
				and (card.bonksAvailable or (if card.affordable then amount else 0)) >= amount
				and not card.pending,
			Position = position(index),
			Size = UDim2.new(1 / columns, -14, 0, buttonHeight),
			Text = if isCrate
				then "OPEN " .. quantity
				else if card.definition.Contents then "BUY OUTFIT" else "BUY ITEM",
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
			Position = position(#quantities + 1),
			Size = UDim2.new(1 / columns, -14, 0, buttonHeight),
			Text = if isCrate
				then "OPEN 1"
				else if card.passId
					then "GET PASS"
					else if card.kind == "Bundle"
						then "GET BUNDLE"
						else if card.kind == "Bonks" then "GET BONKS" else "BUY OUTFIT",
			SubText = ShopConfig.RobuxSymbol .. formatNumber(card.robuxPrice),
			OnActivated = props.OnPurchaseRobux,
			ZIndex = 105,
		})
	end

	local actionIndex = #quantities + (if hasRobux then 1 else 0)
	if hasEquip and preview then
		actionIndex += 1
		buttons.Equip = c(ShopPriceButton, {
			ButtonRef = firstRef,
			Enabled = previewOwned and not equipped and not (props.BusySlots or {})[preview.category],
			Position = position(actionIndex),
			Size = UDim2.new(1 / columns, -14, 0, buttonHeight),
			Text = if (props.BusySlots or {})[preview.category]
				then "EQUIPPING…"
				else if equipped then "EQUIPPED" else "EQUIP",
			OnActivated = function()
				props.OnEquipItem(preview)
			end,
			ZIndex = 105,
		})
	end
	if hasInventory and preview then
		actionIndex += 1
		buttons.Inventory = c(ShopPriceButton, {
			ButtonRef = inventoryRef,
			Enabled = true,
			Position = position(actionIndex),
			Size = UDim2.new(1 / columns, -14, 0, buttonHeight),
			Text = "BACKPACK",
			OnActivated = function()
				props.OnViewInventory(preview.category)
			end,
			ZIndex = 105,
		})
	end

	return modalSurface({
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
					BackgroundColor3 = colors.PanelRaised,
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Size = if portrait then UDim2.new(1, 0, 0, previewHeight) else UDim2.fromScale(0.32, 1),
					ZIndex = 103,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
					Art = c("Frame", {
						BackgroundTransparency = 1,
						Size = if portrait
							then UDim2.fromScale(0.4, 1)
							else if compactEffect
								then UDim2.new(0.36, 0, 1, -56)
								else UDim2.new(1, 0, 0, artHeight),
						ZIndex = 103,
					}, {
						Content = c(ShopPreview, {
							Items = previews,
							Thumbnail = if selected then nil else card.thumbnail,
							ZIndex = 103,
							ColorId = (props.Equipped or {}).CharacterColor,
							CostumeId = (props.Equipped or {}).CostumeAssets,
							TextColor = colors.White,
							TextStroke = 0.045,
						}),
					}),
					Name = label(
						if selected then selected.displayName else card.displayName,
						if portrait
							then UDim2.new(0.43, 0, 0, 8)
							else if compactEffect
								then UDim2.new(0.36, 8, 0, 4)
								else UDim2.fromOffset(10, artHeight + 8),
						if portrait
							then UDim2.new(0.53, 0, 0, previewHeight - previewFooter - 16)
							else if compactEffect
								then UDim2.new(0.64, -16, 1, -64)
								else UDim2.new(1, -20, 0, nameHeight),
						22,
						nil,
						false,
						nil,
						true
					),
					Play = if isEffect and props.OnPreviewEffect
						then c(ShopPriceButton, {
							Text = if preview.category == "ElimEffectAssets" then "PLAY SOUND" else "PLAY EFFECT",
							Enabled = true,
							Position = if portrait then UDim2.new(0.7, 0, 1, -4) else UDim2.new(0.5, 0, 1, -8),
							Size = if portrait then UDim2.new(0.55, -8, 0, 44) else UDim2.new(1, -16, 0, 48),
							OnActivated = function()
								props.OnPreviewEffect(preview)
							end,
							ZIndex = 105,
						})
						else nil,
					Hint = if short
							or isEffect
							or (not isCrate and not isEmoteCollection)
						then nil
						else label(
							if isCrate then "PICK A REWARD TO PREVIEW" else "CHOOSE IN BACKPACK → EMOTES",
							if portrait then UDim2.new(0.43, 0, 1, -27) else UDim2.new(0, 10, 1, -32),
							if portrait then UDim2.new(0.53, 0, 0, 22) else UDim2.new(1, -20, 0, 22),
							15,
							colors.White,
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
							colors.White,
							false,
							Enum.TextXAlignment.Right
						),
						List = c(ScrollFrame, {
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
							CanvasSize = UDim2.new(),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							Position = UDim2.fromOffset(0, 28),
							Size = UDim2.new(1, 0, 1, -28),
							ScrollBarThickness = 4,
							ScrollBarImageColor3 = colors.White,
							ZIndex = 103,
						}, contents),
					})
					else c(ScrollFrame, {
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(),
						ScrollBarThickness = 4,
						BorderSizePixel = 0,
						BackgroundTransparency = 1,
						Position = UDim2.new(listX, 0, 0, listTop),
						Size = UDim2.new(listWidth, 0, 1, -listTop),
						ZIndex = 103,
					}, {
						Layout = c(
							"UIListLayout",
							{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }
						),
						AHeading = label(
							if card.owned
								then "IN YOUR BACKPACK"
								else if card.definition.Contents
									then "THE OUTFIT"
									else if #card.previewItems > 0 then "WHAT’S INSIDE" else "THE GOODS",
							UDim2.fromOffset(0, 0),
							UDim2.new(1, -8, 0, if short then 24 else 32),
							if short then 20 else 26,
							colors.Yellow,
							true,
							nil,
							nil,
							1
						),
						BDescription = label(
							card.description,
							UDim2.fromOffset(0, 40),
							UDim2.new(1, -10, 0, if short then 52 else 80),
							if short then 18 else 24,
							nil,
							false,
							nil,
							true,
							2
						),
						CItems = if #listedItems > 0
							then c("Frame", {
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								LayoutOrder = 3,
								ZIndex = 103,
							}, styleButtons)
							else c("Frame", {
								BackgroundTransparency = 1,
								Size = UDim2.new(1, -8, 0, 140),
								ZIndex = 103,
							}, {
								Preview = c(ShopPreview, {
									Items = card.previewItems,
									Placeholder = if card.kind == "Bonks" then "BONKS" else "PERMANENT BOOST",
									PlaceholderBonks = if card.kind == "Bonks"
										then card.definition.BonksAmount
										else nil,
									ZIndex = 103,
								}),
							}),
					}),
			}),
			Footer = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, inset, 1, -footerHeight - inset),
				Size = UDim2.new(1, -inset * 2, 0, footerHeight),
				ZIndex = 103,
			}, {
				Status = if statusText ~= ""
					then label(
						statusText,
						UDim2.fromOffset(0, 0),
						UDim2.new(1, if hasBonks then -balanceWidth - 12 else 0, 0, summaryHeight),
						if short then 15 else 18,
						colors.White,
						false
					)
					else nil,
				Guarantee = if guarantee ~= ""
					then label(
						guarantee,
						UDim2.fromOffset(0, summaryHeight),
						UDim2.new(1, 0, 0, guaranteeHeight),
						17,
						colors.Yellow,
						false
					)
					else nil,
				Rule = if ruleHeight > 0
					then label(
						"Duplicate items give Bonks. Guarantees update after every open.",
						UDim2.fromOffset(0, summaryHeight + guaranteeHeight),
						UDim2.new(1, 0, 0, ruleHeight),
						14,
						colors.White,
						false
					)
					else nil,
				Buttons = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.new(0.5, 0, 0, footerCopyHeight),
					Size = UDim2.fromOffset(actionWidth, actionHeight),
					ZIndex = 104,
				}, buttons),
				BalanceTitle = if hasBonks
					then label(
						if short then "BONKS" else "YOUR BONKS",
						UDim2.new(1, -balanceWidth, 0, 0),
						UDim2.fromOffset(balanceWidth - 132, summaryHeight),
						16,
						colors.White,
						true
					)
					else nil,
				Balance = if hasBonks
					then c(BonksLabel, {
						Amount = balance,
						MaxTextSize = 21,
						TextColor = colors.White,
						TextStroke = 0.045,
						Alignment = Enum.HorizontalAlignment.Right,
						Native = {
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.fromOffset(132, summaryHeight),
							ZIndex = 104,
						},
					})
					else nil,
			}),
		}),
	})
end

local SeasonPassModal = require(script.Parent.SeasonPassModal)
return function(props)
	if props.Card and props.Card.kind == "SeasonPass" then
		return c(SeasonPassModal, props)
	end
	return c(ItemDetails, props)
end
