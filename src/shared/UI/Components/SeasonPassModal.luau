-- Season progression and premium access are distinct actions using the existing economy controller.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local React = require(ReplicatedStorage.Packages.react)
local UI = require(ReplicatedStorage.Config.Interface.UI)
local Shop = require(ReplicatedStorage.Config.Economy.Shop)
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics.Cosmetics)
local ItemLabels = require(ReplicatedStorage.Config.Cosmetics.Inventory).ItemLabels
local Model = require(script.Parent.Parent.Models.SeasonRewardsModel)
local Claims = require(script.Parent.Parent.Models.SeasonClaims)
local Selection = require(script.Parent.Parent.Services.Selection)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local ResponsiveText = require(script.Parent.ResponsiveText)
local PriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local Rewards = require(script.Parent.SeasonRewardsPanel)
local formatNumber = require(script.Parent.Parent.Models.NumberText)
local c = React.createElement
local colors = UI.ProgressionStyle

local function label(text, position, size, maximum, color, heading, alignment)
	return c(ResponsiveText, {
		MeasurementFont = if heading then Enum.Font.LuckiestGuy else Enum.Font.SourceSansBold,
		MaxTextSize = maximum,
		MinTextSize = 12,
		Wrapped = true,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Text = text,
			Font = if heading then Enum.Font.LuckiestGuy else Enum.Font.SourceSansBold,
			TextColor3 = color or Color3.new(1, 1, 1),
			TextWrapped = true,
			TextXAlignment = alignment or Enum.TextXAlignment.Left,
			ZIndex = 105,
		},
	})
end

