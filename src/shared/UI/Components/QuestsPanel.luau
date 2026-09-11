-- Description: Responsive splash card showing daily quest progress, rewards, and claim actions.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ShopPriceButton = require(script.Parent.Shop.ShopPriceButton)
local BonksLabel = require(script.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.ResponsiveText)

local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local QuestsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Quests"))
local Palette = UIConfig.ProgressionStyle
local Well = require(script.Parent.Well)

local Icon = require(script.Parent.Icon)
local ScrollFrame = require(script.Parent.ScrollFrame)

local c = React.createElement

local DARK = Palette.Ink
local PROGRESS_FILL_COLOR = Palette.Pink
local CLAIM_BUTTON_COLOR = Palette.Pink

local function textStroke(thickness: number)
	return c("UIStroke", {
		Color = DARK,
		Thickness = thickness,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
	})
end

-- Each quest carries the icon of what it tracks; the id comes from the
-- definition so the public quest projection stays exactly what the server
-- sends today.
local function questIcon(questId: string): string?
	for _, definition in QuestsConfig.Definitions do
		if definition.id == questId then
			return definition.Icon
		end
	end
	return nil
end

local function rowHeight(compact: boolean, short: boolean): number
	return if short
		then UIConfig.Layout.QuestRow.ShortHeightPx
		else if compact then UIConfig.Layout.QuestRow.CompactHeightPx else 80
end

