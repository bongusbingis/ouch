-- Name: SeasonStatusCard.luau
-- Author: Jack C.
-- Description: Responsive splash card showing season tier, XP progress, and the next free reward.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)

local c = React.createElement

local PANEL_NINE_SLICE = "rbxassetid://124751224634629"
local PANEL_SLICE_CENTER = Rect.new(31, 41, 978, 620)

local DARK = Color3.fromRGB(24, 41, 48)
local MUTED = Color3.fromRGB(194, 221, 226)
local PROGRESS_FILL_COLOR = Color3.fromRGB(154, 233, 91)
local TIER_BADGE_COLOR = Color3.fromRGB(255, 211, 51)

export type Props = {
	State: any?,
	Compact: boolean?,
	Native: { [any]: any }?,
}

local function findNextFreeReward(tiers: { any }): { kind: string, amount: number? }?
	for _, tier in tiers do
		if not tier.unlocked and tier.freeReward then
			return tier.freeReward
		end
	end
	return nil
end

return function(props: Props)
	local state = props.State
	if state == nil or state.active == false then
		return nil
	end

	local compact = props.Compact == true
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
		BackgroundTransparency = 1,
		Image = PANEL_NINE_SLICE,
		Position = UDim2.fromScale(0, 0),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(1, 1),
		SliceCenter = PANEL_SLICE_CENTER,
		SliceScale = if compact then 0.35 else 0.5,
	}
	if props.Native then
		for key, value in props.Native do
			native[key] = value
		end
	end

	return c("ImageLabel", native, {
		Title = if not compact
			then c(ResponsiveText, {
				HostName = "Title",
				MeasurementFont = Enum.Font.LuckiestGuy,
				MinTextSize = 14,
				MaxTextSize = 30,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
					Position = UDim2.fromScale(0.5, 0.06),
					Size = UDim2.fromScale(0.88, 0.17),
					Text = "SEASON",
					TextColor3 = Color3.new(1, 1, 1),
					TextStrokeColor3 = DARK,
					TextStrokeTransparency = 0.72,
					ZIndex = 2,
				},
			})
			else nil,
		Content = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = DARK,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, if compact then 0.5 else 0.61),
			Size = UDim2.fromScale(if compact then 0.94 else 0.9, if compact then 0.76 else 0.62),
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
				Aspect = if compact then nil else c("UIAspectRatioConstraint", { AspectRatio = 0.85 }),
				TierWord = c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					MinTextSize = if compact then 8 else 10,
					MaxTextSize = if compact then 12 else 16,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
						Position = UDim2.fromScale(0.5, 0.07),
						Size = UDim2.fromScale(0.82, 0.28),
						Text = "TIER",
						TextColor3 = DARK,
					},
				}),
				TierNumber = c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					MinTextSize = if compact then 10 else 14,
					MaxTextSize = if compact then 18 else 32,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.5, 0.65),
						Size = UDim2.fromScale(0.82, 0.48),
						Text = tostring(tier),
						TextColor3 = DARK,
					},
				}),
			}),
			Info = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(if compact then 0.22 else 0.27, 0.08),
				Size = UDim2.fromScale(if compact then 0.75 else 0.7, 0.84),
			}, {
				SeasonName = c(ResponsiveText, {
					MeasurementFont = if compact then Enum.Font.SourceSansBold else Enum.Font.Highway,
					MinTextSize = if compact then 9 else 12,
					MaxTextSize = if compact then 17 else 23,
					Native = {
						BackgroundTransparency = 1,
						FontFace = if compact
							then Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
							else Font.new("rbxasset://fonts/families/HighwayGothic.json"),
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, if compact then 0.42 else 0.24),
						Text = if compact then `SEASON · {displayName}` else displayName,
						TextColor3 = Color3.new(1, 1, 1),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					},
				}),
				ProgressBar = c("Frame", {
					BackgroundColor3 = DARK,
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
					MeasurementFont = Enum.Font.SourceSansBold,
					MinTextSize = if compact then 8 else 10,
					MaxTextSize = if compact then 13 else 16,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
						Position = UDim2.fromScale(0, if compact then 0.68 else 0.5),
						Size = UDim2.fromScale(1, if compact then 0.3 else 0.18),
						Text = if isMaxTier then "MAX TIER" else `{xpIntoTier} / {xpForNextTier} XP`,
						TextColor3 = MUTED,
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				}),
				NextReward = if not compact
						and nextReward
						and nextReward.kind == "Bonks"
					then c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0, 0.72),
						Size = UDim2.fromScale(1, 0.24),
					}, {
						NextLabel = c(ResponsiveText, {
							MeasurementFont = Enum.Font.SourceSansBold,
							MinTextSize = 10,
							MaxTextSize = 15,
							Native = {
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold
								),
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(0.22, 1),
								Text = "NEXT",
								TextColor3 = MUTED,
								TextXAlignment = Enum.TextXAlignment.Left,
							},
						}),
						RewardLabel = c(BonksLabel, {
							Amount = nextReward.amount or 0,
							Native = {
								Position = UDim2.fromScale(0.2, 0),
								Size = UDim2.fromScale(0.55, 1),
							},
							IconSize = UDim2.fromScale(0.2, 0.8),
						}),
					})
					else nil,
			}),
		}),
	})
end
