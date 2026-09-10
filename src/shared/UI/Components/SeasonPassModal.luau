-- Season progression and premium access are distinct actions using the existing economy controller.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
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
local PageTitle = require(script.Parent.PageTitle)
local PriceButton = require(script.Parent.Shop.ShopPriceButton)
local ShopPreview = require(script.Parent.Shop.ShopPreview)
local Rewards = require(script.Parent.SeasonRewardsPanel)
local formatNumber = require(script.Parent.Parent.Models.NumberText)
local modalSurface = require(script.Parent.ModalSurface)

local c = React.createElement
local colors = UI.ProgressionStyle

local function label(text, position, size, maximum, color, heading, alignment)
	return c(ResponsiveText, {
		MeasurementFont = if heading then Enum.Font.LuckiestGuy else UI.Text.BodyFont,
		MaxTextSize = maximum,
		MinTextSize = if heading then 12 else 14,
		Wrapped = true,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Text = text,
			Font = if heading then Enum.Font.LuckiestGuy else UI.Text.BodyFont,
			TextColor3 = color or colors.White,
			TextStrokeColor3 = colors.Ink,
			TextStrokeTransparency = if heading or color == colors.Ink then 1 else 0.35,
			TextWrapped = true,
			TextXAlignment = alignment or Enum.TextXAlignment.Left,
			ZIndex = 105,
		},
	}, {
		Outline = if heading and color ~= colors.Ink
			then c("UIStroke", {
				Color = colors.Ink,
				Thickness = 0.045,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			})
			else nil,
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
	local inset = if compact then 12 else 16
	local titleHeight = if compact then 24 else 40
	local progressTop = inset + titleHeight + (if compact then 1 else 4)
	local progressBarTop = progressTop + (if compact then 22 else 24)
	local bodyTop = progressBarTop + (if compact then 13 else 17)
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
		Dim = modalSurface({
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
			Title = c(PageTitle, {
				Text = if ready then string.upper(state.displayName) else "SEASON REWARDS",
				TextSize = if compact then 25 else 36,
				Alignment = Enum.TextXAlignment.Left,
				Native = {
					Position = UDim2.fromOffset(inset, inset + 2),
					Size = UDim2.new(1, -148, 0, titleHeight),
					ZIndex = 105,
				},
			}),
			Back = c(PriceButton, {
				Color = colors.Ink,
				ButtonRef = closeRef,
				Text = if compact and previewOpen then "REWARDS" else "BACK",
				TextSize = 20,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -inset, 0, inset),
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
				if loading
					then "LOADING REWARDS…"
					else if not seasonActive
						then unavailableText
						else if complete
							then "ALL TIERS EARNED!"
							else `TIER {tier}  •  {formatNumber(math.max(target - xp, 0))} XP TO TIER {tier + 1}`,
				UDim2.fromOffset(inset, progressTop),
				UDim2.new(1, -148, 0, 20),
				if compact then 14 else 19,
				colors.White,
				false
			),
			Progress = c("Frame", {
				BackgroundColor3 = colors.Claimed,
				Visible = seasonActive,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(inset, progressBarTop),
				Size = UDim2.new(1, -148, 0, 5),
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
				Status = if not loading and not ready
					then label(
						unavailableText,
						UDim2.fromScale(0, 0.35),
						UDim2.fromScale(1, 0.3),
						if compact then 22 else 30,
						colors.White,
						true,
						Enum.TextXAlignment.Center
					)
					else nil,
				Preview = if previewVisible
					then c("Frame", {
						BackgroundColor3 = colors.Claimed,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(if compact then 1 else 0.32, 1),
						ZIndex = 103,
					}, {
						Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
						Outline = c("UIStroke", { Color = colors.White, Thickness = 1, Transparency = 0.6 }),
						Track = label(
							`{string.upper(selected.track)} • TIER {selected.tier}`,
							UDim2.new(if compact then 0.4 else 0, 12, 0, 8),
							UDim2.new(if compact then 0.6 else 1, -24, 0, 24),
							20,
							colors.White,
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
								TextColor = colors.White,
								TextStroke = 0.045,
								ZIndex = 104,
							}),
						}),
						Name = label(
							name,
							if compact then UDim2.new(0.4, 12, 0, 34) else UDim2.new(0, 12, 1, -82),
							if compact then UDim2.new(0.6, -24, 0, 26) else UDim2.new(1, -24, 0, 40),
							if compact then 23 else 28,
							colors.White,
							true
						),
						Kind = if not compact
							then label(
								if definition then ItemLabels[definition.Category] or "COSMETIC" else "BONKS",
								UDim2.new(0, 12, 1, -104),
								UDim2.new(1, -24, 0, 20),
								14,
								colors.White,
								false
							)
							else nil,
						Requirement = label(
							if not seasonActive and not selected.claimed
								then unavailableText
								else Model.requirement(selected),
							if compact then UDim2.new(0.4, 12, 0, 62) else UDim2.new(0, 12, 1, -42),
							if compact then UDim2.new(0.6, -24, 1, -66) else UDim2.new(1, -24, 0, 36),
							17,
							colors.White,
							false
						),
					})
					else nil,
				Tracks = if ready and (not compact or not previewOpen)
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
					if loading
						then ""
						else if not seasonActive
							then ""
							else if premiumOwned
								then "PREMIUM UNLOCKED"
								else "Premium includes the extra reward track.",
					UDim2.fromOffset(0, if compact then -4 else 0),
					UDim2.new(1, 0, 0, if compact then 18 else 22),
					if compact then 14 else 18,
					colors.White,
					false
				),
				Premium = if showPremium
					then c(PriceButton, {
						Text = if card.pending then "PROCESSING…" else "GET PREMIUM PASS",
						TextSize = if compact then 18 else 23,
						SubText = if card.robuxPrice
							then Shop.RobuxSymbol .. formatNumber(card.robuxPrice)
							else if card.status == "Loading" then "LOADING PRICE…" else "UNAVAILABLE",
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
						else if loading
							then "LOADING REWARDS…"
							else if not seasonActive
								then unavailableText
								else if claimable > 0 then "CLAIM ALL" else "NOTHING TO CLAIM",
					TextSize = if compact then 19 else 25,
					Compact = true,
					Enabled = claimable > 0 and not props.ClaimPending,
					Position = UDim2.new(if showPremium then 0.75 else 0.5, if showPremium then 4 else 0, 1, -4),
					Size = UDim2.new(if showPremium then 0.5 else 1, -8, 0, if compact then 48 else 60),
					ZIndex = 105,
					OnActivated = props.OnClaimSeason,
				}),
			}),
		}),
	})
end
