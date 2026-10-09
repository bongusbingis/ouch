--!strict
local T = require(script.Parent.Parent.Tokens)
local EconomyPalette = require(script.Parent.Parent.EconomyPalette)
-- Description: Short candy-glow build, landing and reward reveal, with skip, replay and duplicate-refund reporting.

local formatNumber = require(script.Parent.Parent.Models.NumberText)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local useCrateRevealMotion = require(script.Parent.Parent.Hooks.useCrateRevealMotion)
local CrateOpeningGlow = require(script.Parent.CrateOpeningGlow)
local OuchPanel = require(script.Parent.CandyPanel)
local PuffyButton = require(script.Parent.PuffyButton)
local Ribbon = require(script.Parent.RarityRibbon)
local CollectibleFace = require(script.Parent.CollectibleFace)
local CollectibleLayout = require(script.Parent.Parent.Models.CollectibleLayout)
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveText = require(script.Parent.ResponsiveText)
local TextMetrics = require(script.Parent.Parent.TextMetrics)
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Services.Selection)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local CosmeticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic")
)

local modalSurface = require(script.Parent.ModalSurface)

local ModalClose = require(script.Parent.ModalClose)

local CandyTitle = require(script.Parent.CandyTitle)
local c = React.createElement

-- Rarity changes the celebratory ray count only; timing stays short for every pull.
local RARITY_TIERS = {
	Common = { rays = 8 },
	Rare = { rays = 12 },
	Legendary = { rays = 18 },
	Exclusive = { rays = 22 },
}
local DEFAULT_TIER = RARITY_TIERS.Common

local function tierFor(rarity: string?)
	return (if rarity then RARITY_TIERS[rarity] else nil) or DEFAULT_TIER
end

local function rarityColor(rarity: string?): Color3
	return (if rarity then (if T.Rarity[rarity] then T.Rarity[rarity].Color else nil) else nil) or T.Colors.Surface
end

-- Ranks a batch so the summary can lead with the best pull. Lower is better;
-- the order mirrors Config.Cosmetics rarity weights without importing them,
-- because this is presentation ordering only and never decides a reward.
local RARITY_RANK = { Exclusive = 1, Legendary = 2, Rare = 3, Common = 4 }

local function rankOf(rarity: string?): number
	return (if rarity then RARITY_RANK[rarity] else nil) or 99
end

local function bestEntry(results: { any }): any?
	local best = nil
	for _, entry in results do
		if best == nil or rankOf(entry.rarity) < rankOf(best.rarity) then
			best = entry
		end
	end
	return best
end

local function burstRays(tier, color: Color3, alpha: any, zIndex: number)
	local rays = {}
	for index = 1, tier.rays do
		local angle = (index / tier.rays) * math.pi * 2
		rays[`Ray{index}`] = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = alpha:map(function(value: number)
				return math.clamp(1 - value, 0, 1)
			end),
			BorderSizePixel = 0,
			Position = alpha:map(function(value: number)
				local reach = 0.16 + (1 - value) * 0.42
				return UDim2.fromScale(0.5 + math.cos(angle) * reach, 0.5 + math.sin(angle) * reach)
			end),
			Rotation = math.deg(angle),
			Size = alpha:map(function(value: number)
				return UDim2.fromScale(0.06 + value * 0.05, 0.012)
			end),
			ZIndex = zIndex,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
	end
	return rays
end

-- What kind of item it is; the rarity is already on the card's tag.
local function kindOf(entry: any): string
	local category = if entry.preview then entry.preview.category else nil
	return (if category then InventoryConfig.ItemLabels[category] else nil) or ""
end

local function statusFor(entry: any): string
	if entry.isDupe then
		return if entry.bonksRefund > 0 then `DUPE · +{formatNumber(entry.bonksRefund)} BONKS` else "DUPE"
	end
	return "NEW ITEM"
end

-- The single reveal sizes its panel to its content (no dead band under the
-- title); landscape keeps at least this width so the card and info stack sit
-- side by side, and grows to the classic cap.
local SINGLE_MIN_WIDTH = 640
local SINGLE_MAX_WIDTH = 820
-- Hero name: fitted down from Tokens.Collectible.RevealNameMax to this floor,
-- wrapping to two lines before it truncates.
local HERO_NAME_MIN = T.Type.TileLabel
local INFO_GAP = 8

