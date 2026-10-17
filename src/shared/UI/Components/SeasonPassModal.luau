--!strict
local T = require(script.Parent.Parent.Tokens)
-- Season progression and premium access are distinct actions using the existing economy controller.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
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
local CollectibleFace = require(script.Parent.CollectibleFace)
local ModalClose = require(script.Parent.ModalClose)
local Button = require(script.Parent.PuffyButton)
local Layout = require(script.Parent.Parent.Models.SeasonLayout)
local FaceLayout = require(script.Parent.Parent.Models.CollectibleLayout)
local S, K = T.SeasonRewards, T.Collectible
-- The Bonks coin on its own, as on the reward tiles: the amount is named once, on the card.
local BONKS_GLYPH = "rbxassetid://106703644238993"

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

local function requirementColor(entry, active: boolean): Color3
	if entry.claimed then
		return T.Colors.Lime
	elseif not active then
		return T.Colors.Well
	elseif entry.claimable then
		return T.Colors.Yellow
	elseif entry.needsPremium then
		return T.Colors.Gold
	end
	return T.Colors.Well
end

-- The requirement reads as the same candy state chip as the tiles when it fits;
-- longer wording wraps as one centred line group instead of truncating.
local function requirementView(text: string, color: Color3, x: number, y: number, width: number, center: boolean)
	local chipWidth = FaceLayout.tagWidth(text, T.Type.Minimum)
	if chipWidth <= width then
		return c(Ribbon, {
			Text = text,
			Color = color,
			Native = {
				AnchorPoint = Vector2.new(if center then 0.5 else 0, 0),
				Position = UDim2.fromOffset(if center then x + width / 2 else x, y),
				Size = UDim2.fromOffset(chipWidth, K.TagHeight),
				ZIndex = 112,
			},
		})
	end
	return c("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, T.Layout.MinTarget),
		Font = T.Type.Label,
		Text = text,
		TextSize = T.Type.Minimum,
		TextColor3 = T.Colors.Ink,
		TextWrapped = true,
		TextXAlignment = if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 112,
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
	-- The preview is one composed stack (track chip, the collectible card with its
	-- seam rarity tag and CAPS name, the item kind and the requirement chip), centred
	-- in its well so nothing floats in leftover space. The amount of a currency reward
	-- is named once, on the card.
	local preview = nil
	if previewVisible and selected then
		local edge = S.BrowserInset
		local previewWidth = layout.previewWidth
		local caption = if definition then ItemLabels[definition.Category] or "COSMETIC" else "CURRENCY"
		local trackText = `{string.upper(selected.track)} • TIER {selected.tier}`
		local trackColor = if selected.track == "Premium" then T.Colors.Gold else T.Colors.Surface
		local requirementTint = requirementColor(selected, seasonActive)
		local artContent = if selected.kind == "Bonks"
			then c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = BONKS_GLYPH,
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.8, 0.8),
				ZIndex = 108,
			})
			else c(ShopPreview, {
				Items = previewItems,
				ColorId = (props.Equipped or {}).CharacterColor,
				CostumeId = (props.Equipped or {}).CostumeAssets,
				TextColor = T.Colors.Ink,
				TextStroke = 0,
				ZIndex = 108,
			})
		local function back(x: number, y: number)
			return c(Button, {
				Text = "<",
				TextSize = T.Type.Tab,
				TextColor = T.Colors.Ink,
				Color = T.Colors.Surface,
				LipColor = T.Colors.WellLine,
				Shadow = false,
				OnActivated = function()
					setPreviewOpen(false)
				end,
				Native = {
					Position = UDim2.fromOffset(x, y),
					Size = UDim2.fromOffset(T.Layout.MinTarget, T.Layout.MinTarget),
					ZIndex = 110,
				},
			})
		end
		local function trackChip(x: number, y: number, maxWidth: number, center: boolean)
			return c(Ribbon, {
				Text = trackText,
				Color = trackColor,
				Native = {
					AnchorPoint = Vector2.new(if center then 0.5 else 0, 0),
					Position = UDim2.fromOffset(x, y),
					Size = UDim2.fromOffset(FaceLayout.tagWidth(trackText, T.Type.Minimum, maxWidth), K.TagHeight),
					ZIndex = 112,
				},
			})
		end
		local children: { [string]: any } = {}
		if short then
			-- Landscape phone: square card on the left, the copy stacked beside it.
			-- Layout.shortPreview keeps the whole stack inside the well (one-line
			-- name and the requirement chip sharing a row on the shortest phones).
			local kindBounds =
				TextService:GetTextSize(caption, T.Type.Minimum, T.Type.Label, Vector2.new(4096, T.Layout.MinTarget))
			local stack = Layout.shortPreview(bodyHeight, previewWidth, {
				track = FaceLayout.tagWidth(trackText, T.Type.Minimum),
				requirement = FaceLayout.tagWidth(requirement, T.Type.Minimum),
				kind = math.ceil(kindBounds.X) + 2,
			})
			local columnX, columnWidth = stack.columnX, stack.columnWidth
			children.Back = back(stack.back.x, stack.back.y)
			children.Track = trackChip(stack.track.x, stack.track.y, stack.track.maxWidth, false)
			children.Name = c(ResponsiveText, {
				MeasurementFont = T.Type.Display,
				MinTextSize = T.Type.Minimum,
				MaxTextSize = T.Type.TileLabel,
				Wrapped = stack.mode == "Stacked",
				Native = {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(columnX, stack.name.y),
					Size = UDim2.fromOffset(columnWidth, stack.name.height),
					Font = T.Type.Display,
					Text = string.upper(name),
					TextColor3 = T.Colors.Ink,
					TextWrapped = stack.mode == "Stacked",
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 110,
				},
			})
			children.Kind = if stack.kind
				then label(
					caption,
					UDim2.fromOffset(columnX, stack.kind.y),
					UDim2.fromOffset(stack.kind.width, stack.kind.height),
					T.Type.Minimum,
					T.Colors.InkSoft,
					false
				)
				else nil
			children.Requirement = requirementView(
				requirement,
				requirementTint,
				stack.requirement.x,
				stack.requirement.y,
				stack.requirement.width,
				false
			)
			children.Face = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(stack.face.x, stack.face.y),
				Size = UDim2.fromOffset(stack.face.side, stack.face.side),
				ZIndex = 106,
			}, {
				Card = c(CollectibleFace, {
					Width = stack.face.side,
					Height = stack.face.side,
					Rarity = if definition then definition.Rarity else nil,
					Art = artContent,
					ZIndex = 106,
				}),
			})
		else
			local topRow = if compact then T.Layout.MinTarget else K.TagHeight
			local faceWidth = math.min(previewWidth - (edge - K.Pad) * 2, S.PreviewMaxWidth)
			local details = K.FooterHeight + K.NameGap + T.Layout.MinTarget
			local available = bodyHeight - edge * 2 - topRow - details
			local faceHeight = math.max(
				T.Layout.MinTarget,
				math.min(available, S.PreviewArtMaxHeight + K.NameHeight + K.TagHeight + K.Pad * 2)
			)
			local total = topRow + faceHeight + details
			local top = math.max(edge, math.floor((bodyHeight - total) / 2))
			local faceX = math.floor((previewWidth - faceWidth) / 2)
			local copyX = faceX + K.Pad
			local copyWidth = faceWidth - K.Pad * 2
			children.Back = if compact then back(edge, top) else nil
			children.Track = trackChip(
				previewWidth / 2,
				top + (topRow - K.TagHeight) / 2,
				previewWidth - (T.Layout.MinTarget + edge * 2) * 2,
				true
			)
			children.Face = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(faceX, top + topRow),
				Size = UDim2.fromOffset(faceWidth, faceHeight),
				ZIndex = 106,
			}, {
				Card = c(CollectibleFace, {
					Width = faceWidth,
					Height = faceHeight,
					Rarity = if definition then definition.Rarity else nil,
					Name = name,
					Art = artContent,
					ZIndex = 106,
				}),
			})
			local detailsTop = top + topRow + faceHeight
			children.Kind = label(
				caption,
				UDim2.fromOffset(copyX, detailsTop),
				UDim2.fromOffset(copyWidth, K.FooterHeight),
				T.Type.Minimum,
				T.Colors.InkSoft,
				false,
				Enum.TextXAlignment.Center
			)
			children.Requirement = requirementView(
				requirement,
				requirementTint,
				copyX,
				detailsTop + K.FooterHeight + K.NameGap,
				copyWidth,
				true
			)
		end
		preview = c(Well, {
			Candy = true,
			Native = { Size = UDim2.fromOffset(previewWidth, bodyHeight), ZIndex = 103 },
		}, children)
	end
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
				TextSize = T.Type.ModalTitle,
				Native = {
					Position = UDim2.fromOffset(inset, inset),
					Size = UDim2.new(1, -inset * 2 - T.Layout.MinTarget - layout.gap, 0, layout.titleHeight),
					ZIndex = 105,
				},
			}),
			Close = c(ModalClose, {
				ButtonRef = closeRef,
				Position = UDim2.new(1, -inset, 0, inset),
				OnActivated = props.OnClose,
				ZIndex = 106,
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
						Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
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
				Preview = if previewVisible then preview else nil,
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
							Height = bodyHeight,
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
						TextSize = T.Type.Minimum,
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
