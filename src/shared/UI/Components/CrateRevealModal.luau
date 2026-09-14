-- Description: Short candy-glow build, landing and reward reveal, with skip, replay and duplicate-refund reporting.

--!strict

local formatNumber = require(script.Parent.Parent.Models.NumberText)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local useCrateRevealMotion = require(script.Parent.Parent.Hooks.useCrateRevealMotion)
local CrateOpeningGlow = require(script.Parent.CrateOpeningGlow)
local OuchPanel = require(script.Parent.OuchPanel)
local OuchButton = require(script.Parent.OuchButton)
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local InventoryConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory"))
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local ResponsiveText = require(script.Parent.OuchText)
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local Selection = require(script.Parent.Parent.Services.Selection)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local CosmeticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic")
)
local AnimatedButton = require(script.Parent.AnimatedButton)

local modalSurface = require(script.Parent.ModalSurface)

local ModalClose = require(script.Parent.ModalClose)

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
	return (if rarity then InventoryConfig.RarityColors[rarity] else nil) or Color3.new(1, 1, 1)
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

local function gridCell(entry: any, index: number, revealedCount: number, zIndex: number, selected, onSelect, onInspect)
	local shown = index <= revealedCount
	local color = rarityColor(entry.rarity)
	return c(AnimatedButton, {
		SelectionRadius = UDim.new(0, UIConfig.Radius.Control),
		Visual = c(
			OuchButton,
			{ Color = if selected then UIConfig.ProgressionStyle.Pink else UIConfig.ProgressionStyle.Cyan }
		),
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
		Native = {
			BackgroundColor3 = color,
			BackgroundTransparency = if shown then 0.25 else 0.85,
			BorderSizePixel = 0,
			LayoutOrder = index,
			ZIndex = zIndex,
		},
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Control) }),
		Stroke = c("UIStroke", {
			Color = if selected then Color3.new(1, 1, 1) else color,
			Thickness = if selected then 3 else if shown then 2 else 0,
			Transparency = if shown then 0.1 else 1,
		}),
		Preview = if shown
			then c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.1, 0.06),
				Size = UDim2.fromScale(0.8, 0.6),
				ZIndex = zIndex + 1,
			}, {
				Content = c(ShopPreview, {
					Items = if entry.preview then { entry.preview } else {},
					Thumbnail = "",
					ZIndex = zIndex + 1,
				}),
			})
			else nil,
		Label = if shown
			then c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = 18,
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/SourceSansPro.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.5, 0.98),
					Size = UDim2.fromScale(0.92, 0.28),
					Text = if entry.isDupe
						then `+{formatNumber(entry.bonksRefund)}`
						else string.upper(entry.displayName),
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = zIndex + 2,
				},
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
		panelSize = Vector2.new(math.min(panelSize.X, 820), math.min(panelSize.Y, 440))
	end
	local headline = if results
		then (if selectedIndex then results[selectedIndex] else nil) or (if isBulk
			then bestEntry(results)
			else results[1])
		else nil
	local tier = tierFor(if headline then headline.rarity else nil)
	local color = UIConfig.ProgressionStyle.Yellow

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
	local bodyTop = if short then 56 else 76
	local bodyHeight = math.max(44, panelSize.Y - bodyTop - actionHeight - inset * 2)
	local singleArtSize =
		math.min(240, panelSize.X * (if portrait then 0.68 else 0.44), bodyHeight * (if portrait then 0.64 else 1))
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
				color = UIConfig.ProgressionStyle.Pink,
				enabled = props.OpenAgainEnabled == true,
				run = props.OnOpenAgain,
			})
		end
	else
		table.insert(actions, { text = "SKIP", enabled = true, focus = true, run = finish })
	end
	local buttons = {}
	for index, action in actions do
		buttons[`Action{index}`] = c(ShopPriceButton, {
			TextSize = UIConfig.Text.LabelPx,
			ButtonRef = if action.focus then buttonRef else nil,
			Enabled = action.enabled,
			Position = UDim2.fromScale((index - 0.5) / #actions, 1),
			Size = UDim2.new(1 / #actions, -UIConfig.Spacing.ControlGapPx, 0, actionHeight),
			Text = action.text,
			Color = action.color or UIConfig.ProgressionStyle.Cyan,
			SubBonks = action.bonks,
			OnActivated = action.run,
			ZIndex = 114,
		})
	end
	local title = if building then "OPENING..." else if isBulk then `YOU GOT {count} ITEMS` else "YOU GOT"
	local refundLine = if isBulk and reveal.totalRefund > 0
		then `{formatNumber(reveal.totalRefund)} BONKS REFUNDED FROM DUPLICATES`
		else nil

	return modalSurface({
		ref = modalRef,
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(),
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
				ImageColor3 = UIConfig.ProgressionStyle.White,
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
			Title = c(ResponsiveText, {
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 46,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromOffset(panelSize.X * 0.5, inset),
					Size = UDim2.new(0.8, -24, 0, if short then 26 else 34),
					Text = title,
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 114,
				},
			}, {
				Pulse = c("UIScale", { Scale = if building then motion.pulse else 1 }),
				Outline = c("UIStroke", {
					Color = UIConfig.ProgressionStyle.Ink,
					Thickness = 0.045,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				}),
			}),
			Pity = if not building
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					MaxTextSize = 20,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/SourceSansPro.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.new(0.5, 0, 0, bodyTop - 20),
						Size = UDim2.new(0.88, 0, 0, 18),
						Text = if reveal.pityTriggered
							then `PITY  •  GUARANTEED {string.upper(reveal.pityTriggered)}`
							else "SELECT A REWARD TO INSPECT",
						TextColor3 = UIConfig.ProgressionStyle.Yellow,
						ZIndex = 115,
					},
				})
				else nil,
			Single = if not isBulk
				then c(AnimatedButton, {
					SelectionRadius = UDim.new(0, UIConfig.Radius.Control),
					Visual = c(OuchButton, { Color = UIConfig.ProgressionStyle.PanelRaised }),
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
						ZIndex = 113,
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
						ScrollBarThickness = 5,
						Size = UDim2.new(0.88, 0, 0, math.max(44, bodyHeight - 42)),
						VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
						ZIndex = 113,
					},
					(function()
						local cells: { [string]: any } = {
							Layout = c("UIGridLayout", {
								CellPadding = UDim2.fromOffset(6, 6),
								CellSize = if portrait
									then UDim2.new(1 / 3, -6, 0, 112)
									else UDim2.new(1 / 5, -6, 0, if short then 78 else 112),
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
				MeasurementFont = Enum.Font.LuckiestGuy,
				MaxTextSize = 42,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.new(
						if isBulk or portrait then 0.5 else 0.73,
						0,
						0,
						bodyTop
							+ (
								if isBulk
									then bodyHeight - 40
									elseif not short and not portrait then bodyHeight / 2 - 50
									else bodyHeight * (if portrait then 0.64 else 0.18)
							)
					),
					Size = UDim2.new(
						if isBulk or portrait then 0.9 else 0.44,
						0,
						0,
						if isBulk
							then 22
							elseif not short and not portrait then 76
							else bodyHeight * (if portrait then 0.22 else 0.44)
					),
					Text = if settled then string.upper(headline.displayName) else "",
					TextColor3 = Color3.new(1, 1, 1),
					ZIndex = 114,
				},
			}, {
				Outline = c("UIStroke", {
					Color = UIConfig.ProgressionStyle.Ink,
					Thickness = 0.045,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				}),
			}),
			Subtitle = c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MaxTextSize = 25,
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
									then bodyHeight - 18
									elseif not short and not portrait then bodyHeight / 2 + 34
									else bodyHeight * (if portrait then 0.86 else 0.66)
							)
					),
					Size = UDim2.new(
						if isBulk or portrait then 0.88 else 0.44,
						0,
						0,
						if isBulk
							then 18
							elseif not short and not portrait then 28
							else bodyHeight * (if portrait then 0.14 else 0.25)
					),
					Text = if not settled
						then ""
						else if isBulk and refundLine then refundLine else subtitleFor(headline),
					TextColor3 = if isBulk then UIConfig.ProgressionStyle.Yellow else Color3.new(1, 1, 1),
					ZIndex = 114,
				},
			}),
			Actions = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 1, -inset),
				Size = UDim2.new(0.9, 0, 0, actionHeight),
				ZIndex = 114,
			}, buttons),
		}),
	})
end
