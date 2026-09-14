--!strict
local T = require(script.Parent.Parent.Tokens)
-- Description: Responsive splash card showing season tier, XP progress, and the next free reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local SeasonClaims = require(script.Parent.Parent.Models.SeasonClaims)
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Palette = require(script.Parent.Parent.EconomyPalette)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))

local OuchPanel = require(script.Parent.CandyPanel)
local OuchProgressBar = require(script.Parent.CandyProgressBar)

local c = React.createElement

local DARK = Palette.Ink
local PROGRESS_FILL_COLOR = Palette.Pink
local TIER_BADGE_COLOR = Palette.Pink

export type Props = {
	State: any?,
	OnClaim: (() -> ())?,
	OnViewRewards: (() -> ())?,
	Pending: boolean?,
	Compact: boolean?,
	ShowClaim: boolean?,
	Native: { [any]: any }?,
}

-- Both the live card and the between-seasons card fill their slot identically, so
-- the panel keeps the same footprint either way and the splash layout never shifts.
local function cardNative(props: Props): { [any]: any }
	local native: { [any]: any } = {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = Palette.Panel,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
	}
	if props.Native then
		for key, value in props.Native do
			native[key] = value
		end
	end
	return native
end

local function findNextFreeReward(tiers: { any }): any?
	for _, tier in tiers do
		if not tier.unlocked then
			local cosmetic = (tier.freeCosmetics or {})[1]
			if cosmetic then
				return cosmetic
			end
			if tier.freeReward then
				return tier.freeReward
			end
		end
	end
	return nil
end

