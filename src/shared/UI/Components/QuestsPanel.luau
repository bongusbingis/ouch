-- Name: QuestsPanel.luau
-- Author: Jack C.
-- Description: Splash screen panel showing the 3 daily quests with progress bars, rewards, and claim buttons.
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
local PANEL_SLICE_SCALE = 0.5

local PROGRESS_FILL_COLOR = Color3.fromRGB(154, 233, 91)
local PROGRESS_BG_COLOR = Color3.fromRGB(60, 60, 60)
local CLAIM_BUTTON_COLOR = Color3.fromRGB(154, 233, 91)
local CLAIMED_COLOR = Color3.fromRGB(100, 100, 100)

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
}

local function QuestRow(rowProps: { Quest: PublicQuest, Order: number, OnClaim: ((questId: string) -> ())? })
	local quest = rowProps.Quest
	local completed = quest.progress >= quest.goal
	local progressFraction = math.clamp(quest.progress / math.max(quest.goal, 1), 0, 1)

	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = rowProps.Order,
		Size = UDim2.fromScale(1, 0.28),
	}, {
		QuestInfo = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(0.7, 1),
		}, {
			Title = c(ResponsiveText, {
				MeasurementFont = Enum.Font.Highway,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 0.35),
					Text = quest.title,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				},
			}),
			ProgressBarBg = c("Frame", {
				BackgroundColor3 = PROGRESS_BG_COLOR,
				Position = UDim2.fromScale(0, 0.45),
				Size = UDim2.fromScale(1, 0.2),
			}, {
				UICorner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				Fill = c("Frame", {
					BackgroundColor3 = PROGRESS_FILL_COLOR,
					Size = UDim2.fromScale(progressFraction, 1),
				}, {
					UICorner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				}),
			}),
			ProgressLabel = c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
					Position = UDim2.fromScale(0, 0.72),
					Size = UDim2.fromScale(1, 0.25),
					Text = `{quest.progress}/{quest.goal}`,
					TextColor3 = Color3.fromRGB(200, 200, 200),
					TextXAlignment = Enum.TextXAlignment.Right,
				},
			}),
		}),
		RightSection = c("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromScale(0.27, 0.8),
		}, {
			ClaimButton = if completed and not quest.claimed
				then c(AnimatedButton, {
					Style = "Primary",
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://94748581468730",
						ImageColor3 = CLAIM_BUTTON_COLOR,
						Position = UDim2.fromScale(0.5, 0.5),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromScale(1, 0.8),
						SliceCenter = Rect.new(198, 228, 841, 468),
						SliceScale = 0.2,
					},
					OnActivated = function()
						if rowProps.OnClaim then
							rowProps.OnClaim(quest.id)
						end
					end,
				}, {
					UIAspectRatioConstraint = c("UIAspectRatioConstraint", { AspectRatio = 2.5 }),
					TextLabel = c(ResponsiveText, {
						MeasurementFont = Enum.Font.LuckiestGuy,
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
							Position = UDim2.fromScale(0.5, 0.54),
							Size = UDim2.fromScale(0.8, 0.6),
							Text = "CLAIM",
							TextColor3 = Color3.new(1, 1, 1),
							ZIndex = 2,
						},
					}),
				})
				else nil,
			ClaimedMark = if quest.claimed
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.6, 0.5),
						Text = "✓",
						TextColor3 = CLAIMED_COLOR,
					},
				})
				else nil,
			RewardPreview = if not completed and not quest.claimed and quest.reward.kind == "Bonks"
				then c(BonksLabel, {
					Amount = quest.reward.amount or 0,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 0.6),
					},
					IconSize = UDim2.fromScale(0.25, 0.8),
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

	local questRows = {
		UIListLayout = c("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.03, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
	}
	for index, quest in state.quests do
		questRows[`Quest{index}`] = c(QuestRow, {
			Quest = quest,
			Order = index,
			OnClaim = props.OnClaim,
		})
	end

	return c("ImageLabel", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Image = PANEL_NINE_SLICE,
		Position = UDim2.fromScale(0.985, 0.37),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromScale(0.36, 0.38),
		SliceCenter = PANEL_SLICE_CENTER,
		SliceScale = PANEL_SLICE_SCALE,
	}, {
		UIPadding = c("UIPadding", {
			PaddingTop = UDim.new(0.04, 0),
			PaddingBottom = UDim.new(0.04, 0),
			PaddingLeft = UDim.new(0.04, 0),
			PaddingRight = UDim.new(0.04, 0),
		}),
		Title = c(ResponsiveText, {
			HostName = "Title",
			MeasurementFont = Enum.Font.LuckiestGuy,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.9, 0.12),
				Text = "DAILY QUESTS",
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 2,
			},
		}),
		QuestList = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(1, 0.82),
		}, questRows),
	})
end
