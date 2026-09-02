-- Name: SeasonStatusCard.luau
-- Author: Jack C.
-- Description: Compact splash screen card showing the player's current season tier, XP progress bar, and next free reward.
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
local PANEL_SLICE_SCALE = 0.5

local PROGRESS_FILL_COLOR = Color3.fromRGB(154, 233, 91)
local PROGRESS_BG_COLOR = Color3.fromRGB(60, 60, 60)
local TIER_BADGE_COLOR = Color3.fromRGB(255, 211, 51)

export type Props = {
	State: any?,
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

	local tier = state.tier or 0
	local tierCount = state.tierCount or 0
	local xpIntoTier = state.xpIntoTier or 0
	local xpForNextTier = state.xpForNextTier or 1
	local displayName = state.displayName or "SEASON"
	local isMaxTier = tier >= tierCount
	local progressFraction = if isMaxTier then 1 else math.clamp(xpIntoTier / xpForNextTier, 0, 1)

	local nextReward = if state.tiers then findNextFreeReward(state.tiers) else nil

	return c("ImageLabel", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Image = PANEL_NINE_SLICE,
		Position = UDim2.fromScale(0.985, 0.14),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(0.22, 0.2),
		SliceCenter = PANEL_SLICE_CENTER,
		SliceScale = PANEL_SLICE_SCALE,
	}, {
		UIPadding = c("UIPadding", {
			PaddingTop = UDim.new(0.06, 0),
			PaddingBottom = UDim.new(0.06, 0),
			PaddingLeft = UDim.new(0.05, 0),
			PaddingRight = UDim.new(0.05, 0),
		}),
		Title = c(ResponsiveText, {
			HostName = "Title",
			MeasurementFont = Enum.Font.LuckiestGuy,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.9, 0.18),
				Text = "SEASON",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 2,
			},
		}),
		Content = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(1, 0.7),
		}, {
			TierBadge = c("Frame", {
				BackgroundColor3 = TIER_BADGE_COLOR,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(0.25, 1),
			}, {
				UICorner = c("UICorner", { CornerRadius = UDim.new(0.15, 0) }),
				UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 0.85 }),
				TierWord = c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
						Position = UDim2.fromScale(0.5, 0.08),
						Size = UDim2.fromScale(0.8, 0.25),
						Text = "TIER",
						TextColor3 = Color3.fromRGB(24, 41, 48),
					},
				}),
				TierNumber = c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.5, 0.62),
						Size = UDim2.fromScale(0.8, 0.45),
						Text = tostring(tier),
						TextColor3 = Color3.fromRGB(24, 41, 48),
					},
				}),
			}),
			Info = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.3, 0),
				Size = UDim2.fromScale(0.7, 1),
			}, {
				SeasonName = c(ResponsiveText, {
					MeasurementFont = Enum.Font.Highway,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 0.22),
						Text = displayName,
						TextColor3 = Color3.new(1, 1, 1),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					},
				}),
				ProgressBarBg = c("Frame", {
					BackgroundColor3 = PROGRESS_BG_COLOR,
					Position = UDim2.fromScale(0, 0.3),
					Size = UDim2.fromScale(1, 0.18),
				}, {
					UICorner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
					Fill = c("Frame", {
						BackgroundColor3 = PROGRESS_FILL_COLOR,
						Size = UDim2.fromScale(progressFraction, 1),
					}, {
						UICorner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
					}),
				}),
				XPLabel = c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
						Position = UDim2.fromScale(0, 0.52),
						Size = UDim2.fromScale(1, 0.18),
						Text = if isMaxTier then "MAX TIER" else `{xpIntoTier} / {xpForNextTier} XP`,
						TextColor3 = Color3.fromRGB(200, 200, 200),
						TextXAlignment = Enum.TextXAlignment.Left,
					},
				}),
				NextReward = if nextReward and nextReward.kind == "Bonks"
					then c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0, 0.75),
						Size = UDim2.fromScale(1, 0.25),
					}, {
						NextLabel = c(ResponsiveText, {
							MeasurementFont = Enum.Font.SourceSansBold,
							Native = {
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/SourceSansPro.json",
									Enum.FontWeight.Bold
								),
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(0.2, 1),
								Text = "NEXT:",
								TextColor3 = Color3.fromRGB(180, 180, 180),
								TextXAlignment = Enum.TextXAlignment.Left,
							},
						}),
						RewardLabel = c(BonksLabel, {
							Amount = nextReward.amount or 0,
							Native = {
								Position = UDim2.fromScale(0.2, 0),
								Size = UDim2.fromScale(0.6, 1),
							},
							IconSize = UDim2.fromScale(0.15, 0.8),
						}),
					})
					else nil,
			}),
		}),
	})
end
