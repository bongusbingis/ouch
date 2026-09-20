--!strict
local T = require(script.Parent.Parent.Tokens)
-- Offer details, interactive reward previews, and player-specific crate odds.
-- Purchase actions and profile state remain owned by the economy controller.

local formatNumber = require(script.Parent.Parent.Models.NumberText)

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ReactSpring = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react-spring"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Shop"))
local ItemLabels =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory")).ItemLabels
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local usePreferredTextSize = require(script.Parent.Parent.Hooks.usePreferredTextSize)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local DetailsLayout = require(script.Parent.Parent.Models.ShopDetailsLayout)
local CrateOddsLayout = require(script.Parent.Parent.Models.CrateOddsLayout)
local ResponsiveText = require(script.Parent.ResponsiveText)
local OuchPanel = require(script.Parent.CandyPanel)
local PageTitle = require(script.Parent.CandyTitle)
local CandySurface = require(script.Parent.CandySurface)
local Ribbon = require(script.Parent.RarityRibbon)
local ModalClose = require(script.Parent.ModalClose)
local BonksChip = require(script.Parent.BonksChip)
local PuffyButton = require(script.Parent.PuffyButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local CrateOddsGrid = require(script.Parent.Shop.CrateOddsGrid)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local CosmeticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic")
)
local Selection = require(script.Parent.Parent.Services.Selection)
local DeviceClass = require(script.Parent.Parent.Parent.Game.Input.DeviceClass)
local ScrollFrame = require(script.Parent.ScrollFrame)
local modalSurface = require(script.Parent.ModalSurface)

local Well = require(script.Parent.Well)
local WellScroll = require(script.Parent.WellScroll)

local c = React.createElement
local colors = require(script.Parent.Parent.EconomyPalette)
local C, I = T.Colors, T.Inspection

local function label(text, position, size, maxSize, color, heading, alignment, wrapped, order)
	return c(ResponsiveText, {
		MeasurementFont = if heading then Enum.Font.FredokaOne else T.Type.Label,
		MaxTextSize = math.max(T.Type.Minimum, maxSize),
		MinTextSize = T.Type.Minimum,
		Wrapped = wrapped,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = if heading then Enum.Font.FredokaOne else T.Type.Label,
			Text = text,
			TextWrapped = wrapped,
			TextColor3 = if color == colors.White or color == colors.Yellow
				then T.Colors.Ink
				else color or T.Colors.Ink,
			TextXAlignment = alignment or Enum.TextXAlignment.Left,
			ZIndex = 105,
			LayoutOrder = order,
		},
	}, {
		Outline = c("UIStroke", {
			Color = T.Colors.Surface,
			Thickness = 0,
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		}),
	})
end

local function text(value, position, size, maxSize, options)
	local settings = options or {}
	local font = settings.font or T.Type.Label
	return c(ResponsiveText, {
		MeasurementFont = font,
		MaxTextSize = maxSize,
		MinTextSize = math.min(maxSize, settings.minimum or T.Type.Minimum),
		Wrapped = settings.wrapped,
		Truncate = settings.truncate,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = font,
			Text = value,
			TextWrapped = settings.wrapped == true,
			TextTruncate = if settings.truncate then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None,
			TextColor3 = settings.color or C.Ink,
			TextXAlignment = settings.alignment or Enum.TextXAlignment.Left,
			TextYAlignment = settings.vertical or Enum.TextYAlignment.Top,
			ZIndex = settings.z or 105,
		},
	})
end

local function ribbonWidth(value: string): number
	local measured = TextService:GetTextSize(string.upper(value), T.Type.Minimum, T.Type.Label, Vector2.new(10000, 100))
	return math.max(I.BadgeMinWidth, math.ceil(measured.X) + 28)
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

local function useDetailsFocus(card, focusEnabled, panelRef, order)
	React.useEffect(function()
		if card == nil then
			return
		end
		local previous = GuiService.SelectedObject
		local panel = panelRef.current
		return function()
			local selected = GuiService.SelectedObject
			if (selected == nil or (panel and selected:IsDescendantOf(panel))) and Selection.isSelectable(previous) then
				GuiService.SelectedObject = previous
			end
		end
	end, { card ~= nil })
	React.useEffect(function()
		if card == nil or focusEnabled == false then
			return
		end
		local active = true
		local queued = false
		local function focus()
			queued = false
			if not active or (DeviceClass.current() ~= "Gamepad" and GuiService.SelectedObject == nil) then
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
				ownRoot
				and (not ownRoot.Enabled or (selectedRoot and selectedRoot.DisplayOrder > ownRoot.DisplayOrder))
			then
				return
			end
			if selected and selected.Selectable and panelRef.current and selected:IsDescendantOf(panelRef.current) then
				Selection.scrollIntoView(selected)
				return
			end
			for _, reference in order do
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
		scheduleFocus()
		return function()
			active = false
			connection:Disconnect()
			disconnect()
		end
	end, { card, focusEnabled })
end