export type PublicQuest = {
	questId: string,
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
	Expanded: boolean?,
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
	local icon = questIcon(quest.questId)
	local tile = if icon then 32 else 0
	local infoLeft = 10 + (if icon then tile + 10 else 0)

	return c("Frame", {
		BackgroundColor3 = Palette.Ink,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		LayoutOrder = rowProps.Order,
		Size = UDim2.new(1, -8, 0, rowHeight(compact, short)),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Tile) }),
		Stroke = if completed and not quest.claimed
			then c("UIStroke", {
				Color = if completed then Palette.Yellow else Palette.White,
				Thickness = UIConfig.Well.StrokePx,
				Transparency = if completed and not quest.claimed then 0 else 0.7,
			})
			else nil,
		IconTile = if icon
			then c("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Palette.Ink,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 10, if compact then 0 else 0.5, if compact then 8 + tile / 2 else 0),
				Size = UDim2.fromOffset(tile, tile),
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Tile) }),
				Glyph = c(Icon, {
					Name = icon,
					Color = if completed then Palette.Yellow else Palette.White,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(0.9, 0.9),
					},
				}),
			})
			else nil,
		QuestInfo = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(infoLeft, 0),
			Size = if compact
				then UDim2.new(1, -infoLeft - 10, 0, if short then 34 else UIConfig.Layout.QuestRow.CompactInfoHeightPx)
				else UDim2.new(1, -infoLeft - 104, 1, 0),
		}, {
			Title = c(ResponsiveText, {
				Wrapped = true,
				MeasurementFont = UIConfig.Text.BodyFont,
				MinTextSize = 14,
				MaxTextSize = if compact then 18 else 19,
				Native = {
					BackgroundTransparency = 1,
					Font = UIConfig.Text.BodyFont,
					Position = UDim2.fromOffset(0, 4),
					Size = UDim2.new(1, 0, 0, if short then 32 else 38),
					Text = if short and not completed
						then `{quest.title} ({quest.progress}/{quest.goal})`
						else quest.title,
					TextWrapped = true,
					TextColor3 = Palette.White,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),
			ProgressBar = c("Frame", {
				Visible = not short,
				BackgroundColor3 = Palette.Ink,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -30),
				Size = UDim2.new(1, 0, 0, 8),
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = c("Frame", {
					BackgroundColor3 = if completed then Palette.Yellow else PROGRESS_FILL_COLOR,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(progressFraction, 1),
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
			}),
			ProgressLabel = c(ResponsiveText, {
				MeasurementFont = UIConfig.Text.BodyFont,
				MinTextSize = 14,
				MaxTextSize = 16,
				Native = {
					BackgroundTransparency = 1,
					Font = UIConfig.Text.BodyFont,
					Visible = not short,
					Position = UDim2.new(0, 0, 1, -20),
					Size = UDim2.new(1, 0, 0, 18),
					Text = `{quest.progress}/{quest.goal}`,
					TextColor3 = Palette.White,
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
				then c(ShopPriceButton, {
					Enabled = rowProps.OnClaim ~= nil and not rowProps.Pending,
					Color = CLAIM_BUTTON_COLOR,
					Compact = true,
					Text = if rowProps.Pending then "WAIT…" else "CLAIM",
					TextSize = 20,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = if compact then UDim2.new(1, -44, 0.5, 0) else UDim2.new(0.5, 0, 1, -24),
					Size = UDim2.fromOffset(84, 44),
					ZIndex = 2,
					OnActivated = function()
						if rowProps.OnClaim then
							rowProps.OnClaim(quest.questId)
						end
					end,
				})
				else nil,
			Claimed = if quest.claimed
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.LuckiestGuy,
					MinTextSize = if compact then 8 else 10,
					MaxTextSize = if compact then 14 else 16,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
						Position = if compact then UDim2.new(1, -44, 0.5, 0) else UDim2.fromScale(0.5, 0.72),
						Size = if compact then UDim2.fromOffset(88, 24) else UDim2.fromScale(0.94, 0.38),
						Text = "CLAIMED",
						TextColor3 = Palette.Muted,
					},
				})
				else nil,
			RewardPreview = if quest.reward.kind == "Bonks"
				then c(BonksLabel, {
					Amount = quest.reward.amount or 0,
					TextColor = Palette.Yellow,
					TextStroke = 0.045,
					MaxTextSize = 20,
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
	local listRef = React.useRef(nil)
	local scrollHint, setScrollHint = React.useState(nil :: string?)
	local scrollAvailable = state ~= nil and props.Expanded ~= true
	React.useEffect(function()
		if not scrollAvailable then
			setScrollHint(nil)
			return
		end
		local list = listRef.current
		if not list then
			return
		end
		local function updateHint()
			local window = list.AbsoluteWindowSize.Y
			local overflow = list.AbsoluteCanvasSize.Y - window
			setScrollHint(
				if window <= 0 or overflow <= 1
					then nil
					elseif overflow - list.CanvasPosition.Y > 1 then "SCROLL ↓"
					else "SCROLL ↑"
			)
		end
		local connections = {}
		for _, property in { "AbsoluteCanvasSize", "AbsoluteWindowSize", "CanvasPosition" } do
			table.insert(connections, list:GetPropertyChangedSignal(property):Connect(updateHint))
		end
		updateHint()
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { scrollAvailable })
	if state == nil then
		return nil
	end

	local compact = props.Compact == true
	local short = props.Short == true
	local expanded = props.Expanded == true
	local listHeight = if #state.quests == 0 then 76 else #state.quests * (rowHeight(compact, short) + 8) + 8
	local questRows = {
		Layout = c("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
		Padding = c("UIPadding", {
			PaddingBottom = UDim.new(0, if expanded then 14 else 6),
			PaddingTop = UDim.new(0, 2),
		}),
	}
	if #state.quests == 0 then
		questRows.Empty = c(ResponsiveText, {
			MeasurementFont = UIConfig.Text.BodyFont,
			MinTextSize = 12,
			MaxTextSize = 20,
			Native = {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -16, 0, 60),
				Text = "NO QUESTS AVAILABLE YET",
				TextColor3 = Palette.White,
				Font = UIConfig.Text.BodyFont,
				TextWrapped = true,
			},
		})
	end
	for index, quest in state.quests do
		questRows[`Quest{index}`] = c(QuestRow, {
			Quest = quest,
			Pending = props.PendingClaims and props.PendingClaims[quest.questId],
			Order = index,
			OnClaim = props.OnClaim,
			Compact = compact,
			Short = short and not expanded,
		})
	end

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
	if expanded then
		native.Size = UDim2.new(native.Size.X.Scale, native.Size.X.Offset, 0, listHeight + if short then 40 else 52)
	end

	return c(Well, { Native = native }, {
		Title = c(ResponsiveText, {
			HostName = "Title",
			MeasurementFont = Enum.Font.LuckiestGuy,
			MinTextSize = if compact then 10 else 14,
			MaxTextSize = if compact then 20 else 26,
			Native = {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
				Position = UDim2.fromOffset(18, 8),
				Size = UDim2.new(1, if scrollHint then -132 else -36, 0, if short then 28 else 36),
				Text = if short and scrollHint then "QUESTS" else "DAILY QUESTS",
				TextColor3 = Palette.White,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			},
		}, { Outline = textStroke(0.045) }),
		ScrollHint = if scrollHint
			then c("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -16, 0, 8),
				Size = UDim2.fromOffset(88, if short then 28 else 36),
				Font = UIConfig.Text.BodyFont,
				Text = scrollHint,
				TextSize = UIConfig.Text.CaptionMinPx,
				TextColor3 = Palette.White,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 2,
			})
			else nil,
		QuestList = if expanded
			then c("Frame", {
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(8, if short then 40 else 52),
				Size = UDim2.new(1, -16, 0, listHeight),
			}, questRows)
			else c(ScrollFrame, {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Palette.White,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -16),
				Size = UDim2.new(1, -32, 1, if short then -60 else -68),
				ScrollRef = listRef,
			}, questRows),
	})
end
