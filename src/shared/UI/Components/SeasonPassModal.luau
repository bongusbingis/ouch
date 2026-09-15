--!strict
local T = require(script.Parent.Parent.Tokens)
-- Season progression and premium access are distinct actions using the existing economy controller.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Shop"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local ItemLabels =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Inventory")).ItemLabels
local Model = require(script.Parent.Parent.Models.SeasonRewardsModel)
local Claims = require(script.Parent.Parent.Models.SeasonClaims)
local Selection = require(script.Parent.Parent.Services.Selection)
local DeviceClass = require(script.Parent.Parent.Parent.Game.Input.DeviceClass)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local ResponsiveText = require(script.Parent.ResponsiveText)
local PageTitle = require(script.Parent.CandyTitle)
local PriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local Rewards = require(script.Parent.SeasonRewardsPanel)
local Progress = require(script.Parent.CandyProgressBar)
local formatNumber = require(script.Parent.Parent.Models.NumberText)
local modalSurface = require(script.Parent.ModalSurface)

local Well = require(script.Parent.Well)
local Ribbon = require(script.Parent.RarityRibbon)
local Layout = require(script.Parent.Parent.Models.SeasonLayout)
local S = T.SeasonRewards

local c = React.createElement
local CandyPanel = require(script.Parent.CandyPanel)
local colors = require(script.Parent.Parent.EconomyPalette)

local function label(text, position, size, maximum, color, heading, alignment)
	return c(ResponsiveText, {
		MeasurementFont = if heading then Enum.Font.FredokaOne else T.Type.Label,
		MaxTextSize = math.max(T.Type.Minimum, maximum),
		MinTextSize = T.Type.Minimum,
		Wrapped = true,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Text = text,
			Font = if heading then Enum.Font.FredokaOne else T.Type.Label,
			TextColor3 = if color == colors.White or color == colors.Yellow
				then T.Colors.Ink
				else color or T.Colors.Ink,
			TextStrokeColor3 = colors.Ink,
			TextStrokeTransparency = 1,
			TextWrapped = true,
			TextXAlignment = alignment or Enum.TextXAlignment.Left,
			ZIndex = 105,
		},
	}, {
		Outline = if heading and color ~= colors.Ink
			then c("UIStroke", {
				Color = T.Colors.Surface,
				Thickness = 0,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			})
			else nil,
	})
end