local function panelNative(panelRef, width, height)
	return {
		ref = panelRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		ZIndex = 102,
		SelectionGroup = true,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
	}
end

local function surfaceNative(visible)
	return {
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		Active = true,
		BackgroundColor3 = T.Colors.Ink,
		BackgroundTransparency = 0.52,
		Visible = visible ~= false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 101,
	}
end

local function statusFor(card, isCrate, shortfall)
	return if card.pending
		then (if isCrate then "OPENING…" else "PROCESSING…")
		else if card.purchased
			then "PURCHASED"
			else if card.owned
				then (if isCrate then "OWNED" else "")
				else if card.status == "Loading"
					then "LOADING PRICE…"
					else if card.status == "Preview"
						then "COMING SOON"
						else if card.status == "Unavailable"
							then "UNAVAILABLE"
							else if shortfall > 0 then `NEED {formatNumber(shortfall)} MORE BONKS` else ""
end

local function ItemDetails(props)
	local safe = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local frame = DetailsLayout.frame(safe.size)
	local card = props.Card
	local selectedId, setSelectedId = React.useState(nil)
	local firstRef, robuxRef, inventoryRef, playRef, closeRef =
		React.useRef(nil), React.useRef(nil), React.useRef(nil), React.useRef(nil), React.useRef(nil)
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
	useDetailsFocus(card, props.FocusEnabled, panelRef, { firstRef, robuxRef, inventoryRef, playRef, closeRef })
	if card == nil then
		return nil
	end

	local listedItems = card.previewItems
	if card.definition.Contents then
		listedItems = {}
		for _, pieceId in card.definition.Contents do
			table.insert(listedItems, {
				itemId = pieceId,
				definition = Cosmetics.Items[pieceId],
				owned = CosmeticsLogic.isOwned(Cosmetics.Items, props.Owned or {}, pieceId),
			})
		end
	end
	local showList = #listedItems > 1
	local preview = card.previewItems[1]
	for _, item in card.previewItems do
		if item.itemId == selectedId then
			preview = item
			break
		end
	end
	local previews = if preview then { preview } else {}
	local isEffect = preview ~= nil
		and (preview.category == "ImpactEffectAssets" or preview.category == "ElimEffectAssets")
	local isEmoteCollection = card.kind == "GamePass" and preview ~= nil and preview.category == "EmoteAssets"
	local previewOwned = preview ~= nil
		and (preview.itemId == nil or CosmeticsLogic.isOwned(Cosmetics.Items, props.Owned or {}, preview.itemId))
	local equipped = preview ~= nil and ((props.Equipped or {})[preview.category] or "") == (preview.itemId or "")
	local hasEquip = previewOwned and props.OnEquipItem ~= nil
	local hasInventory = previewOwned and props.OnViewInventory ~= nil
	local hasBonks = card.bonksPrice ~= nil and not card.owned and not card.purchased
	local hasRobux = not card.owned
		and not card.purchased
		and (card.productId ~= nil or card.passId ~= nil)
		and card.robuxPrice ~= nil
	local hasAudition = isEffect and props.OnPreviewEffect ~= nil
	local balance = card.bonksAvailable or 0
	local shortfall = if hasBonks then math.max(0, card.bonksPrice - balance) else 0
	local statusText = statusFor(card, false, shortfall)
	local actionCount = (if hasBonks then 1 else 0)
		+ (if hasRobux then 1 else 0)
		+ (if hasEquip then 1 else 0)
		+ (if hasInventory then 1 else 0)

	local rarity = if preview and preview.definition then preview.definition.Rarity else nil
	local caption = if rarity and preview then ItemLabels[preview.category] else nil
	local descriptionSize = if frame.short then 18 else 20
	local descriptionHeight = math.ceil(
		TextService:GetTextSize(
			card.description or "",
			descriptionSize,
			T.Type.Label,
			Vector2.new(math.max(frame.detailsWidth - 4, 1), 10000)
		).Y
	) + 4
	local hintText = if isEmoteCollection
		then (if frame.stacked then "ASSIGN IN EMOTES" else "CHOOSE IN BACKPACK → EMOTES")
		else nil
	local descriptionTop = I.BadgeHeight + I.BadgeGap
	local hintTop = descriptionTop + descriptionHeight + 6
	local auditionTop = (if hintText then hintTop + I.ListCaptionHeight else descriptionTop + descriptionHeight)
		+ frame.gap
	local detailsHeight = if hasAudition
		then auditionTop + frame.auditionHeight
		elseif hintText then hintTop + I.ListCaptionHeight
		else descriptionTop + descriptionHeight
	local layout = DetailsLayout.resolve(frame, {
		detailsHeight = detailsHeight,
		listRows = if showList then #listedItems else 0,
		actionCount = actionCount,
		hasWallet = hasBonks,
		hasStatus = statusText ~= "",
	})

	local details = {}
	local badgeX = 0
	local badgeText = if rarity then nil elseif card.badge then card.badge else nil
	if rarity or badgeText then
		local width = ribbonWidth(rarity or badgeText)
		details.Badge = c(Ribbon, {
			Rarity = rarity,
			Text = badgeText,
			Native = {
				Position = UDim2.fromOffset(badgeX, 0),
				Size = UDim2.fromOffset(width, I.BadgeHeight),
				ZIndex = 106,
			},
		})
		badgeX += width + I.BadgeGap
	end
	if card.owned or card.purchased then
		local stamp = if card.purchased then "PURCHASED" else "OWNED"
		local width = ribbonWidth(stamp)
		details.Owned = c(Ribbon, {
			Text = stamp,
			Color = C.Yellow,
			Native = {
				Position = UDim2.fromOffset(badgeX, 0),
				Size = UDim2.fromOffset(width, I.BadgeHeight),
				ZIndex = 106,
			},
		})
		badgeX += width + I.BadgeGap
	end
	if caption and frame.detailsWidth - badgeX >= I.CaptionMinWidth then
		details.Caption = text(
			caption,
			UDim2.fromOffset(badgeX + 2, 0),
			UDim2.fromOffset(frame.detailsWidth - badgeX - 2, I.BadgeHeight),
			16,
			{ color = C.InkSoft, minimum = 14, truncate = true, vertical = Enum.TextYAlignment.Center }
		)
	end
	details.Description = text(
		card.description or "",
		UDim2.fromOffset(0, descriptionTop),
		UDim2.fromOffset(frame.detailsWidth, descriptionHeight),
		descriptionSize,
		{ wrapped = true }
	)
	if hintText then
		details.Hint = text(
			hintText,
			UDim2.fromOffset(0, hintTop),
			UDim2.fromOffset(frame.detailsWidth, I.ListCaptionHeight),
			16,
			{ color = C.InkSoft, minimum = 14, truncate = true, vertical = Enum.TextYAlignment.Center }
		)
	end
	if hasAudition then
		details.Audition = c(ShopPriceButton, {
			ButtonRef = playRef,
			Color = C.Cyan,
			Text = if preview.category == "ElimEffectAssets" then "PLAY SOUND" else "PLAY EFFECT",
			TextSize = 20,
			Enabled = true,
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromOffset(0, auditionTop),
			Size = UDim2.fromOffset(math.min(I.AuditionWidth, frame.detailsWidth), frame.auditionHeight),
			OnActivated = function()
				props.OnPreviewEffect(preview)
			end,
			ZIndex = 106,
		})
	end

	local function listBlock(x, y, width)
		local rows = {
			Layout = c("UIListLayout", { Padding = UDim.new(0, I.ListGap), SortOrder = Enum.SortOrder.LayoutOrder }),
			Padding = c("UIPadding", {
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, if layout.listScrolls then 10 else 2),
			}),
		}
		for index, item in listedItems do
			local name = item.definition.DisplayName
				.. (
					if item.owned
						then (if card.kind == "Bundle"
							then ` · +{Cosmetics.Rarities[item.definition.Rarity].DupeBonks or 0} Bonks (owned)`
							else " · OWNED")
						else ""
				)
			rows[item.itemId or `{index}`] = c(PuffyButton, {
				Enabled = item.definition.CostumePiece == nil,
				Color = C.Surface,
				StrokeColor = if preview and preview.itemId == item.itemId then C.Yellow else C.Ink,
				Radius = T.Shape.RadiusCard,
				Shadow = false,
				Text = name,
				TextColor = C.Ink,
				TextSize = if frame.compact then 18 else 20,
				Wrapped = true,
				OnActivated = function()
					setSelectedId(item.itemId)
				end,
				Native = { Size = UDim2.new(1, -4, 0, frame.listRowHeight), LayoutOrder = index, ZIndex = 106 },
			})
		end
		return c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(width, layout.listBlock),
			ZIndex = 105,
		}, {
			Caption = text(
				if card.owned
					then "IN YOUR BACKPACK"
					elseif card.definition.Contents then "THE OUTFIT"
					else "WHAT’S INSIDE",
				UDim2.fromOffset(2, 0),
				UDim2.fromOffset(width - 4, I.ListCaptionHeight),
				16,
				{ color = C.InkSoft, minimum = 14, truncate = true, vertical = Enum.TextYAlignment.Center }
			),
			Rows = c(ScrollFrame, {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, I.ListCaptionHeight + I.ListGap),
				Size = UDim2.fromOffset(width, layout.listHeight),
				ScrollingEnabled = layout.listScrolls,
				ScrollBarThickness = if layout.listScrolls then 4 else 0,
				ScrollBarImageColor3 = C.Pink,
				ZIndex = 105,
			}, rows),
		})
	end
	if showList and not frame.stacked then
		details.List = listBlock(0, layout.listTop - frame.contentInset, frame.detailsWidth)
	end

	local buttons = {}
	local function slot(index)
		local column = (index - 1) % layout.columns
		local row = math.floor((index - 1) / layout.columns)
		return UDim2.fromOffset(
			column * (layout.actionWidth + frame.footerGap),
			row * (frame.buttonHeight + frame.footerGap)
		)
	end
	local function action(name, index, options)
		buttons[name] = c(ShopPriceButton, {
			TextSize = UIConfig.Text.LabelPx,
			ButtonRef = options.ref,
			Red = options.red,
			Enabled = options.enabled,
			AnchorPoint = Vector2.zero,
			Position = slot(index),
			Size = UDim2.fromOffset(layout.actionWidth, frame.buttonHeight),
			Text = options.text,
			SubText = options.subText,
			SubBonks = options.subBonks,
			OnActivated = options.onActivated,
			ZIndex = 105,
		})
	end
	local actionIndex = 0
	if hasBonks then
		actionIndex += 1
		action("Buy", actionIndex, {
			ref = firstRef,
			red = true,
			enabled = card.status == "Active" and (card.bonksAvailable or (if card.affordable
				then card.bonksPrice
				else 0)) >= card.bonksPrice and not card.pending,
			text = if card.definition.Contents then "BUY OUTFIT" else "BUY ITEM",
			subBonks = card.bonksPrice,
			onActivated = function()
				props.OnPurchaseBonks(1)
			end,
		})
	end
	if hasRobux then
		actionIndex += 1
		action("Robux", actionIndex, {
			ref = robuxRef,
			red = true,
			enabled = card.status == "Active" and not card.pending,
			text = if card.passId
				then "GET PASS"
				else if card.kind == "Bundle"
					then "GET BUNDLE"
					else if card.kind == "Bonks" then "GET BONKS" else "BUY OUTFIT",
			subText = ShopConfig.RobuxSymbol .. formatNumber(card.robuxPrice),
			onActivated = props.OnPurchaseRobux,
		})
	end
	if hasEquip and preview then
		actionIndex += 1
		local busy = (props.BusySlots or {})[preview.category]
		action("Equip", actionIndex, {
			ref = firstRef,
			red = not equipped,
			enabled = previewOwned and not equipped and not busy,
			text = if busy then "EQUIPPING…" else if equipped then "EQUIPPED" else "EQUIP",
			onActivated = function()
				props.OnEquipItem(preview)
			end,
		})
	end
	if hasInventory and preview then
		actionIndex += 1
		action("Inventory", actionIndex, {
			ref = inventoryRef,
			enabled = true,
			text = "BACKPACK",
			onActivated = function()
				props.OnViewInventory(preview.category)
			end,
		})
	end
	local buttonsWidth = layout.columns * layout.actionWidth + math.max(layout.columns - 1, 0) * frame.footerGap
	local walletRowHeight = if layout.walletRowOnTop then frame.chipHeight else layout.footerHeight
	local statusX = if hasBonks then I.ChipReserve + frame.footerGap else 0
	local statusWidth = if layout.walletRowOnTop or actionCount == 0
		then frame.footerWidth - statusX
		else frame.footerWidth - statusX - buttonsWidth - frame.footerGap

	local previewFrame = {
		Surface = c(CandySurface, {
			Color = C.Surface,
			LipColor = C.WellLine,
			Radius = T.Shape.RadiusCard,
			Shadow = false,
			ZIndex = 104,
		}),
		Preview = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.new(1, -20, 1, -16 - T.Shape.LipHeight),
			ZIndex = 106,
		}, {
			Content = c(ShopPreview, {
				Items = previews,
				Playing = props.FocusEnabled ~= false and props.Visible ~= false,
				Thumbnail = if selectedId then nil else card.thumbnail,
				Placeholder = if card.kind == "Bonks"
					then "BONKS"
					elseif card.kind == "GamePass" then "PERMANENT BOOST"
					else card.badge,
				PlaceholderBonks = if card.kind == "Bonks" then card.definition.BonksAmount else nil,
				ZIndex = 106,
				ColorId = (props.Equipped or {}).CharacterColor,
				CostumeId = (props.Equipped or {}).CostumeAssets,
				TextColor = T.Colors.Ink,
				TextStroke = 0,
			}),
		}),
	}

	return modalSurface(surfaceNative(props.Visible), {
		Panel = c(OuchPanel, { Padding = 0, Native = panelNative(panelRef, frame.width, layout.height) }, {
			Scale = c("UIScale", { Scale = styles.Scale }),
			Title = c(PageTitle, {
				Text = string.upper(card.displayName),
				TextSize = frame.titleSize,
				Tilt = if frame.short then 0 else nil,
				Native = {
					Position = UDim2.fromOffset(frame.inset + (if frame.compact then 2 else 6), frame.titleTop),
					Size = UDim2.fromOffset(frame.width - frame.inset * 2 - T.Layout.MinTarget - 12, frame.titleHeight),
					ZIndex = 108,
				},
			}),
			Close = c(ModalClose, {
				ButtonRef = closeRef,
				Position = UDim2.new(1, -frame.inset, 0, frame.closeTop),
				OnActivated = props.OnClose,
				ZIndex = 109,
			}),
			Body = c(if layout.scroll then WellScroll else Well, {
				Candy = true,
				InsetPx = 0,
				Native = {
					Position = UDim2.fromOffset(frame.inset, layout.wellTop),
					Size = UDim2.new(1, -frame.inset * 2, 0, layout.wellHeight),
					CanvasSize = if layout.scroll then UDim2.fromOffset(0, layout.wellCanvas) else nil,
					ScrollingDirection = if layout.scroll then Enum.ScrollingDirection.Y else nil,
					ScrollBarThickness = if layout.scroll then 4 else nil,
					ScrollBarImageColor3 = if layout.scroll then C.Pink else nil,
					ZIndex = 103,
				},
			}, {
				Art = c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(frame.contentInset, frame.contentInset),
					Size = UDim2.fromOffset(layout.art, layout.art),
					ZIndex = 104,
				}, previewFrame),
				Details = c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(frame.contentInset + layout.art + frame.gap, frame.contentInset),
					Size = UDim2.fromOffset(frame.detailsWidth, layout.detailsBlock),
					ZIndex = 104,
				}, details),
				List = if showList and frame.stacked
					then listBlock(frame.contentInset, layout.listTop, frame.innerWidth)
					else nil,
			}),
			Footer = if layout.footerHeight > 0
				then c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(frame.inset, layout.footerTop),
					Size = UDim2.fromOffset(frame.footerWidth, layout.footerHeight),
					ZIndex = 103,
				}, {
					Wallet = if hasBonks
						then c(BonksChip, {
							Candy = true,
							Amount = balance,
							HeightPx = frame.chipHeight,
							TextSize = 20,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.fromOffset(0, walletRowHeight / 2),
							ZIndex = 104,
						})
						else nil,
					Status = if statusText ~= ""
						then text(
							statusText,
							UDim2.fromOffset(statusX, 0),
							UDim2.fromOffset(math.max(statusWidth, 1), walletRowHeight),
							18,
							{ color = C.InkSoft, wrapped = true, vertical = Enum.TextYAlignment.Center }
						)
						else nil,
					Buttons = if actionCount > 0
						then c("Frame", {
							AnchorPoint = if layout.walletRowOnTop then Vector2.zero else Vector2.new(1, 0),
							BackgroundTransparency = 1,
							Position = if layout.walletRowOnTop
								then UDim2.fromOffset(0, layout.buttonsTop)
								else UDim2.new(1, 0, 0, (layout.footerHeight - layout.buttonsHeight) / 2),
							Size = UDim2.fromOffset(buttonsWidth, layout.buttonsHeight),
							ZIndex = 104,
						}, buttons)
						else nil,
				})
				else nil,
		}),
	})
