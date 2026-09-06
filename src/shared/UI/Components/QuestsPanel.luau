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

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Palette = UIConfig.ProgressionStyle

local c = React.createElement

local CLAIM_BUTTON_ASSET = "rbxassetid://94748581468730"

local DARK = Palette.Ink
local MUTED = Palette.Muted
local PROGRESS_FILL_COLOR = Palette.Cyan
local CLAIM_BUTTON_COLOR = Palette.Green

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
	PendingClaims: { [string]: boolean }?,
	OnClaim: ((questId: string) -> ())?,
	Compact: boolean?,
	Short: boolean?,
	Native: { [any]: any }?,
}

local function QuestRow(rowProps: {
	Quest: PublicQuest,
	Pending: boolean?,
	Order: number,
	OnClaim: ((questId: string) -> ())?,
	Compact: boolean,
	Short: boolean?,
})
	local quest = rowProps.Quest
	local compact = rowProps.Compact
	local short = rowProps.Short == true
	local completed = quest.progress >= quest.goal
	local progressFraction = math.clamp(quest.progress / math.max(quest.goal, 1), 0, 1)

	return c("Frame", {
		BackgroundColor3 = Palette.Raised,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		LayoutOrder = rowProps.Order,
		Size = UDim2.new(
			1,
			-8,
			0,
			if short
				then UIConfig.Layout.QuestRow.ShortHeightPx
				else if compact then UIConfig.Layout.QuestRow.CompactHeightPx else 86
		),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Stroke = c("UIStroke", {
			Color = if completed then Palette.Green else Palette.Muted,
			Thickness = 1,
			Transparency = if completed and not quest.claimed then 0 else 0.8,
		}),
		QuestInfo = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 0),
			Size = if compact
				then UDim2.new(1, -20, 0, if short then 34 else UIConfig.Layout.QuestRow.CompactInfoHeightPx)
				else UDim2.new(1, -114, 1, 0),
		}, {
			Title = c(ResponsiveText, {
				Wrapped = true,
				MeasurementFont = Enum.Font.SourceSansBold,
				MinTextSize = 14,
				MaxTextSize = if compact then 18 else 19,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
					Position = UDim2.fromOffset(0, 4),
					Size = UDim2.new(1, 0, 0, if short then 32 else 38),
					Text = if short and not completed
						then `{quest.title} ({quest.progress}/{quest.goal})`
						else quest.title,
					TextWrapped = true,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),
			ProgressBar = c("Frame", {
				Visible = not short,
				BackgroundColor3 = DARK,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -30),
				Size = UDim2.new(1, 0, 0, 8),
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = c("Frame", {
					BackgroundColor3 = if completed then Palette.Green else PROGRESS_FILL_COLOR,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(progressFraction, 1),
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
			}),
			ProgressLabel = c(ResponsiveText, {
				MeasurementFont = Enum.Font.SourceSansBold,
				MinTextSize = 10,
				MaxTextSize = 15,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
					Visible = not short,
					Position = UDim2.new(0, 0, 1, -20),
					Size = UDim2.new(1, 0, 0, 18),
					Text = `{quest.progress}/{quest.goal}`,
					TextColor3 = MUTED,
					TextXAlignment = Enum.TextXAlignment.Right,
				},
			}),
		}),
		RightSection = c("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position = if compact then UDim2.new(1, -8, 1, -26) else UDim2.new(1, -8, 0.5, 0),
			Size = if compact then UDim2.new(1, -16, 0, 44) else UDim2.new(0, 88, 1, -8),
		}, {
			ClaimButton = if completed and not quest.claimed
				then c(AnimatedButton, {
					Style = "Primary",
					Enabled = rowProps.OnClaim ~= nil and not rowProps.Pending,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = CLAIM_BUTTON_ASSET,
						ImageColor3 = CLAIM_BUTTON_COLOR,
						Position = if compact then UDim2.new(1, -44, 0.5, 0) else UDim2.new(0.5, 0, 1, -22),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromOffset(88, 44),
						SliceCenter = Rect.new(198, 228, 841, 468),
						SliceScale = 0.2,
					},
					OnActivated = function()
						if rowProps.OnClaim then
							rowProps.OnClaim(quest.id)
						end
					end,
				}, {

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
							Text = if rowProps.Pending then "CLAIMING..." else "CLAIM",
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
						Position = if compact then UDim2.new(1, -44, 0.5, 0) else UDim2.fromScale(0.5, 0.72),
						Size = if compact then UDim2.fromOffset(88, 24) else UDim2.fromScale(0.94, 0.38),
						Text = "CLAIMED",
						TextColor3 = PROGRESS_FILL_COLOR,
					},
				})
				else nil,
			RewardPreview = if quest.reward.kind == "Bonks"
				then c(BonksLabel, {
					Amount = quest.reward.amount or 0,
					Native = {
						AnchorPoint = if compact then Vector2.new(0, 0.5) else Vector2.new(0.5, 0.5),
						Position = if compact
							then UDim2.fromScale(0, 0.5)
							else UDim2.fromScale(0.5, if completed or quest.claimed then 0.19 else 0.5),
						Size = if compact and completed then UDim2.new(1, -92, 0, 24) else UDim2.new(1, 0, 0, 24),
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
	local short = props.Short == true
	local questRows = {
		Layout = c("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
		Padding = c("UIPadding", { PaddingBottom = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) }),
	}
	if #state.quests == 0 then
		questRows.Empty = c(ResponsiveText, {
			MeasurementFont = Enum.Font.Highway,
			MinTextSize = 12,
			MaxTextSize = 20,
			Native = {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -16, 0, 60),
				Text = "NO QUESTS AVAILABLE YET",
				TextColor3 = Palette.Muted,
				FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
				TextWrapped = true,
			},
		})
	end
	for index, quest in state.quests do
		questRows[`Quest{index}`] = c(QuestRow, {
			Quest = quest,
			Pending = props.PendingClaims and props.PendingClaims[quest.id],
			Order = index,
			OnClaim = props.OnClaim,
			Compact = compact,
			Short = short,
		})
	end

	local native = {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = Palette.Surface,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
	}
	if props.Native then
		for key, value in props.Native do
			native[key] = value
		end
	end

	return c("Frame", native, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Outline = c("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }),
		HeaderBand = c("Frame", {
			BackgroundColor3 = Palette.Cyan,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, if short then 24 else 36),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
		}),
		Title = c(ResponsiveText, {
			HostName = "Title",
			MeasurementFont = Enum.Font.LuckiestGuy,
			MinTextSize = if compact then 10 else 14,
			MaxTextSize = if compact then 20 else 26,
			Native = {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromOffset(14, 4),
				Size = UDim2.new(1, -28, 0, if short then 24 else 36),
				Text = "DAILY QUESTS",
				TextColor3 = DARK,
				TextStrokeColor3 = DARK,
				TextStrokeTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			},
		}),
		QuestList = c("ScrollingFrame", {
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Palette.Cyan,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 1, if short then -40 else -56),
		}, questRows),
	})
end