local function gridCell(entry, index, revealedCount, z, selected, onSelect, onInspect, width, height)
	local shown = index <= revealedCount
	return c(PuffyButton, {
		Color = T.Colors.SurfaceWarm,
		Radius = T.Shape.RadiusCard,
		Shadow = false,
		StrokeColor = if selected then T.Colors.Yellow else T.Colors.Ink,
		Enabled = shown and entry.preview ~= nil,
		OnActivated = function()
			onSelect(index)
			if onInspect then
				onInspect(entry.preview)
			end
		end,
		OnSelectionGained = function(button)
			onSelect(index)
			Selection.scrollIntoView(button)
		end,
		Native = { LayoutOrder = index, Size = UDim2.fromScale(1, 1), ZIndex = z },
	}, {
		Face = if shown
			then c(CollectibleFace, {
				Width = width,
				Height = height - T.Shape.LipHeight,
				Rarity = entry.rarity,
				Name = entry.displayName,
				Footer = statusFor(entry),
				ZIndex = z + 6,
				Art = c(ShopPreview, { Items = if entry.preview then { entry.preview } else {}, ZIndex = z + 7 }),
			})
			else nil,
	})
end

return function(props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local portrait = ResponsiveLayout.isPortrait(safeArea.size, UIConfig.Layout.PortraitMaxAspect)
	local panelSize = ResponsiveLayout.panelSize(
		safeArea.size,
		UIConfig.Layout.Panels.CrateReveal,
		UIConfig.Layout.PortraitMaxAspect,
		UIConfig.Layout.ShortLandscapeMaxHeightPx
	)
	local reveal = props.Reveal
	local buttonRef = React.useRef(nil)
	local modalRef = React.useRef(nil)
	local lastSelection = React.useRef(nil)
	local selectedIndex, setSelectedIndex = React.useState(nil :: number?)
	local reducedMotion = useReducedMotion()

	local results = if reveal then reveal.results else nil
	local count = if results then #results else 0
	local isBulk = count > 1
	if not isBulk and not portrait then
		-- Height here is the most the single may use; the panel is cut to its content below.
		panelSize = Vector2.new(
			math.min(safeArea.size.X - T.Layout.Inset * 2, math.max(panelSize.X, SINGLE_MIN_WIDTH), SINGLE_MAX_WIDTH),
			math.floor(safeArea.size.Y * 0.9)
		)
	end
	local headline = if results
		then (if selectedIndex then results[selectedIndex] else nil) or (if isBulk
			then bestEntry(results)
			else results[1])
		else nil
	local tier = tierFor(if headline then headline.rarity else nil)
	local color = rarityColor(if headline then headline.rarity else nil)

	local motion = useCrateRevealMotion(reveal, reducedMotion)
	local phase = motion.phase
	local revealedCount = motion.revealedCount
	local settled = phase == "Done" or (phase == "Item" and revealedCount >= count)
	local finish = motion.finish
	React.useEffect(function()
		setSelectedIndex(nil)
		lastSelection.current = nil
	end, { reveal })

	React.useEffect(function()
		if reveal == nil then
			return
		end
		local previous = GuiService.SelectedObject
		local modal = modalRef.current
		return function()
			local selected = GuiService.SelectedObject
			if
				(selected == nil or (modal ~= nil and selected:IsDescendantOf(modal)))
				and Selection.isSelectable(previous)
			then
				GuiService.SelectedObject = previous
			end
		end
	end, { reveal ~= nil })

	React.useEffect(function()
		if reveal == nil or props.FocusEnabled == false then
			return
		end
		local active = true
		task.defer(function()
			local button = if Selection.isSelectable(lastSelection.current)
				then lastSelection.current
				else buttonRef.current
			if active and Selection.isSelectable(button) then
				GuiService.SelectedObject = button
			end
		end)
		return function()
			active = false
			local selected = GuiService.SelectedObject
			if selected and modalRef.current and selected:IsDescendantOf(modalRef.current) then
				lastSelection.current = selected
			end
		end
	end, { reveal, props.FocusEnabled, settled })

	if reveal == nil or headline == nil then
		return nil
	end

	local building = phase == "Shake" or phase == "Landing" or phase == "Idle"
	local short = not portrait and panelSize.Y < 420
	local inset = if short then 16 else 22
	local actionHeight = if short then 44 else 54

	local preview = headline.preview
	local owned = preview ~= nil and CosmeticsLogic.isOwned(Cosmetics.Items, props.Owned or {}, preview.itemId)
	local equipped = preview ~= nil and (props.Equipped or {})[preview.category] == preview.itemId
	local busy = preview ~= nil and (props.BusySlots or {})[preview.category] == true
	local actions = {}
	if settled then
		if preview and props.OnEquipItem then
			table.insert(actions, {
				text = if not owned
					then "DELIVERING…"
					else if busy then "EQUIPPING…" else if equipped then "EQUIPPED" else "EQUIP",
				enabled = owned and not equipped and not busy,
				run = function()
					props.OnEquipItem(preview)
				end,
			})
		end
		if props.OnViewInventory then
			table.insert(actions, {
				text = "BACKPACK",
				enabled = true,
				focus = true,
				run = function()
					props.OnViewInventory(if preview then preview.category else nil)
				end,
			})
		else
			table.insert(actions, { text = "DONE", enabled = true, focus = true, run = props.OnClose })
		end
		if props.OnOpenAgain then
			table.insert(actions, {
				-- CAPS, no lowercase multiplier; the price sits on the button's own Bonks line.
				text = if props.OpenAgainCount and props.OpenAgainCount > 1
					then `OPEN {props.OpenAgainCount} MORE`
					elseif props.OpenAgainCount then "OPEN AGAIN"
					else string.upper(props.OpenAgainText or "OPEN AGAIN"),
				bonks = props.OpenAgainBonks,
				color = EconomyPalette.Pink,
				enabled = props.OpenAgainEnabled == true,
				run = props.OnOpenAgain,
			})
		end
	else
		table.insert(actions, { text = "SKIP", enabled = true, focus = true, run = finish })
	end
	-- The footer grid is laid out for the settled button set from the first frame,
	-- so the panel never changes size when SKIP gives way to the result actions.
	local settledCount = (if preview and props.OnEquipItem then 1 else 0) + 1 + (if props.OnOpenAgain then 1 else 0)
	local slots = math.max(#actions, settledCount)
	local columns = if portrait then math.min(2, slots) else slots
	local footerHeight = math.ceil(slots / columns) * (actionHeight + 12) - 12
	local title = if building then "OPENING..." else if isBulk then `YOU GOT {count} ITEMS` else "YOU GOT"
	local titleSize = T.Type.ModalTitle
	local titleWidth = panelSize.X - inset * 2 - 64
	local titleHeight = math.max(
		44,
		TextService:GetTextSize(title, titleSize, T.Type.Display, Vector2.new(math.max(titleWidth - 36, 1), 10000)).Y
			+ 12
	)
	-- The hint line under the title is reserved only when it shows (pity, batches).
	local hintLine = isBulk or reveal.pityTriggered ~= nil
	local bodyTop = inset + titleHeight + (if hintLine then 34 else T.Layout.CompactGap)
	local bodyHeight = math.max(44, panelSize.Y - bodyTop - footerHeight - inset * 2)
	-- Single reveal: one collectible card beside (or above) a composed info stack
	-- (status chip, fitted name, kind, inspect hint), centred together, with the
	-- panel cut to that content so nothing floats in dead space.
	local K = T.Collectible
	local contentWidth = panelSize.X - inset * 2
	local heroKind = kindOf(headline)
	local heroName = string.upper(headline.displayName)
	local heroHint = preview ~= nil and props.OnInspectItem ~= nil
	local kindHeight = if heroKind ~= "" then T.Type.Body + 4 else 0
	local hintHeight = if heroHint then T.Type.Minimum + 4 else 0
	local infoRows = 2 + (if heroKind ~= "" then 1 else 0) + (if heroHint then 1 else 0)
	local infoFixed = K.RevealChipHeight + kindHeight + hintHeight + INFO_GAP * (infoRows - 1)
	local nameTwoLines = HERO_NAME_MIN * 2 + 8
	local heroCard, heroCopyWidth, heroCopyHeight, heroLeft, heroTop, copyLeft, copyTop
	local heroNameSize, heroNameHeight = HERO_NAME_MIN, nameTwoLines
	local function fitName(width: number, maxHeight: number)
		heroNameSize = TextMetrics.fittingSize(
			heroName,
			T.Type.Display,
			Vector2.new(width, maxHeight),
			HERO_NAME_MIN,
			K.RevealNameMax,
			true
		)
		local measured = TextService:GetTextSize(heroName, heroNameSize, T.Type.Display, Vector2.new(width, 1000)).Y
		heroNameHeight = math.ceil(math.min(measured, maxHeight)) + 4
	end
	if not isBulk then
		local footerBlock = T.Layout.Gap + footerHeight + inset
		if portrait then
			heroCopyWidth = contentWidth
			heroCard = math.floor(math.min(K.RevealCardMax, contentWidth * 0.7))
			fitName(heroCopyWidth, K.RevealNameMax * 2 + 8)
			heroCopyHeight = infoFixed + heroNameHeight
			local overflow = bodyTop + heroCard + K.Pad * 2 + heroCopyHeight + footerBlock - panelSize.Y
			if overflow > 0 then
				heroCard = math.max(math.floor(heroCard - overflow), 120)
			end
			heroLeft = math.floor((panelSize.X - heroCard) / 2)
			heroTop = bodyTop
			copyLeft, copyTop = inset, bodyTop + heroCard + K.Pad * 2
			bodyHeight = heroCard + K.Pad * 2 + heroCopyHeight
		else
			local room = panelSize.Y - bodyTop - footerBlock
			heroCard = math.floor(math.min(K.RevealCardMax, room, contentWidth - K.RevealCopyMin - K.RevealGap))
			heroCard = math.max(heroCard, 96)
			heroCopyWidth = math.min(360, contentWidth - heroCard - K.RevealGap)
			fitName(heroCopyWidth, math.max(heroCard - infoFixed, nameTwoLines))
			heroCopyHeight = math.max(heroCard, infoFixed + heroNameHeight)
			local groupWidth = heroCard + K.RevealGap + heroCopyWidth
			-- Narrow the panel to the group so the pair reads centred, not adrift.
			panelSize = Vector2.new(
				math.min(panelSize.X, math.max(groupWidth + (inset + T.Layout.Gap) * 2, SINGLE_MIN_WIDTH)),
				panelSize.Y
			)
			heroLeft = math.floor((panelSize.X - groupWidth) / 2)
			heroTop = bodyTop + math.floor((heroCopyHeight - heroCard) / 2)
			copyLeft, copyTop = heroLeft + heroCard + K.RevealGap, bodyTop
			bodyHeight = heroCopyHeight
		end
		panelSize = Vector2.new(panelSize.X, math.min(panelSize.Y, bodyTop + bodyHeight + footerBlock))
	end
	titleWidth = panelSize.X - inset * 2 - 64
	-- Every footer button shares one label size, fitted to the narrowest label room.
	local buttonRoom =
		Vector2.new(panelSize.X * 0.9 / columns - UIConfig.Spacing.ControlGapPx - 20, actionHeight - T.Shape.LipHeight)
	local actionTextSize = UIConfig.Text.LabelPx
	for _, action in actions do
		local room = if action.bonks then Vector2.new(buttonRoom.X, buttonRoom.Y / 2) else buttonRoom
		actionTextSize = math.min(
			actionTextSize,
			TextMetrics.fittingSize(action.text, T.Type.Display, room, T.Type.Minimum, UIConfig.Text.LabelPx, false)
		)
	end
	local buttons = {}
	for index, action in actions do
		local row = math.floor((index - 1) / columns) + 1
		buttons[`Action{index}`] = c(ShopPriceButton, {
			TextSize = actionTextSize,
			ButtonRef = if action.focus then buttonRef else nil,
			Enabled = action.enabled,
			-- Equal widths; a short last row is centred instead of hugging the left.
			Position = UDim2.new(
				((index - 1) % columns + (columns - math.min(columns, #actions - (row - 1) * columns)) / 2 + 0.5)
					/ columns,
				0,
				0,
				(row - 1) * (actionHeight + 12) + actionHeight
			),
			Size = UDim2.new(1 / columns, -UIConfig.Spacing.ControlGapPx, 0, actionHeight),
			Text = action.text,
			Color = action.color or T.Colors.Surface,
			SubBonks = action.bonks,
			OnActivated = action.run,
			ZIndex = 114,
		})
	end
	local refundLine = if isBulk and reveal.totalRefund > 0
		then `{formatNumber(reveal.totalRefund)} BONKS REFUNDED FROM DUPLICATES`
		else nil

	return modalSurface({
		ref = modalRef,
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = T.Colors.Ink,
		BackgroundTransparency = 0.52,
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Visible = props.Visible ~= false,
		ZIndex = 111,
		[React.Event.Activated] = function()
			if not settled then
				finish()
			end
		end,
	}, {
		Panel = c(OuchPanel, {
			Padding = 0,
			Gloss = true,
			Native = {
				SelectionGroup = true,
				SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
				SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
				SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
				SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = UIConfig.Layout.PageSurface.Image,
				ImageColor3 = EconomyPalette.White,
				Position = UDim2.fromScale(0.5, 0.53),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromOffset(panelSize.X, panelSize.Y),
				SliceCenter = UIConfig.Layout.PageSurface.SliceCenter,
				SliceScale = UIConfig.Layout.PageSurface.SliceScale,
				ZIndex = 112,
			},
		}, {
			Opening = if building
				then c("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0, bodyTop + bodyHeight / 2),
					Size = UDim2.fromOffset(math.min(bodyHeight, 240), math.min(bodyHeight, 240)),
					ZIndex = 114,
				}, { Glow = c(CrateOpeningGlow, { Motion = motion }) })
				else nil,
			Close = c(ModalClose, {
				OnActivated = props.OnClose,
				Position = UDim2.new(1, -12, 0, 12),
				SizePx = 44,
				ZIndex = 118,
			}),
			Burst = if phase == "Burst"
					or phase == "Item"
					or phase == "Done"
				then c("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 116,
				}, burstRays(tier, color, motion.burst, 116))
				else nil,
			Flash = c("Frame", {
				BackgroundColor3 = T.Colors.Surface,
				BackgroundTransparency = motion.burst:map(function(alpha: number)
					return math.clamp(1 - alpha * 0.15, 0, 1)
				end),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Visible = phase == "Burst",
				ZIndex = 117,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusPanel) }),
			}),
			Title = c(CandyTitle, {
				Text = title,
				TextSize = titleSize,
				Native = {
					Position = UDim2.fromOffset(inset, inset),
					Size = UDim2.fromOffset(titleWidth, titleHeight),
					ZIndex = 114,
				},
			}),
			Pity = if not building and (isBulk or reveal.pityTriggered)
				then c(ResponsiveText, {
					MeasurementFont = T.Type.Label,
					MaxTextSize = 20,
					MinTextSize = T.Type.Minimum,
					Wrapped = true,
					Truncate = true,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Font = T.Type.Label,
						Position = UDim2.new(0.5, 0, 0, bodyTop - 30),
						Size = UDim2.new(0.88, 0, 0, 28),
						Text = if reveal.pityTriggered
							then `PITY · GUARANTEED {string.upper(reveal.pityTriggered)}`
							else "SELECT TO INSPECT",
						TextColor3 = T.Colors.InkSoft,
						ZIndex = 115,
					},
				})
				else nil,
			Single = if not isBulk
				then c(PuffyButton, {
					Radius = T.Shape.RadiusCard,
					Shadow = false,
					Color = T.Colors.SurfaceWarm,
					StrokeColor = T.Colors.Ink,
					Enabled = settled and preview ~= nil and props.OnInspectItem ~= nil,
					OnActivated = function()
						props.OnInspectItem(preview)
					end,
					Native = {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(heroLeft, heroTop),
						Size = UDim2.fromOffset(heroCard, heroCard),
						Visible = revealedCount >= 1,
						ZIndex = 113,
					},
				}, {
					Face = c(CollectibleFace, {
						Width = heroCard,
						Height = heroCard - T.Shape.LipHeight,
						Rarity = headline.rarity,
						ZIndex = 119,
						Art = c(ShopPreview, {
							Items = if headline.preview then { headline.preview } else {},
							Thumbnail = "",
							Playing = settled,
							ZIndex = 120,
						}),
					}),
				})
				else nil,
			-- The info stack reads top-down as one block: status chip, name, kind, then the inspect hint.
			Info = if not isBulk and settled
				then c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(copyLeft, copyTop),
					Size = UDim2.fromOffset(heroCopyWidth, heroCopyHeight),
					ZIndex = 114,
				}, {
					Layout = c("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = if portrait
							then Enum.HorizontalAlignment.Center
							else Enum.HorizontalAlignment.Left,
						VerticalAlignment = if portrait
							then Enum.VerticalAlignment.Top
							else Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, INFO_GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Status = c(Ribbon, {
						Text = statusFor(headline),
						Color = if headline.isDupe then T.Colors.Surface else T.Colors.Lime,
						Native = {
							LayoutOrder = 1,
							Size = UDim2.fromOffset(
								CollectibleLayout.tagWidth(statusFor(headline), T.Type.Minimum, heroCopyWidth),
								K.RevealChipHeight
							),
							ZIndex = 115,
						},
					}),
					-- Fitted to the column (40 down to 22, two lines, then truncation), so a
					-- long name stays inside the panel instead of overflowing it.
					Name = c("TextLabel", {
						BackgroundTransparency = 1,
						Font = T.Type.Display,
						LayoutOrder = 2,
						Size = UDim2.fromOffset(heroCopyWidth, heroNameHeight),
						Text = heroName,
						TextColor3 = T.Colors.Ink,
						TextSize = heroNameSize,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextWrapped = true,
						TextXAlignment = if portrait then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
						ZIndex = 115,
					}),
					Kind = if heroKind ~= ""
						then c("TextLabel", {
							BackgroundTransparency = 1,
							Font = T.Type.Label,
							LayoutOrder = 3,
							Size = UDim2.fromOffset(heroCopyWidth, T.Type.Body + 4),
							Text = heroKind,
							TextColor3 = T.Colors.InkSoft,
							TextSize = T.Type.Body,
							TextTruncate = Enum.TextTruncate.AtEnd,
							TextXAlignment = if portrait then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
							ZIndex = 115,
						})
						else nil,
					Hint = if heroHint
						then c("TextLabel", {
							BackgroundTransparency = 1,
							Font = T.Type.Label,
							LayoutOrder = 4,
							Size = UDim2.fromOffset(heroCopyWidth, T.Type.Minimum + 4),
							Text = "SELECT THE CARD TO INSPECT",
							TextColor3 = T.Colors.InkSoft,
							TextSize = T.Type.Minimum,
							TextTruncate = Enum.TextTruncate.AtEnd,
							TextXAlignment = if portrait then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
							ZIndex = 115,
						})
						else nil,
				})
				else nil,
			Grid = if isBulk
				then c(
					"ScrollingFrame",
					{
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						CanvasSize = UDim2.fromOffset(0, 0),
						Position = UDim2.new(0.06, 0, 0, bodyTop),
						ScrollBarImageTransparency = 0.2,
						ScrollBarThickness = T.Layout.ScrollBar,
						ScrollBarImageColor3 = T.Colors.Pink,
						Size = UDim2.new(0.88, 0, 0, math.max(44, bodyHeight - (if refundLine then 40 else 0))),
						VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
						ZIndex = 113,
					},
					(function()
						local gridWidth = panelSize.X * 0.88 - T.Layout.ScrollBar - 4
						local gridColumns = math.max(1, math.floor(gridWidth / 200))
						local cellWidth = math.floor(gridWidth / gridColumns) - 10
						local cells: { [string]: any } = {
							Layout = c("UIGridLayout", {
								CellPadding = UDim2.fromOffset(10, 10),
								CellSize = UDim2.fromOffset(cellWidth, 260),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							Padding = c("UIPadding", {
								PaddingTop = UDim.new(0, T.Shape.StrokeCard),
								PaddingLeft = UDim.new(0, T.Shape.StrokeCard),
							}),
						}
						for index, entry in results :: { any } do
							cells[`Cell{index}`] = gridCell(
								entry,
								index,
								revealedCount,
								114,
								entry == headline,
								setSelectedIndex,
								props.OnInspectItem,
								cellWidth,
								260
							)
						end
						return cells
					end)()
				)
				else nil,
			Refunds = if isBulk
					and settled
					and refundLine
				then c(ResponsiveText, {
					MeasurementFont = T.Type.Label,
					MaxTextSize = T.Type.Body,
					MinTextSize = T.Type.Minimum,
					Truncate = true,
					Native = {
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Font = T.Type.Label,
						Position = UDim2.new(0.5, 0, 0, bodyTop + bodyHeight),
						Size = UDim2.new(0.88, 0, 0, 30),
						Text = refundLine,
						TextColor3 = T.Colors.Ink,
						ZIndex = 114,
					},
				})
				else nil,
			Actions = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 1, -inset),
				Size = UDim2.new(0.9, 0, 0, footerHeight),
				ZIndex = 114,
			}, buttons),
		}),
	})
end