end

local function CrateDetails(props)
	local safe = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local preferredTextSize = usePreferredTextSize()
	local portrait = ResponsiveLayout.isPortrait(safe.size, UIConfig.Layout.PortraitMaxAspect)
	local size = ResponsiveLayout.panelSize(
		safe.size,
		UIConfig.Layout.Panels.ShopDetails,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	if portrait then
		size = Vector2.new(size.X, math.max(size.Y, safe.size.Y - 32))
	end
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
	useDetailsFocus(card, props.FocusEnabled, panelRef, { firstRef, robuxRef, closeRef })
	if card == nil then
		return nil
	end

	local short = not portrait and size.Y < 420
	local hasBonks = card.bonksPrice ~= nil and not card.owned and not card.purchased
	local hasRobux = not card.owned
		and not card.purchased
		and (card.productId ~= nil or card.passId ~= nil)
		and card.robuxPrice ~= nil
	local quantities = if hasBonks then card.openQuantities or { 1 } else {}
	local balance = card.bonksAvailable or 0
	local minimumPrice = math.huge
	for _, quantity in quantities do
		minimumPrice = math.min(minimumPrice, card.bonksPrice * quantity)
	end
	local shortfall = if minimumPrice < math.huge then math.max(0, minimumPrice - balance) else 0
	local statusText = statusFor(card, true, shortfall)
	local selected = nil
	for _, outcome in card.odds or {} do
		if outcome.itemId == selectedId then
			selected = outcome
			break
		end
	end
	local previews = if selected and selected.preview then { selected.preview } else card.previewItems
	local preview = previews[1]
	local isEffect = preview
		and selected ~= nil
		and (preview.category == "ImpactEffectAssets" or preview.category == "ElimEffectAssets")
	local compactEffect = short and isEffect
	local slots = #quantities + (if hasRobux then 1 else 0)
	local columns = if portrait then math.min(2, math.max(1, slots)) else math.max(1, slots)
	local rows = math.max(1, math.ceil(slots / columns))
	local buttonHeight = if short then 52 else 60
	local inset = if short or portrait then UIConfig.Spacing.CompactInsetPx else UIConfig.Spacing.PageInsetPx
	local veryShort = short and size.Y < 270
	local guarantee = guaranteeText(card)
	local footerGuarantee = guarantee ~= "" and (not short or compactEffect or veryShort)
	local statusWidth, sharedFooterHeight = 0, 26
	local shareFooter = false
	if veryShort and footerGuarantee and statusText ~= "" then
		local textSize = math.round(14 * (UIConfig.Text.PreferredScale[preferredTextSize.Name] or 1))
		local statusBounds = TextService:GetTextSize(statusText, textSize, T.Type.Label, Vector2.new(100000, 100000))
		local guaranteeBounds = TextService:GetTextSize(guarantee, textSize, T.Type.Label, Vector2.new(100000, 100000))
		statusWidth = math.ceil(statusBounds.X) + 8
		shareFooter = statusWidth + 12 + guaranteeBounds.X + 8 <= size.X - inset * 2
		sharedFooterHeight = math.max(26, math.ceil(math.max(statusBounds.Y, guaranteeBounds.Y)) + 4)
	end
	local balanceWithGuarantee = not short and not portrait and statusText == "" and footerGuarantee
	local summaryHeight = if portrait and hasBonks
		then 44
		elseif statusText ~= "" or (hasBonks and not short and not balanceWithGuarantee) then (if shareFooter
			then sharedFooterHeight
			else 26)
		else 0
	local guaranteeHeight = if footerGuarantee and not shareFooter
		then (if balanceWithGuarantee then 40 elseif short then 24 else if size.X < 620 then 44 else 28)
		else 0
	local showBalance = hasBonks and not short
	local balanceHeight = I.CompactChipHeight
	if showBalance and not balanceWithGuarantee then
		summaryHeight = math.max(summaryHeight, balanceHeight)
	end
	local balanceRowHeight = if balanceWithGuarantee then guaranteeHeight else summaryHeight
	-- The wallet owns a full copy row, plus clearance for both its outline and button hover.
	local footerCopyHeight = summaryHeight + guaranteeHeight + (if showBalance then T.Shop.CardGap else 8)
	local actionHeight = if slots > 0 then rows * (buttonHeight + UIConfig.Spacing.ControlGapPx) else 0
	local footerHeight = actionHeight + footerCopyHeight
	local balanceWidth = if size.X < 620 then 120 else 252
	local actionWidth = math.min(size.X - inset * 2, columns * (UIConfig.Layout.ShopDetailsActionMaxWidthPx + 8))
	local titleWidth = size.X - inset * 2 - 100 - (if short and hasBonks then 112 else 0)
	local titleSize = if short then 26 else 36
	local titleText = string.upper(card.displayName) .. " CRATE"
	local titleHeight = math.max(
		48,
		TextService:GetTextSize(titleText, titleSize, T.Type.Display, Vector2.new(math.max(titleWidth - 36, 1), 10000)).Y
			+ 12
	)
	local bodyTop = inset + titleHeight + (if short then 6 else 12)
	local bodyHeight = size.Y - bodyTop - footerHeight - inset - (if short then 0 else 8)
	local previewContentHeight = if veryShort
		then math.max(bodyHeight, if compactEffect then 96 else 88)
		else bodyHeight
	local scrollPreview = previewContentHeight > bodyHeight
	local previewHeight = if portrait then math.min(132, math.max(104, bodyHeight * 0.31)) else bodyHeight
	local showPreview = not (portrait and selected == nil)
	local listTop = if portrait and showPreview then previewHeight + 8 else 0
	local listX = if portrait then 0 else 0.35
	local listWidth = if portrait then 1 else 0.65
	local nameHeight = if short then 36 else 52
	local previewFooter = if isEffect
		then 56
		else if short and not footerGuarantee and guarantee ~= "" then 52 else if short then 8 else 34
	local artHeight = math.min(
		if short or portrait then math.huge else 280,
		math.max(if veryShort then 32 else 44, previewContentHeight - nameHeight - previewFooter - 16)
	)
	local previewStackTop = if portrait or short
		then 0
		else math.max(0, math.floor((previewContentHeight - artHeight - nameHeight - previewFooter - 16) / 2))
	local scrollInset, scrollBarWidth = 8, 4
	local gridViewport = (size.X - inset * 2) * listWidth - scrollInset * 2 - scrollBarWidth
	-- Preserve the existing card-density budget while fitting motion inside that budget.
	local gridGap = if short then 8 else UIConfig.Spacing.ControlGapPx
	local gridListPx = (size.X - inset * 2) * listWidth - 26
	local gridMinTile = if short then 112 else 124
	local gridColumns = math.clamp(math.floor((gridListPx + gridGap) / (gridMinTile + gridGap)), 2, 6)
	local gridTile =
		math.min(if portrait then 124 else 136, math.floor((gridListPx - (gridColumns - 1) * gridGap) / gridColumns))
	local gridLayout =
		CrateOddsLayout.resolve(math.min(gridViewport, gridColumns * gridTile + (gridColumns - 1) * gridGap))
	local contents = {
		Layout = c(
			"UIListLayout",
			{ Padding = UDim.new(0, if short then 4 else 6), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, T.Shape.StrokeTab),
			PaddingBottom = UDim.new(0, T.Shape.StrokeTab),
			PaddingLeft = UDim.new(0, gridLayout.inset),
			PaddingRight = UDim.new(0, gridLayout.inset),
		}),
		Grid = c(CrateOddsGrid, {
			Odds = card.odds or {},
			SelectedId = selectedId,
			OnSelect = setSelectedId,
			Layout = gridLayout,
			ColorId = (props.Equipped or {}).CharacterColor,
			CostumeId = (props.Equipped or {}).CostumeAssets,
			ZIndex = 104,
		}),
	}

	local buttons = {}
	local function position(index)
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		return UDim2.new(
			(column + 0.5) / columns,
			0,
			0,
			row * (buttonHeight + UIConfig.Spacing.ControlGapPx) + buttonHeight
		)
	end
	for index, quantity in quantities do
		local amount = card.bonksPrice * quantity
		buttons["Open" .. quantity] = c(ShopPriceButton, {
			TextSize = UIConfig.Text.LabelPx,
			ButtonRef = if index == 1 then firstRef else nil,
			Red = true,
			Enabled = card.status == "Active"
				and (card.bonksAvailable or (if card.affordable then amount else 0)) >= amount
				and not card.pending,
			Position = position(index),
			Size = UDim2.new(1 / columns, -14, 0, buttonHeight),
			Text = "OPEN " .. quantity,
			SubBonks = amount,
			OnActivated = function()
				props.OnPurchaseBonks(quantity)
			end,
			ZIndex = 105,
		})
	end
	if hasRobux then
		buttons.Robux = c(ShopPriceButton, {
			TextSize = UIConfig.Text.LabelPx,
			ButtonRef = robuxRef,
			Enabled = card.status == "Active" and not card.pending,
			Red = true,
			Position = position(#quantities + 1),
			Size = UDim2.new(1 / columns, -14, 0, buttonHeight),
			Text = "OPEN 1",
			SubText = ShopConfig.RobuxSymbol .. formatNumber(card.robuxPrice),
			OnActivated = props.OnPurchaseRobux,
			ZIndex = 105,
		})
	end

	return modalSurface(surfaceNative(props.Visible), {
		-- Keep the footer parallel to the shell; the title sticker retains its playful tilt.
		Panel = c(OuchPanel, { Padding = 0, Tilt = 0, Native = panelNative(panelRef, size.X, size.Y) }, {
			Scale = c("UIScale", { Scale = styles.Scale }),
			Title = c(PageTitle, {
				Text = titleText,
				TextSize = titleSize,
				Alignment = Enum.TextXAlignment.Left,
				Native = {
					Position = UDim2.fromOffset(inset, inset + 2),
					Size = UDim2.fromOffset(titleWidth, titleHeight),
					ZIndex = 105,
				},
			}),
			Close = c(ModalClose, {
				ButtonRef = closeRef,
				Position = UDim2.new(1, -inset, 0, inset),
				OnActivated = props.OnClose,
				ZIndex = 106,
			}),
			ShortBalance = if short and hasBonks
				then c(BonksLabel, {
					Amount = balance,
					MaxTextSize = 21,
					TextColor = colors.Yellow,
					TextStroke = 0,
					Alignment = Enum.HorizontalAlignment.Right,
					Native = {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -inset - 104, 0, inset),
						Size = UDim2.fromOffset(108, 44),
						ZIndex = 105,
					},
				})
				else nil,
			Body = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(inset, bodyTop),
				Size = UDim2.new(1, -inset * 2, 0, bodyHeight),
				ZIndex = 103,
			}, {
				Preview = c(if scrollPreview then WellScroll else Well, {
					Candy = true,
					Native = {
						Visible = showPreview,
						CanvasSize = if scrollPreview then UDim2.fromOffset(0, previewContentHeight) else nil,
						ScrollingDirection = if scrollPreview then Enum.ScrollingDirection.Y else nil,
						ScrollBarThickness = if scrollPreview then 3 else nil,
						ScrollBarImageColor3 = if scrollPreview then T.Colors.Pink else nil,
						Size = if portrait then UDim2.new(1, 0, 0, previewHeight) else UDim2.fromScale(0.32, 1),
						ZIndex = 103,
					},
				}, {
					Rarity = if selected ~= nil
							and preview
							and preview.definition
							and preview.definition.Rarity
						then c(Ribbon, {
							Rarity = preview.definition.Rarity,
							Native = {
								Position = UDim2.fromOffset(12, 12),
								Size = UDim2.fromOffset(150, 28),
								ZIndex = 111,
							},
						})
						else nil,
					Art = c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(0, previewStackTop),
						Size = if portrait
							then UDim2.fromScale(0.4, 1)
							else if compactEffect
								then UDim2.new(0.36, 0, 0, previewContentHeight - 56)
								else UDim2.new(1, 0, 0, artHeight),
						ZIndex = 103,
					}, {
						Content = c(ShopPreview, {
							Items = previews,
							Playing = props.FocusEnabled ~= false and props.Visible ~= false,
							Thumbnail = if selected then nil else card.thumbnail,
							ZIndex = 103,
							ColorId = (props.Equipped or {}).CharacterColor,
							CostumeId = (props.Equipped or {}).CostumeAssets,
							TextColor = T.Colors.Ink,
							TextStroke = 0,
						}),
					}),
					Name = label(
						if short and not selected
							then "NEXT OPEN ODDS"
							else if selected then selected.displayName else card.displayName,
						if portrait
							then UDim2.new(0.43, 0, 0, 8)
							else if compactEffect
								then UDim2.new(0.36, 8, 0, 4)
								else UDim2.fromOffset(10, previewStackTop + artHeight + 8),
						if portrait
							then UDim2.new(0.53, 0, 0, previewHeight - previewFooter - 16)
							else if compactEffect
								then UDim2.new(0.64, -24, 0, previewContentHeight - 76)
								else UDim2.new(1, -20, 0, nameHeight),
						if short then 18 else 22,
						nil,
						true,
						nil,
						true
					),
					Guarantee = if short
							and not footerGuarantee
							and guarantee ~= ""
						then label(
							guarantee,
							UDim2.new(0, 10, 1, -48),
							UDim2.new(1, -20, 0, 44),
							14,
							colors.Yellow,
							false,
							nil,
							true
						)
						else nil,
					Play = if isEffect and props.OnPreviewEffect
						then c(ShopPriceButton, {
							Color = colors.Pink,
							Text = if preview.category == "ElimEffectAssets" then "PLAY SOUND" else "PLAY EFFECT",
							Enabled = true,
							Position = if portrait
								then UDim2.new(0.7, 0, 1, -12)
								else UDim2.new(
									0.5,
									0,
									0,
									if short
										then previewContentHeight - 16
										else previewStackTop
											+ artHeight
											+ 8
											+ nameHeight
											+ UIConfig.Spacing.ControlGapPx
											+ 48
								),
							Size = if portrait then UDim2.new(0.55, -24, 0, 44) else UDim2.new(1, -32, 0, 48),
							OnActivated = function()
								props.OnPreviewEffect(preview)
							end,
							ZIndex = 105,
						})
						else nil,
					Hint = if short or isEffect
						then nil
						else label(
							"CHOOSE A REWARD",
							if portrait
								then UDim2.new(0.43, 0, 1, -27)
								else UDim2.fromOffset(10, previewStackTop + artHeight + 8 + nameHeight + 8),
							if portrait then UDim2.new(0.53, 0, 0, 22) else UDim2.new(1, -20, 0, 22),
							UIConfig.Text.CaptionMinPx,
							colors.White,
							false
						),
				}),
				Contents = c(Well, {
					Candy = true,
					Native = {
						Position = UDim2.new(listX, 0, 0, listTop),
						Size = UDim2.new(listWidth, 0, 1, -listTop),
						ZIndex = 103,
					},
				}, {
					OddsHeading = if not short
						then label(
							"NEXT OPEN ODDS",
							UDim2.fromOffset(12, 6),
							UDim2.new(1, -24, 0, 30),
							22,
							colors.White,
							true
						)
						else nil,
					List = c(ScrollFrame, {
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(scrollInset, if short then 8 else 40),
						Size = UDim2.new(1, -scrollInset * 2, 1, if short then -16 else -48),
						ScrollingDirection = Enum.ScrollingDirection.Y,
						VerticalScrollBarInset = Enum.ScrollBarInset.Always,
						ScrollBarThickness = scrollBarWidth,
						ScrollBarImageColor3 = colors.White,
						ZIndex = 103,
					}, contents),
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
						if shareFooter
							then UDim2.fromOffset(statusWidth, summaryHeight)
							else UDim2.new(
								1,
								if hasBonks and not short then -balanceWidth - 12 else 0,
								0,
								summaryHeight
							),
						if shareFooter then 14 else if short then 15 else 18,
						colors.White,
						false
					)
					else nil,
				Guarantee = if footerGuarantee
					then label(
						guarantee,
						if shareFooter
							then UDim2.fromOffset(statusWidth + 12, 0)
							else UDim2.fromOffset(0, summaryHeight),
						if shareFooter
							then UDim2.new(1, -statusWidth - 12, 0, summaryHeight)
							else UDim2.new(
								1,
								if balanceWithGuarantee then -balanceWidth - 12 else 0,
								0,
								guaranteeHeight
							),
						if veryShort then 14 else 18,
						colors.Yellow,
						false,
						nil,
						true
					)
					else nil,
				Buttons = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.new(0.5, 0, 0, footerCopyHeight),
					Size = UDim2.fromOffset(actionWidth, actionHeight),
					ZIndex = 104,
				}, buttons),
				Balance = if showBalance
					then c(BonksChip, {
						Candy = true,
						Amount = balance,
						HeightPx = balanceHeight,
						TextSize = 20,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 0, 0, (balanceRowHeight - balanceHeight) / 2),
						ZIndex = 104,
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
	if props.Card and props.Card.kind == "Crate" then
		return c(CrateDetails, props)
	end
	return c(ItemDetails, props)
end
