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
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveText = require(script.Parent.ResponsiveText)
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
	return (if rarity then (if T.Rarity[rarity] then T.Rarity[rarity].Color else nil) else nil) or Color3.new(1, 1, 1)
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

local function subtitleFor(entry: any): string
	if entry.isDupe then
		return if entry.bonksRefund > 0 then `DUPLICATE  •  +{formatNumber(entry.bonksRefund)} BONKS` else "DUPLICATE"
	end
	return string.upper(entry.rarity)
end

local function gridCell(entry, index, revealedCount, z, selected, onSelect, onInspect)
	local shown = index <= revealedCount
	local tier = T.Rarity[entry.rarity]
	return c(PuffyButton, {
		Color = T.Colors.Surface,
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
		Rarity = if shown
			then c(Ribbon, {
				Rarity = entry.rarity,
				Color = if tier then tier.Color else nil,
				Native = { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 26), ZIndex = z + 6 },
			})
			else nil,
		Preview = if shown
			then c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(8, 42),
				Size = UDim2.new(1, -16, 1, -162),
				ZIndex = z + 6,
			}, {
				Content = c(ShopPreview, { Items = if entry.preview then { entry.preview } else {}, ZIndex = z + 6 }),
			})
			else nil,
		Name = c("TextLabel", {
			BackgroundColor3 = T.Colors.Ink,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 1, -112),
			Size = UDim2.new(1, -16, 0, 52),
			Font = T.Type.Display,
			Text = if shown then string.upper(entry.displayName) else "…",
			TextSize = T.Type.Minimum,
			TextColor3 = T.Colors.Surface,
			TextWrapped = true,
			ZIndex = z + 7,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }) }),
		Status = c("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 1, -52),
			Size = UDim2.new(1, -16, 0, 44),
			Font = T.Type.Label,
			Text = if not shown
				then ""
				elseif entry.isDupe then "+" .. formatNumber(entry.bonksRefund) .. " BONKS · DUPE"
				else "NEW ITEM",
			TextSize = T.Type.Minimum,
			TextColor3 = T.Colors.Ink,
			TextWrapped = true,
			ZIndex = z + 7,
		}),
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
		panelSize = Vector2.new(math.min(panelSize.X, 820), math.min(panelSize.Y, 440))
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
				text = if props.OpenAgainCount
					then `AGAIN {props.OpenAgainCount}x`
					else props.OpenAgainText or "OPEN AGAIN",
				bonks = props.OpenAgainBonks,
				color = EconomyPalette.Pink,
				enabled = props.OpenAgainEnabled == true,
				run = props.OnOpenAgain,
			})
		end
	else
		table.insert(actions, { text = "SKIP", enabled = true, focus = true, run = finish })
	end
	local columns = if portrait then math.min(2, #actions) else #actions
	local footerHeight = math.ceil(#actions / columns) * (actionHeight + 12) - 12
	local title = if building then "OPENING..." else if isBulk then `YOU GOT {count} ITEMS` else "YOU GOT"
	local titleSize = if portrait or short then 26 else 36
	local titleWidth = panelSize.X - inset * 2 - 64
	local titleHeight = math.max(
		44,
		TextService:GetTextSize(title, titleSize, T.Type.Display, Vector2.new(math.max(titleWidth - 36, 1), 10000)).Y
			+ 12
	)
	local bodyTop = inset + titleHeight + 34
	local bodyHeight = math.max(44, panelSize.Y - bodyTop - footerHeight - inset * 2)
	local singleArtSize =
		math.min(240, panelSize.X * (if portrait then 0.68 else 0.44), bodyHeight * (if portrait then 0.6 else 1))
	local buttons = {}
	for index, action in actions do
		buttons[`Action{index}`] = c(ShopPriceButton, {
			TextSize = UIConfig.Text.LabelPx,
			ButtonRef = if action.focus then buttonRef else nil,
			Enabled = action.enabled,
			Position = UDim2.new(
				((index - 1) % columns + 0.5) / columns,
				0,
				0,
				math.floor((index - 1) / columns) * (actionHeight + 12) + actionHeight
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
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = motion.burst:map(function(alpha: number)
					return math.clamp(1 - alpha * 0.15, 0, 1)
				end),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Visible = phase == "Burst",
				ZIndex = 117,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Panel.RadiusPx) }),
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
			Pity = if not building
				then c(ResponsiveText, {
					MeasurementFont = T.Type.Label,
					MaxTextSize = 20,
					MinTextSize = T.Type.Minimum,
					Wrapped = true,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/SourceSansPro.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.new(0.5, 0, 0, bodyTop - 30),
						Size = UDim2.new(0.88, 0, 0, 28),
						Text = if reveal.pityTriggered
							then `PITY  •  GUARANTEED {string.upper(reveal.pityTriggered)}`
							else "SELECT TO INSPECT",
						TextColor3 = T.Colors.Ink,
						ZIndex = 115,
					},
				})
				else nil,
			Single = if not isBulk
				then c(PuffyButton, {
					Radius = T.Shape.RadiusCard,
					Shadow = false,
					Color = T.Colors.Well,
					Enabled = settled and preview ~= nil and props.OnInspectItem ~= nil,
					OnActivated = function()
						props.OnInspectItem(preview)
					end,
					Native = {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(
							if portrait then 0.5 else 0.26,
							0,
							0,
							bodyTop + bodyHeight * (if portrait then 0.32 else 0.5)
						),
						Size = UDim2.fromOffset(singleArtSize, singleArtSize),
						Visible = revealedCount >= 1,
						ZIndex = 113,
					},
				}, {
					Content = c(ShopPreview, {
						Items = if headline.preview then { headline.preview } else {},
						Thumbnail = "",
						ZIndex = 120,
					}),
					Rarity = c(Ribbon, {
						Rarity = headline.rarity,
						Native = {
							Position = UDim2.fromOffset(8, 8),
							Size = UDim2.new(1, -16, 0, 44),
							ZIndex = 121,
						},
					}),
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
						ScrollBarThickness = 8,
						ScrollBarImageColor3 = T.Colors.Pink,
						Size = UDim2.new(0.88, 0, 0, math.max(44, bodyHeight - 86)),
						VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
						ZIndex = 113,
					},
					(function()
						local cells: { [string]: any } = {
							Layout = c("UIGridLayout", {
								CellPadding = UDim2.fromOffset(10, 10),
								CellSize = UDim2.new(
									1 / math.max(1, math.floor((panelSize.X * 0.88) / 200)),
									-10,
									0,
									260
								),
								SortOrder = Enum.SortOrder.LayoutOrder,
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
								props.OnInspectItem
							)
						end
						return cells
					end)()
				)
				else nil,
			Name = c(ResponsiveText, {
				MeasurementFont = Enum.Font.FredokaOne,
				MaxTextSize = if isBulk then 22 else 32,
				MinTextSize = T.Type.Minimum,
				Wrapped = true,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.new(
						if isBulk or portrait then 0.5 else 0.73,
						0,
						0,
						bodyTop
							+ (
								if isBulk
									then bodyHeight - 80
									elseif not short and not portrait then bodyHeight / 2 - 50
									else bodyHeight * (if portrait then 0.64 else 0.18)
							)
					),
					Size = UDim2.new(
						if isBulk or portrait then 0.9 else 0.44,
						0,
						0,
						if isBulk
							then 30
							elseif not short and not portrait then 76
							else bodyHeight * (if portrait then 0.22 else 0.44)
					),
					Text = if settled then string.upper(headline.displayName) else "",
					TextColor3 = T.Colors.Ink,
					ZIndex = 114,
				},
			}, {
				Outline = c("UIStroke", {
					Color = EconomyPalette.Ink,
					Thickness = 0,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				}),
			}),
			Subtitle = c(ResponsiveText, {
				MeasurementFont = T.Type.Label,
				MaxTextSize = 22,
				MinTextSize = T.Type.Minimum,
				Wrapped = true,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.new(
						if isBulk or portrait then 0.5 else 0.73,
						0,
						0,
						bodyTop
							+ (
								if isBulk
									then bodyHeight - 46
									elseif not short and not portrait then bodyHeight / 2 + 34
									else bodyHeight * (if portrait then 0.86 else 0.66)
							)
					),
					Size = UDim2.new(
						if isBulk or portrait then 0.88 else 0.44,
						0,
						0,
						if isBulk
							then 44
							elseif not short and not portrait then 28
							else bodyHeight * (if portrait then 0.14 else 0.25)
					),
					Text = if not settled
						then ""
						else if isBulk and refundLine then refundLine else subtitleFor(headline),
					TextColor3 = T.Colors.Ink,
					ZIndex = 114,
				},
			}),
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
