-- Description: Responsive splash card showing season tier, XP progress, and the next free reward.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local SeasonClaims = require(script.Parent.Parent.Models.SeasonClaims)
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Palette = UIConfig.ProgressionStyle
local Surface = require(script.Parent.Arena.Surface)
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))

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
	if state == nil or state.active == false then
		return nil
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
	local native = {
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

	return c(Surface, { Native = native, Color = Palette.Panel, Radius = 10 }, {
		HeaderBand = c("Frame", {
			BackgroundColor3 = Palette.Pink,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 32),
			Visible = not compact,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
		}),
		Title = if not compact
			then c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				MinTextSize = 14,
				MaxTextSize = 22,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.new(0.5, 0, 0, 4),
					Size = UDim2.new(1, -24, 0, 32),
					Text = "SEASON PROGRESS",
					TextColor3 = Color3.new(1, 1, 1),
					TextStrokeColor3 = DARK,
					TextStrokeTransparency = 0.72,
					ZIndex = 2,
				},
			})
			else nil,
		Content = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.Track,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0.5, if compact then 0 else 18),
			Size = UDim2.new(1, -20, 1, if compact then -12 else -48),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.12, 0) }),
			TierBadge = c("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = TIER_BADGE_COLOR,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.02, 0.5),
				Size = UDim2.fromScale(if compact then 0.17 else 0.21, 0.84),
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.14, 0) }),
				Stroke = c("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }),
				TierWord = c(ResponsiveText, {
					MeasurementFont = UIConfig.Text.BodyFont,
					MinTextSize = if compact then 8 else 10,
					MaxTextSize = if compact then 12 else 16,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.fromEnum(UIConfig.Text.BodyFont),
						Position = UDim2.fromScale(0.5, 0.07),
						Size = UDim2.fromScale(0.82, 0.28),
						Text = "TIER",
						TextColor3 = Color3.new(1, 1, 1),
						TextStrokeColor3 = Palette.Ink,
						TextStrokeTransparency = 0.35,
					},
				}),
				TierNumber = c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					MinTextSize = if compact then 10 else 14,
					MaxTextSize = if compact then 24 else 32,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.5, 0.65),
						Size = UDim2.fromScale(0.82, 0.48),
						Text = tostring(tier),
						TextColor3 = Color3.new(1, 1, 1),
						TextStrokeColor3 = Palette.Ink,
						TextStrokeTransparency = 0.35,
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
					Position = UDim2.new(1, -2, 0.5, 0),
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
					MeasurementFont = UIConfig.Text.BodyFont,
					MinTextSize = if compact then 9 else 12,
					MaxTextSize = if compact then 17 else 23,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.fromEnum(UIConfig.Text.BodyFont),
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, if compact then 0.42 else 0.24),
						Text = if compact then "SEASON" else displayName,
						TextColor3 = Palette.White,
						TextStrokeColor3 = Palette.Ink,
						TextStrokeTransparency = 0.35,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					},
				}),
				ProgressBar = c("Frame", {
					BackgroundColor3 = Palette.Track,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, if compact then 0.48 else 0.3),
					Size = UDim2.fromScale(1, if compact then 0.16 else 0.16),
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Fill = c("Frame", {
						BackgroundColor3 = PROGRESS_FILL_COLOR,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(progressFraction, 1),
					}, {
						Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					}),
				}),
				XPLabel = c(ResponsiveText, {
					MeasurementFont = UIConfig.Text.BodyFont,
					MinTextSize = if compact then 8 else 10,
					MaxTextSize = if compact then 13 else 16,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.fromEnum(UIConfig.Text.BodyFont),
						Position = UDim2.fromScale(0, if compact then 0.68 else 0.5),
						Size = UDim2.fromScale(1, if compact then 0.3 else 0.18),
						Text = if isMaxTier then "MAX TIER" else `{xpIntoTier} / {xpForNextTier} XP`,
						TextColor3 = Palette.White,
						TextStrokeColor3 = Palette.Ink,
						TextStrokeTransparency = 0.35,
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
							MeasurementFont = UIConfig.Text.BodyFont,
							MinTextSize = 10,
							MaxTextSize = 15,
							Native = {
								BackgroundTransparency = 1,
								FontFace = Font.fromEnum(UIConfig.Text.BodyFont),
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(0.22, 1),
								Text = "NEXT",
								TextColor3 = Palette.White,
								TextStrokeColor3 = Palette.Ink,
								TextStrokeTransparency = 0.35,
								TextXAlignment = Enum.TextXAlignment.Left,
							},
						}),
						RewardLabel = if nextReward.kind == "Bonks"
							then c(BonksLabel, {
								Amount = nextReward.amount or 0,
								TextColor = Palette.White,
								TextStroke = 0.045,
								Native = {
									Position = UDim2.fromScale(0.2, 0),
									Size = UDim2.fromScale(0.55, 1),
								},
								IconSize = UDim2.fromScale(0.2, 0.8),
							})
							else c(ResponsiveText, {
								MeasurementFont = UIConfig.Text.BodyFont,
								MaxTextSize = 16,
								Truncate = true,
								Native = {
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(0.22, 0),
									Size = UDim2.fromScale(0.78, 1),
									Font = UIConfig.Text.BodyFont,
									Text = if Cosmetics.Items[nextReward.itemId]
										then Cosmetics.Items[nextReward.itemId].DisplayName
										else "Cosmetic",
									TextColor3 = Palette.White,
									TextStrokeColor3 = Palette.Ink,
									TextStrokeTransparency = 0.35,
									TextXAlignment = Enum.TextXAlignment.Left,
								},
							}),
					})
					else nil,
			}),
		}),
	})
end