return function(props: Props)
	local state = props.State
	-- No season state at all means it has not arrived from the server yet, so the
	-- slot stays empty rather than claiming a gap that may not exist.
	if state == nil then
		return nil
	end
	-- A resolved "no active season" is different, and it is a state this game
	-- genuinely enters: the selector returns nothing between one season's end and
	-- the next one's start. Rendering nothing there left a hole on the desktop
	-- splash and a blank panel behind the SEASON tab, which reads as a broken
	-- screen. Say so instead, and keep the card's own shape so the layout holds.
	if state.active == false then
		return c(OuchPanel, { Native = cardNative(props), Padding = 0 }, {
			Heading = c(ResponsiveText, {
				HostName = "Heading",
				MeasurementFont = Enum.Font.FredokaOne,
				MinTextSize = 14,
				MaxTextSize = UIConfig.Text.HeaderPx,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.new(0.5, 0, 0, if props.Compact then 6 else 10),
					Size = UDim2.new(1, -24, 0, 30),
					Text = "SEASON",
					TextColor3 = T.Colors.Ink,
					TextStrokeColor3 = DARK,
					TextStrokeTransparency = 1,
					ZIndex = 2,
				},
			}),
			Detail = c(ResponsiveText, {
				HostName = "Detail",
				MeasurementFont = T.Type.Label,
				MinTextSize = 11,
				MaxTextSize = 16,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = UIConfig.Text.DefaultFont,
					Position = UDim2.new(0.5, 0, 0.5, if props.Compact then 6 else 10),
					Size = UDim2.new(1, -28, 0, 44),
					-- Deliberately promises nothing about carry-over: BattlePassService
					-- discards season XP while no season is active, so copy claiming
					-- progress continues would be false.
					Text = "Between seasons. Tier rewards return with the next one.",
					TextColor3 = T.Colors.Ink,
					TextStrokeColor3 = DARK,
					TextStrokeTransparency = 1,
					TextWrapped = true,
					ZIndex = 2,
				},
			}),
		})
	end

	local claimable = if props.ShowClaim == false then 0 else SeasonClaims.count(state)
	local actionVisible = props.ShowClaim ~= false and (claimable > 0 or props.OnViewRewards ~= nil)
	local compact = props.Compact == true
	local claimWidth = if compact then UIConfig.Layout.SeasonCompactClaimWidthPx else UIConfig.Layout.SeasonClaimWidthPx
	local tier = state.tier or 0
	local tierCount = state.tierCount or 0
	local xpIntoTier = state.xpIntoTier or 0
	local xpForNextTier = state.xpForNextTier or 1
	local displayName = state.displayName or "SEASON"
	local isMaxTier = tier >= tierCount
	local progressFraction = if isMaxTier then 1 else math.clamp(xpIntoTier / xpForNextTier, 0, 1)
	local nextReward = if state.tiers then findNextFreeReward(state.tiers) else nil
	local native = cardNative(props)

	return c(OuchPanel, { Native = native, Padding = 0 }, {
		Title = if not compact
			then c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.FredokaOne,
				MinTextSize = 14,
				MaxTextSize = UIConfig.Text.HeaderPx,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.new(0.5, 0, 0, 4),
					Size = UDim2.new(1, -24, 0, 32),
					Text = "SEASON PROGRESS",
					TextColor3 = T.Colors.Ink,
					TextStrokeColor3 = DARK,
					TextStrokeTransparency = 1,
					ZIndex = 2,
				},
			})
			else nil,
		Content = c("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, if compact then 0 else 18),
			Size = UDim2.new(1, -UIConfig.Panel.InsetPx * 2, 1, if compact then -24 else -60),
		}, {
			TierBadge = c("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = TIER_BADGE_COLOR,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.02, 0.5),
				Size = UDim2.fromScale(if compact then 0.17 else 0.21, 0.84),
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Tile) }),
				TierWord = c(ResponsiveText, {
					MeasurementFont = T.Type.Label,
					MinTextSize = T.Type.Minimum,
					MaxTextSize = T.Type.Minimum,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.fromEnum(T.Type.Label),
						Position = UDim2.fromScale(0.5, 0),
						Size = UDim2.new(0.9, 0, 0, 22),
						Text = "TIER",
						TextColor3 = T.Colors.Ink,
						TextStrokeColor3 = Palette.Ink,
						TextStrokeTransparency = 1,
					},
				}),
				TierNumber = c(ResponsiveText, {
					MeasurementFont = Enum.Font.FredokaOne,
					MinTextSize = if compact then 10 else 14,
					MaxTextSize = if compact then 24 else 32,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Position = UDim2.fromScale(0.5, 0.65),
						Size = UDim2.fromScale(0.82, 0.48),
						Text = tostring(tier),
						TextColor3 = T.Colors.Ink,
						TextStrokeColor3 = Palette.Ink,
						TextStrokeTransparency = 1,
					},
				}),
			}),
			Claim = if actionVisible
				then c(ShopPriceButton, {
					Enabled = props.OnViewRewards ~= nil or (props.OnClaim ~= nil and not props.Pending),
					OnActivated = props.OnViewRewards or props.OnClaim,
					Color = Palette.Pink,
					Compact = true,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -4, 0.5, 0),
					Size = UDim2.fromOffset(claimWidth, UIConfig.Interaction.MinTargetPx),
					Text = if props.OnViewRewards
						then (if compact then "VIEW" else "REWARDS")
						else if props.Pending then "CLAIMING…" else "CLAIM",
					TextSize = 19,
					ZIndex = (native.ZIndex or 1) + 2,
				})
				else nil,
			Info = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(if compact then 0.22 else 0.27, 0.08),
				Size = UDim2.new(
					if compact then 0.75 else 0.7,
					if actionVisible then -(claimWidth + UIConfig.Layout.InventoryContentGapPx) else 0,
					0.84,
					0
				),
			}, {
				SeasonName = c(ResponsiveText, {
					MeasurementFont = T.Type.Label,
					MinTextSize = if compact then 9 else 12,
					MaxTextSize = if compact then 22 else UIConfig.Text.HeaderPx,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.fromEnum(T.Type.Label),
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, if compact then 0.42 else 0.24),
						Text = if compact then "SEASON" else displayName,
						TextColor3 = T.Colors.Ink,
						TextStrokeColor3 = Palette.Ink,
						TextStrokeTransparency = 1,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					},
				}),
				ProgressBar = c(OuchProgressBar, {
					Progress = progressFraction,
					Color = PROGRESS_FILL_COLOR,
					Native = {
						Position = UDim2.fromScale(0, if compact then 0.48 else 0.3),
						Size = UDim2.fromScale(1, 0.16),
					},
				}),
				XPLabel = c(ResponsiveText, {
					MeasurementFont = T.Type.Label,
					MinTextSize = 10,
					MaxTextSize = T.Type.Minimum,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.fromEnum(T.Type.Label),
						Position = UDim2.fromScale(0, if compact then 0.68 else 0.5),
						Size = UDim2.new(1, 0, 0, 20),
						Text = if isMaxTier then "MAX TIER" else `{xpIntoTier} / {xpForNextTier} XP`,
						TextColor3 = T.Colors.Ink,
						TextStrokeColor3 = Palette.Ink,
						TextStrokeTransparency = 1,
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				}),
				NextReward = if not compact and nextReward
					then c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0, 0.72),
						Size = UDim2.fromScale(1, 0.24),
					}, {
						NextLabel = c(ResponsiveText, {
							MeasurementFont = T.Type.Label,
							MinTextSize = 10,
							MaxTextSize = 15,
							Native = {
								BackgroundTransparency = 1,
								FontFace = Font.fromEnum(T.Type.Label),
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(0.22, 1),
								Text = "NEXT",
								TextColor3 = T.Colors.Ink,
								TextStrokeColor3 = Palette.Ink,
								TextStrokeTransparency = 1,
								TextXAlignment = Enum.TextXAlignment.Left,
							},
						}),
						RewardLabel = if nextReward.kind == "Bonks"
							then c(BonksLabel, {
								Amount = nextReward.amount or 0,
								TextColor = T.Colors.Ink,
								TextStroke = 0,
								Native = {
									Position = UDim2.fromScale(0.2, 0),
									Size = UDim2.fromScale(0.55, 1),
								},
								IconSize = UDim2.fromScale(0.2, 0.8),
							})
							else c(ResponsiveText, {
								MeasurementFont = T.Type.Label,
								MaxTextSize = 16,
								Truncate = true,
								Native = {
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(0.22, 0),
									Size = UDim2.fromScale(0.78, 1),
									Font = T.Type.Label,
									Text = if Cosmetics.Items[nextReward.itemId]
										then Cosmetics.Items[nextReward.itemId].DisplayName
										else "Cosmetic",
									TextColor3 = T.Colors.Ink,
									TextStrokeColor3 = Palette.Ink,
									TextStrokeTransparency = 1,
									TextXAlignment = Enum.TextXAlignment.Left,
								},
							}),
					})
					else nil,
			}),
		}),
	})
end