return function(props)
	local safe = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local compact = safe.size.Y < 500 or safe.size.X < 760
	local width = math.min(safe.size.X - 24, 1240)
	local height = math.min(safe.size.Y - 16, 820)
	local card = props.Card
	local state = props.SeasonState
	local ready = state ~= nil and state.seasonId == card.definition.SeasonId
	local entries = Model.entries(if ready then state else nil)
	local selectedKey, setSelectedKey = React.useState(nil)
	local previewOpen, setPreviewOpen = React.useState(false)
	local selected = Model.selected(entries, selectedKey)
	local closeRef, claimRef = React.useRef(nil), React.useRef(nil)
	React.useEffect(function()
		setSelectedKey(nil)
		setPreviewOpen(false)
	end, { card.id })
	React.useEffect(function()
		if props.FocusEnabled == false then
			return
		end
		local previous = GuiService.SelectedObject
		local active = true
		task.defer(function()
			if active then
				GuiService.SelectedObject = if Selection.isSelectable(claimRef.current)
					then claimRef.current
					else closeRef.current
			end
		end)
		return function()
			active = false
			if Selection.isSelectable(previous) then
				GuiService.SelectedObject = previous
			end
		end
	end, { card.id, props.FocusEnabled })
	local claimable = if ready then Claims.count(state) else 0
	local premiumOwned = ready and state.hasPremium
	local canBuy = ready
		and not premiumOwned
		and card.status == "Active"
		and card.robuxPrice ~= nil
		and card.productId ~= nil
		and not card.pending
	local bodyTop = if compact then 70 else 100
	local footerHeight = if compact then 78 else 98
	local bodyHeight = math.max(64, height - bodyTop - footerHeight - (if compact then 8 else 16))
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
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 100 }, {
		Dim = c("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.4,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 100,
		}),
		Panel = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(safe.position.X + safe.size.X / 2, safe.position.Y + safe.size.Y / 2),
			Size = UDim2.fromOffset(width, height),
			BackgroundTransparency = 1,
			Image = "rbxassetid://124751224634629",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(31, 41, 978, 620),
			SliceScale = 0.5,
			BorderSizePixel = 0,
			ZIndex = 102,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		}, {
			Title = label(
				if ready then string.upper(state.displayName) else "SEASON REWARDS",
				UDim2.fromOffset(16, 8),
				UDim2.new(1, -140, 0, if compact then 27 else 40),
				if compact then 25 else 36,
				nil,
				true
			),
			Back = c(PriceButton, {
				ButtonRef = closeRef,
				Text = if compact and previewOpen then "REWARDS" else "BACK",
				TextSize = 20,
				Position = UDim2.new(1, -62, 0, 52),
				Size = UDim2.fromOffset(104, 44),
				Compact = true,
				ZIndex = 106,
				OnActivated = function()
					if compact and previewOpen then
						setPreviewOpen(false)
					else
						props.OnClose()
					end
				end,
			}),
			ProgressLabel = label(
				if complete
					then "ALL TIERS EARNED!"
					else `TIER {tier}  •  {formatNumber(math.max(target - xp, 0))} XP TO TIER {tier + 1}`,
				UDim2.fromOffset(16, if compact then 35 else 50),
				UDim2.new(1, -148, 0, 20),
				if compact then 14 else 19,
				colors.Ink,
				false
			),
			Progress = c("Frame", {
				BackgroundColor3 = colors.Ink,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(16, if compact then 59 else 78),
				Size = UDim2.new(1, -152, 0, 5),
				ZIndex = 103,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = c("Frame", {
					BackgroundColor3 = colors.Pink,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(progress, 1),
					ZIndex = 104,
				}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
			}),
			Body = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(16, bodyTop),
				Size = UDim2.new(1, -32, 0, bodyHeight),
				ZIndex = 103,
			}, {
				Preview = if previewVisible
					then c("Frame", {
						BackgroundColor3 = colors.Surface,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(if compact then 1 else 0.32, 1),
						ZIndex = 103,
					}, {
						Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
						Track = label(
							`{string.upper(selected.track)} • TIER {selected.tier}`,
							UDim2.new(if compact then 0.4 else 0, 12, 0, 8),
							UDim2.new(if compact then 0.6 else 1, -24, 0, 24),
							20,
							if selected.track == "Premium" then colors.Yellow else colors.Cyan,
							true
						),
						Art = c("Frame", {
							BackgroundTransparency = 1,
							Position = UDim2.fromOffset(0, if compact then 0 else 34),
							Size = if compact then UDim2.fromScale(0.4, 1) else UDim2.new(1, 0, 1, -140),
							ZIndex = 104,
						}, {
							Content = c(ShopPreview, {
								Items = previewItems,
								BonksTextSize = if compact then 34 else 64,
								PlaceholderBonks = if selected.kind == "Bonks" then selected.amount else nil,
								ColorId = (props.Equipped or {}).CharacterColor,
								CostumeId = (props.Equipped or {}).CostumeAssets,
								ZIndex = 104,
							}),
						}),
						Name = label(
							name,
							if compact then UDim2.new(0.4, 12, 0, 35) else UDim2.new(0, 12, 1, -82),
							if compact then UDim2.new(0.6, -24, 0.5, -24) else UDim2.new(1, -24, 0, 40),
							if compact then 23 else 28,
							nil,
							true
						),
						Kind = label(
							if definition then ItemLabels[definition.Category] or "COSMETIC" else "BONKS",
							if compact then UDim2.new(0.4, 12, 0.5, -2) else UDim2.new(0, 12, 1, -104),
							if compact then UDim2.new(0.6, -24, 0, 18) else UDim2.new(1, -24, 0, 18),
							13,
							colors.Muted,
							false
						),
						Requirement = label(
							Model.requirement(selected),
							if compact then UDim2.new(0.4, 12, 0.5, 22) else UDim2.new(0, 12, 1, -42),
							if compact then UDim2.new(0.6, -24, 0.5, -28) else UDim2.new(1, -24, 0, 36),
							17,
							if selected.claimable then colors.Green else colors.Muted,
							false
						),
					})
					else nil,
				Tracks = if not compact or not previewOpen
					then c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(if compact then 0 else 0.34, 0),
						Size = UDim2.fromScale(if compact then 1 else 0.66, 1),
						ZIndex = 103,
					}, {
						Rewards = c(Rewards, {
							Compact = compact,
							Width = (width - 32) * (if compact then 1 else 0.66),
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
				Position = UDim2.new(0, 16, 1, -footerHeight),
				Size = UDim2.new(1, -32, 0, footerHeight - 8),
				ZIndex = 103,
			}, {
				Explanation = label(
					if premiumOwned
						then "PREMIUM PASS OWNED • Play matches to earn XP and unlock rewards."
						else "Play matches to earn tiers. The Premium Pass adds rewards for this season.",
					UDim2.fromOffset(0, if compact then -4 else 0),
					UDim2.new(1, 0, 0, if compact then 18 else 22),
					if compact then 14 else 18,
					colors.Ink,
					false
				),
				Premium = if not premiumOwned
					then c(PriceButton, {
						Text = if card.pending then "PROCESSING…" else "GET PREMIUM PASS",
						TextSize = if compact then 18 else 23,
						SubText = if card.robuxPrice
							then Shop.RobuxSymbol .. formatNumber(card.robuxPrice)
							else "PRICE UNAVAILABLE",
						SubTextSize = 22,
						Red = true,
						Compact = true,
						Enabled = canBuy,
						Position = UDim2.new(0.25, -4, 1, -4),
						Size = UDim2.new(0.5, -8, 0, if compact then 48 else 60),
						ZIndex = 105,
						OnActivated = props.OnPurchaseRobux,
					})
					else nil,
				Claim = c(PriceButton, {
					ButtonRef = claimRef,
					Text = if props.ClaimPending
						then "CLAIMING…"
						else if claimable > 0 then "CLAIM REWARDS" else "NO REWARDS READY",
					TextSize = if compact then 19 else 25,
					Compact = true,
					Enabled = claimable > 0 and not props.ClaimPending,
					Position = UDim2.new(if premiumOwned then 0.5 else 0.75, if premiumOwned then 0 else 4, 1, -4),
					Size = UDim2.new(if premiumOwned then 1 else 0.5, -8, 0, if compact then 48 else 60),
					ZIndex = 105,
					OnActivated = props.OnClaimSeason,
				}),
			}),
		}),
	})
end
