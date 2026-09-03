-- Name: QuestsPanel.luau
-- Author: Jack C.
-- Description: Responsive splash card showing daily quest progress, rewards, and claim actions.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local AnimatedButton = require(script.Parent.AnimatedButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)

local c = React.createElement

local PANEL_NINE_SLICE = "rbxassetid://124751224634629"
local PANEL_SLICE_CENTER = Rect.new(31, 41, 978, 620)
local CLAIM_BUTTON_ASSET = "rbxassetid://94748581468730"

local DARK = Color3.fromRGB(24, 41, 48)
local MUTED = Color3.fromRGB(194, 221, 226)
local PROGRESS_FILL_COLOR = Color3.fromRGB(154, 233, 91)
local CLAIM_BUTTON_COLOR = Color3.fromRGB(154, 233, 91)

export type PublicQuest = {
	id: string,
	title: string,
	progress: number,
	goal: number,
	claimed: boolean,
	reward: { kind: string, amount: number?, itemId: string? },
}

export type QuestState = {
	dailyKey: string,
	resetAt: number,
	quests: { PublicQuest },
}

export type Props = {
	State: QuestState?,
	OnClaim: ((questId: string) -> ())?,
	Compact: boolean?,
	Native: { [any]: any }?,
}

local function QuestRow(rowProps: {
	Quest: PublicQuest,
	Order: number,
	OnClaim: ((questId: string) -> ())?,
	Compact: boolean,
})
	local quest = rowProps.Quest
	local compact = rowProps.Compact
	local completed = quest.progress >= quest.goal
	local progressFraction = math.clamp(quest.progress / math.max(quest.goal, 1), 0, 1)

	return c("Frame", {
		BackgroundColor3 = DARK,
		BackgroundTransparency = if compact then 0.74 else 0.68,
		BorderSizePixel = 0,
		LayoutOrder = rowProps.Order,
		Size = UDim2.fromScale(1, 0.3),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0.12, 0) }),
		QuestInfo = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.025, 0),
			Size = UDim2.fromScale(0.71, 1),
		}, {
			Title = c(ResponsiveText, {
				MeasurementFont = Enum.Font.Highway,
				MinTextSize = if compact then 8 else 11,
				MaxTextSize = if compact then 14 else 22,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
					Position = UDim2.fromScale(0, if compact then 0.03 else 0.08),
					Size = UDim2.fromScale(1, if compact then 0.48 else 0.34),
					Text = quest.title,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				},
			}),
			ProgressBar = c("Frame", {
				BackgroundColor3 = DARK,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, if compact then 0.62 else 0.5),
				Size = UDim2.fromScale(1, if compact then 0.18 else 0.17),
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
			ProgressLabel = if not compact
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSansBold,
					MinTextSize = 10,
					MaxTextSize = 15,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
						Position = UDim2.fromScale(0, 0.7),
						Size = UDim2.fromScale(1, 0.22),
						Text = `{quest.progress}/{quest.goal}`,
						TextColor3 = MUTED,
						TextXAlignment = Enum.TextXAlignment.Right,
					},
				})
				else nil,
		}),
		RightSection = c("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.975, 0.5),
			Size = UDim2.fromScale(0.22, if compact then 0.78 else 0.72),
		}, {
			ClaimButton = if completed and not quest.claimed
				then c(AnimatedButton, {
					Style = "Primary",
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = CLAIM_BUTTON_ASSET,
						ImageColor3 = CLAIM_BUTTON_COLOR,
						Position = UDim2.fromScale(0.5, 0.5),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromScale(1, 1),
						SliceCenter = Rect.new(198, 228, 841, 468),
						SliceScale = 0.2,
					},
					OnActivated = function()
						if rowProps.OnClaim then
							rowProps.OnClaim(quest.id)
						end
					end,
				}, {
					Aspect = c("UIAspectRatioConstraint", { AspectRatio = if compact then 3.3 else 2.8 }),
					TextLabel = c(ResponsiveText, {
						MeasurementFont = Enum.Font.LuckiestGuy,
						MinTextSize = if compact then 8 else 10,
						MaxTextSize = if compact then 13 else 19,
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
							Position = UDim2.fromScale(0.5, 0.54),
							Size = UDim2.fromScale(0.78, 0.58),
							Text = "CLAIM",
							TextColor3 = Color3.new(1, 1, 1),
							ZIndex = 2,
						},
					}),
				})
				else nil,
			Claimed = if quest.claimed
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					MinTextSize = if compact then 8 else 10,
					MaxTextSize = if compact then 14 else 20,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.94, 0.62),
						Text = "DONE",
						TextColor3 = PROGRESS_FILL_COLOR,
					},
				})
				else nil,
			RewardPreview = if not completed
					and not quest.claimed
					and quest.reward.kind == "Bonks"
				then c(BonksLabel, {
					Amount = quest.reward.amount or 0,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, if compact then 0.72 else 0.62),
					},
					IconSize = UDim2.fromScale(if compact then 0.25 else 0.22, 0.8),
				})
				else nil,
		}),
	})
end

return function(props: Props)
	local state = props.State
	if state == nil then
		return nil
	end

	local compact = props.Compact == true
	local questRows = {
		Layout = c("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.025, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
	}
	for index, quest in state.quests do
		questRows[`Quest{index}`] = c(QuestRow, {
			Quest = quest,
			Order = index,
			OnClaim = props.OnClaim,
			Compact = compact,
		})
	end

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
		Title = c(ResponsiveText, {
			HostName = "Title",
			MeasurementFont = Enum.Font.LuckiestGuy,
			MinTextSize = if compact then 10 else 14,
			MaxTextSize = if compact then 19 else 32,
			Native = {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(if compact then 0.04 else 0.055, 0.045),
				Size = UDim2.fromScale(if compact then 0.92 else 0.89, if compact then 0.16 else 0.14),
				Text = "DAILY QUESTS",
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeColor3 = DARK,
				TextStrokeTransparency = 0.72,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			},
		}),
		QuestList = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.95),
			Size = UDim2.fromScale(if compact then 0.94 else 0.9, if compact then 0.75 else 0.76),
		}, questRows),
	})
end