return function(props)
	local safe = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local short = safe.size.Y < S.ShortHeight
	local compact = short or safe.size.X - S.Edge * 2 < 760
	local card = props.Card
	local state = props.SeasonState
	local ready = state ~= nil and state.seasonId == card.definition.SeasonId
	local loading = state == nil
	local seasonActive = ready and state.active == true
	local ended = ready and not seasonActive and state.endsAt ~= nil and state.endsAt <= workspace:GetServerTimeNow()
	local unavailableText = if ended then "SEASON ENDED" else "SEASON UNAVAILABLE"
	local entries = Model.entries(if ready then state else nil)
	local selectedKey, setSelectedKey = React.useState(nil)
	local previewOpen, setPreviewOpen = React.useState(false)
	local selected = Model.selected(entries, selectedKey)
	local closeRef, claimRef = React.useRef(nil), React.useRef(nil)
	React.useEffect(function()
		setSelectedKey(nil)
		setPreviewOpen(false)
	end, { card.id })
	React.useLayoutEffect(function()
		local backRef = props.BackRef
		if not backRef then
			return
		end
		local function back()
			if props.FocusEnabled ~= false and compact and previewOpen then
				setPreviewOpen(false)
				return true
			end
			return false
		end
		backRef.current = back
		return function()
			if backRef.current == back then
				backRef.current = nil
			end
		end
	end, { props.BackRef, compact, previewOpen, props.FocusEnabled })
	React.useEffect(function()
		if props.FocusEnabled == false then
			return
		end
		local previous = GuiService.SelectedObject
		local panel = if closeRef.current then closeRef.current.Parent else nil
		local active = true
		local function focus()
			if not active or DeviceClass.current() ~= "Gamepad" then
				return
			end
			local button = if Selection.isSelectable(claimRef.current) then claimRef.current else closeRef.current
			if not Selection.isSelectable(button) then
				return
			end
			local focused = GuiService.SelectedObject
			if focused and not focused:IsDescendantOf(Players.LocalPlayer.PlayerGui) then
				return
			end
			local ownRoot = button:FindFirstAncestorWhichIsA("ScreenGui")
			local selectedRoot = if focused then focused:FindFirstAncestorWhichIsA("ScreenGui") else nil
			if selectedRoot and ownRoot and selectedRoot.DisplayOrder > ownRoot.DisplayOrder then
				return
			end
			if not (focused and panel and focused:IsDescendantOf(panel) and Selection.isSelectable(focused)) then
				GuiService.SelectedObject = button
			end
		end
		local disconnect = DeviceClass.observe(function(input)
			if input == "Gamepad" then
				task.defer(focus)
			end
		end)
		return function()
			active = false
			disconnect()
			local focused = GuiService.SelectedObject
			if
				DeviceClass.current() == "Gamepad"
				and (focused == nil or (panel and focused:IsDescendantOf(panel)))
				and Selection.isSelectable(previous)
			then
				GuiService.SelectedObject = previous
			end
		end
	end, { card.id, props.FocusEnabled })
	local claimable = if seasonActive then Claims.count(state) else 0
	local premiumOwned = ready and state.hasPremium
	local showPremium = seasonActive and not premiumOwned
	local canBuy = seasonActive
		and not premiumOwned
		and card.status == "Active"
		and card.robuxPrice ~= nil
		and card.productId ~= nil
		and not card.pending
	local layout = Layout.resolve(safe.size, showPremium)
	local width, height, inset = layout.width, layout.height, layout.inset
	local bodyHeight = layout.bodyHeight
	local previewVisible = selected ~= nil and (not compact or previewOpen)
	local tier = if ready then state.tier or 0 else 0
	local xp = if ready then state.xpIntoTier or 0 else 0
	local target = if ready then state.xpForNextTier or 1 else 1
	local complete = ready and tier >= state.tierCount
	local progress = if complete then 1 else math.clamp(xp / math.max(target, 1), 0, 1)
	local definition = if selected and selected.itemId then Cosmetics.Items[selected.itemId] else nil
	local name = if definition
		then definition.DisplayName
		else if selected then `{formatNumber(selected.amount or 0)} BONKS` else "SEASON REWARDS"
	local previewItems = if definition
		then { { itemId = selected.itemId, category = definition.Category, definition = definition } }
		else {}
	local progressText = if loading
		then "LOADING REWARDS..."
		else if not seasonActive
			then unavailableText
			else if complete
				then "ALL TIERS EARNED"
				else `{formatNumber(math.max(target - xp, 0))} XP TO TIER {tier + 1}`
	local requirement = if selected
		then (if not seasonActive and not selected.claimed then unavailableText else Model.requirement(selected))
		else ""
	local previewDetails = S.PreviewDetailsHeight
	local previewArtHeight = math.min(S.PreviewArtMaxHeight, math.max(40, bodyHeight - previewDetails - 88))
	local claimText = if props.ClaimPending
		then "CLAIMING..."
		else if loading
			then "LOADING REWARDS..."
			else if not seasonActive
				then unavailableText
				else if claimable > 0 then `CLAIM ALL ({claimable})` else "NOTHING TO CLAIM"
	local stackedActions = layout.portrait and showPremium
	local actionHeight = if short then S.ShortFooterHeight else if compact then 52 else 56
	local claimWidth = if stackedActions
		then layout.innerWidth
		else if showPremium
			then (layout.innerWidth - layout.gap) / 2
			else if compact then layout.innerWidth else math.min(360, layout.innerWidth * 0.46)
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 100 }, {
		Dim = modalSurface({
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			BackgroundColor3 = T.Colors.Ink,
			BackgroundTransparency = 0.4,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 100,
		}),
		Panel = c(CandyPanel, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(safe.position.X + safe.size.X / 2, safe.position.Y + safe.size.Y / 2),
			Size = UDim2.fromOffset(width, height),
			Tilt = S.PanelTilt,
			ZIndex = 102,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		}, {
			Title = c(PageTitle, {
				Tilt = if short then 0 else nil,
				Text = if ready then string.upper(state.displayName) else "SEASON REWARDS",
				TextSize = if short then 24 else if layout.portrait then 26 else 34,
				Native = {
					Position = UDim2.fromOffset(inset, inset),
					Size = UDim2.new(1, -inset * 2 - 120, 0, layout.titleHeight),
					ZIndex = 105,
				},
			}),
			Back = c(PriceButton, {
				Color = T.Colors.Surface,
				ButtonRef = closeRef,
				Text = if compact and previewOpen then "REWARDS" else "BACK",
				TextSize = 18,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -inset, 0, inset + (if short then 0 else 4)),
				Size = UDim2.fromOffset(104, 44),
				ZIndex = 106,
				OnActivated = function()
					if compact and previewOpen then
						setPreviewOpen(false)
					else
						props.OnClose()
					end
				end,
			}),
			Status = c(Well, {
				Candy = true,
				Native = {
					Position = UDim2.fromOffset(inset, layout.statusTop),
					Size = UDim2.new(1, -inset * 2, 0, layout.statusHeight),
					ZIndex = 103,
				},
			}, {
				Tier = if not short
					then c("Frame", {
						BackgroundColor3 = T.Colors.Pink,
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(10, 6),
						Size = UDim2.fromOffset(56, 52),
						ZIndex = 104,
					}, {
						Corner = c("UICorner", { CornerRadius = UDim.new(0, 14) }),
						Label = label(
							"TIER",
							UDim2.fromOffset(0, 2),
							UDim2.new(1, 0, 0, 20),
							18,
							T.Colors.Ink,
							false,
							Enum.TextXAlignment.Center
						),
						Number = label(
							if ready then tostring(tier) else "-",
							UDim2.fromOffset(0, 22),
							UDim2.new(1, 0, 0, 28),
							28,
							T.Colors.Ink,
							true,
							Enum.TextXAlignment.Center
						),
					})
					else nil,
				ProgressLabel = label(
					if short and seasonActive then `TIER {tier}  •  {progressText}` else progressText,
					UDim2.fromOffset(if short then 10 else 82, if short then 0 else 8),
					UDim2.new(1, if short then -20 else -96, 0, 24),
					18,
					T.Colors.Ink,
					false
				),
				Progress = c(Progress, {
					Progress = progress,
					Native = {
						Visible = seasonActive,
						Position = UDim2.fromOffset(if short then 10 else 82, if short then 24 else 40),
						Size = UDim2.new(1, if short then -20 else -98, 0, if short then 6 else 14),
						ZIndex = 104,
					},
				}),
			}),
			Body = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(inset, layout.bodyTop),
				Size = UDim2.fromOffset(layout.innerWidth, bodyHeight),
				ZIndex = 103,
			}, {
				Status = if not loading and not ready
					then label(
						unavailableText,
						UDim2.fromScale(0, 0.35),
						UDim2.fromScale(1, 0.3),
						30,
						T.Colors.Ink,
						true,
						Enum.TextXAlignment.Center
					)
					else nil,
				Preview = if previewVisible
					then c(Well, {
						Candy = true,
						Native = { Size = UDim2.fromOffset(layout.previewWidth, bodyHeight), ZIndex = 103 },
					}, {
						Track = if not short
							then c(Ribbon, {
								Text = `{string.upper(selected.track)} • TIER {selected.tier}`,
								Color = if selected.track == "Premium" then T.Colors.Gold else T.Colors.Surface,
								Native = {
									Position = UDim2.fromOffset(16, 14),
									Size = UDim2.new(1, -32, 0, 28),
									ZIndex = 106,
								},
							})
							else nil,
						Art = c("Frame", {
							BackgroundTransparency = 1,
							Position = if short
								then UDim2.fromOffset(8, 8)
								else UDim2.new(0, 16, 0.5, -(previewDetails + previewArtHeight) / 2 + 20),
							Size = if short
								then UDim2.new(0.35, -16, 1, -16)
								else UDim2.new(1, -32, 0, previewArtHeight),
							ZIndex = 104,
						}, {
							Content = c(ShopPreview, {
								Items = previewItems,
								BonksTextSize = if compact then 36 else 56,
								PlaceholderBonks = if selected.kind == "Bonks" then selected.amount else nil,
								ColorId = (props.Equipped or {}).CharacterColor,
								CostumeId = (props.Equipped or {}).CostumeAssets,
								TextColor = T.Colors.Ink,
								TextStroke = 0,
								ZIndex = 104,
							}),
						}),
						Details = c("ScrollingFrame", {
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							Selectable = false,
							Position = if short then UDim2.new(0.35, 4, 0, 8) else UDim2.new(0, 16, 1, -previewDetails),
							Size = if short
								then UDim2.new(0.65, -16, 1, -16)
								else UDim2.new(1, -32, 0, previewDetails - 12),
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
							CanvasSize = UDim2.new(),
							ScrollBarThickness = 3,
							ScrollBarImageColor3 = T.Colors.Pink,
							ZIndex = 105,
						}, {
							Kind = label(
								if short
									then `{string.upper(selected.track)} • TIER {selected.tier}`
									else if definition
										then ItemLabels[definition.Category] or "COSMETIC"
										else "CURRENCY",
								UDim2.fromOffset(0, 0),
								UDim2.new(1, 0, 0, 22),
								18,
								T.Colors.InkSoft,
								false
							),
							Name = label(
								name,
								UDim2.fromOffset(0, if short then 22 else 24),
								UDim2.new(1, 0, 0, if short then 26 else 44),
								if short then 24 else 28,
								T.Colors.Ink,
								true
							),
							Rarity = if definition
								then c(Ribbon, {
									Rarity = definition.Rarity,
									Native = {
										Position = UDim2.fromOffset(2, if short then 52 else 72),
										Size = UDim2.new(1, -6, 0, 24),
										ZIndex = 107,
									},
								})
								else nil,
							Requirement = label(
								requirement,
								UDim2.fromOffset(0, if short then 78 else 106),
								UDim2.new(1, -4, 0, if short then 24 else 44),
								18,
								T.Colors.InkSoft,
								false
							),
						}),
					})
					else nil,
				Tracks = if ready and (not compact or not previewOpen)
					then c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(layout.tracksX, 0),
						Size = UDim2.fromOffset(layout.tracksWidth, bodyHeight),
						ZIndex = 103,
					}, {
						Rewards = c(Rewards, {
							Compact = short,
							Width = layout.tracksWidth,
							State = if ready then state else nil,
							SeasonId = card.definition.SeasonId,
							ShowProgress = false,
							Entries = entries,
							SelectedKey = if selected then selected.key else nil,
							OnSelectEntry = function(entry, openPreview)
								setSelectedKey(entry.key)
								if compact and openPreview then
									setPreviewOpen(true)
								end
							end,
						}),
					})
					else nil,
			}),
			Footer = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(inset, layout.footerTop),
				Size = UDim2.fromOffset(layout.innerWidth, layout.footerHeight),
				ZIndex = 103,
			}, {
				Divider = c("Frame", {
					BackgroundColor3 = T.Colors.WellLine,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, -layout.gap / 2),
					Size = UDim2.new(1, 0, 0, 2),
					ZIndex = 104,
				}),
				Explanation = if premiumOwned and not compact
					then c(Ribbon, {
						Text = "PREMIUM UNLOCKED",
						Color = T.Colors.Gold,
						Native = { Position = UDim2.fromOffset(2, 14), Size = UDim2.fromOffset(216, 32), ZIndex = 105 },
					})
					else nil,
				Premium = if showPremium
					then c(PriceButton, {
						Text = if card.pending then "PROCESSING..." else "GET PREMIUM",
						TextSize = 18,
						SubText = if card.robuxPrice
							then Shop.RobuxSymbol .. formatNumber(card.robuxPrice)
							else if card.status == "Loading" then "LOADING PRICE..." else "UNAVAILABLE",
						SubTextSize = 18,
						Red = true,
						Enabled = canBuy,
						AnchorPoint = Vector2.new(0, 0),
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.fromOffset(
							if stackedActions then layout.innerWidth else (layout.innerWidth - layout.gap) / 2,
							actionHeight
						),
						ZIndex = 105,
						OnActivated = props.OnPurchaseRobux,
					})
					else nil,
				Claim = c(PriceButton, {
					ButtonRef = claimRef,
					Text = claimText,
					TextSize = if compact then 20 else 24,
					Red = claimable > 0,
					Enabled = claimable > 0 and not props.ClaimPending,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, if stackedActions then actionHeight + 8 else 0),
					Size = UDim2.fromOffset(claimWidth, actionHeight),
					ZIndex = 105,
					OnActivated = props.OnClaimSeason,
				}),
			}),
		}),
	})
end
