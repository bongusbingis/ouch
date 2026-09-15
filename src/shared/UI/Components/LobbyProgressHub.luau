--!strict
-- The splash's progression hub presents existing projections and claim callbacks.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local SeasonClaims = require(script.Parent.Parent.Models.SeasonClaims)
local Panel = require(script.Parent.CandyPanel)
local Button = require(script.Parent.PuffyButton)
local Progress = require(script.Parent.CandyProgressBar)
local Text = require(script.Parent.LobbyText)
local Icon = require(script.Parent.Icon)
local Bonks = require(script.Parent.BonksLabel)
local Scroll = require(script.Parent.ScrollFrame)
local c, C, S = React.createElement, T.Colors, T.Splash

local function message(text)
	return c(
		Text,
		{ Text = text, TextColor3 = C.InkSoft, Font = Enum.Font.BuilderSans, Size = UDim2.new(1, -8, 0, 76) }
	)
end

local function QuestRow(props)
	local q = props.Quest
	local dense = props.Compact == true
	local rowHeight = if dense then T.LobbyLandscape.QuestHeight else S.QuestHeight
	local complete = q.progress >= q.goal
	local ready = complete and not q.claimed
	return c("Frame", {
		BackgroundColor3 = if ready then C.Yellow:Lerp(C.Surface, 0.8) else C.Well,
		BorderSizePixel = 0,
		LayoutOrder = props.Order,
		Size = UDim2.new(1, -8, 0, rowHeight),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
		Outline = c("UIStroke", { Color = if ready then C.Yellow else C.WellLine, Thickness = 2 }),
		Title = c(Text, {
			Text = q.title,
			Position = UDim2.fromOffset(14, if dense then 6 else 10),
			Size = UDim2.new(1, -138, 0, if dense then 40 else 44),
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		Meter = c(Progress, {
			Progress = math.clamp(q.progress / math.max(q.goal, 1), 0, 1),
			Color = if complete then C.Lime else C.Pink,
			Native = {
				Position = UDim2.fromOffset(14, if dense then 54 else 65),
				Size = UDim2.new(1, -138, 0, if dense then 8 else 12),
			},
		}),
		Count = c(Text, {
			Text = `{q.progress} / {q.goal}`,
			TextColor3 = C.InkSoft,
			Position = UDim2.fromOffset(14, if dense then 68 else 83),
			Size = UDim2.new(1, -138, 0, 22),
		}),
		Reward = if q.reward.kind == "Bonks"
			then c(Bonks, {
				Amount = q.reward.amount or 0,
				TextColor = C.Ink,
				TextStroke = 0,
				MaxTextSize = 20,
				Native = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, if dense then 4 else 12),
					Size = UDim2.fromOffset(104, if dense then 24 else 26),
				},
			})
			else c(Text, {
				Text = "REWARD",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, if dense then 4 else 12),
				Size = UDim2.fromOffset(104, if dense then 24 else 26),
			}),
		Claim = if ready
			then c(Button, {
				Text = if props.Pending then "WAIT..." else "CLAIM",
				TextSize = 18,
				Enabled = props.OnClaim ~= nil and not props.Pending,
				Shadow = false,
				Color = C.Pink,
				LipColor = C.PinkLip,
				StrokeColor = C.Ink,
				Native = {
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -12, 1, if dense then -6 else -12),
					Size = UDim2.fromOffset(104, if dense then 44 else 48),
				},
				OnActivated = function()
					if props.OnClaim then
						props.OnClaim(q.questId)
					end
				end,
			})
			else c(Text, {
				Text = if q.claimed then "CLAIMED" else "IN PROGRESS",
				TextColor3 = C.InkSoft,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -10, 1, if dense then -6 else -12),
				Size = UDim2.fromOffset(108, if dense then 44 else 48),
			}),
	})
end

local function seasonContent(props)
	local landscape = props.Landscape == true
	local state = props.SeasonState
	if not state then
		return message("Loading season progress...")
	end
	if state.active == false then
		return message("No active season.")
	end
	local maxed = (state.tier or 0) >= (state.tierCount or 0)
	local ready = SeasonClaims.count(state)
	return c(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, if landscape then 120 else S.SeasonContentHeight) },
		{
			Name = c(Text, {
				Text = state.displayName or "SEASON",
				Font = T.Type.Display,
				TextSize = if landscape then 18 else 22,
				Size = UDim2.new(1, if landscape then -74 else -110, 0, 32),
			}),
			Tier = c(Text, {
				Text = `TIER {state.tier or 0}`,
				TextColor3 = C.PinkLip,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(if landscape then 72 else 108, 32),
			}),
			Meter = c(Progress, {
				Progress = if maxed then 1 else (state.xpIntoTier or 0) / math.max(state.xpForNextTier or 1, 1),
				Native = {
					Position = UDim2.fromOffset(0, if landscape then 34 else 38),
					Size = UDim2.new(1, 0, 0, if landscape then 8 else 12),
				},
			}),
			XP = c(Text, {
				Text = if maxed then "MAX TIER" else `{state.xpIntoTier or 0} / {state.xpForNextTier or 1} XP`,
				TextColor3 = C.InkSoft,
				Position = UDim2.fromOffset(0, if landscape then 46 else 58),
				Size = UDim2.new(1, 0, 0, 24),
			}),
			View = c(Button, {
				Text = "VIEW REWARDS",
				TextSize = 18,
				TextColor = C.Ink,
				Color = C.Surface,
				LipColor = C.WellLine,
				Shadow = false,
				Enabled = props.OnViewSeasonRewards ~= nil,
				OnActivated = props.OnViewSeasonRewards,
				Native = {
					Position = UDim2.fromOffset(0, if landscape then 76 else 86),
					Size = UDim2.new(
						if ready > 0 then 0.58 else 1,
						if ready > 0 then -8 else 0,
						0,
						if landscape then 44 else 48
					),
				},
			}),
			Claim = if ready > 0
				then c(Button, {
					Text = if props.PendingClaims and props.PendingClaims.Season then "WAIT..." else `CLAIM {ready}`,
					TextSize = 18,
					Color = C.Pink,
					LipColor = C.PinkLip,
					Shadow = false,
					Enabled = props.OnClaimSeason ~= nil and not (props.PendingClaims and props.PendingClaims.Season),
					OnActivated = props.OnClaimSeason,
					Native = {
						Position = UDim2.new(0.58, 8, 0, if landscape then 76 else 86),
						Size = UDim2.new(0.42, -8, 0, if landscape then 44 else 48),
					},
				})
				else nil,
		}
	)
end

local function dailyContent(props)
	local state = props.DailyReward
	if not state then
		return message("Loading daily rewards...")
	end
	local days = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Padding = c("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3) }),
	}
	for index, day in state.days or {} do
		local claimed = day.claimed and not day.available
		days[`Day{index}`] = c("Frame", {
			BackgroundColor3 = if day.available
				then C.Pink:Lerp(C.Surface, 0.82)
				else if claimed then C.WellLine else C.Well,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(S.DayWidth, S.DayHeight),
			LayoutOrder = index,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Stroke = c("UIStroke", { Color = if day.available then C.Pink else C.WellLine, Thickness = 2 }),
			Day = c(Text, {
				Text = if claimed then "DONE" else `DAY {day.day}`,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 28),
				Position = UDim2.fromOffset(0, 5),
			}),
			Reward = if day.reward.kind == "Bonks"
				then c(Bonks, {
					Amount = day.reward.amount or 0,
					TextColor = C.Ink,
					TextStroke = 0,
					MaxTextSize = 18,
					Native = { Position = UDim2.fromOffset(2, 34), Size = UDim2.new(1, -4, 0, 26) },
				})
				else c(Text, {
					Text = "GIFT",
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(0, 34),
					Size = UDim2.new(1, 0, 0, 26),
				}),
			Mark = if claimed or day.available
				then c(Icon, {
					Name = if claimed then "Check" else "Star",
					Color = if day.available then C.PinkLip else C.InkSoft,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 61),
						Size = UDim2.fromOffset(18, 18),
					},
				})
				else nil,
		})
	end
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, S.DailyContentHeight) }, {
		Week = c(Scroll, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 92),
			ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = C.Pink,
		}, days),
		View = c(Button, {
			Text = if state.canClaim then "OPEN DAILY REWARD" else "VIEW DAILY REWARDS",
			TextSize = 18,
			Color = if state.canClaim then C.Pink else C.Surface,
			TextColor = if state.canClaim then C.Surface else C.Ink,
			LipColor = if state.canClaim then C.PinkLip else C.WellLine,
			Shadow = false,
			Enabled = props.OnViewDailyReward ~= nil,
			OnActivated = props.OnViewDailyReward,
			Native = { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 44) },
		}),
	})
end

return function(props)
	local active = props.SelectedTab or "SEASON"
	local contentTop = if props.Compact then S.CompactProgressContentTop else S.ProgressContentTop
	local readyQuests = 0
	for _, q in if props.QuestState then props.QuestState.quests else {} do
		if q.progress >= q.goal and not q.claimed then
			readyQuests += 1
		end
	end
	local tabs = {}
	for index, name in { "SEASON", "QUESTS", "DAILY" } do
		local ready = if name == "QUESTS"
			then readyQuests
			else if name == "DAILY"
				then (if props.DailyReward and props.DailyReward.canClaim then 1 else 0)
				else SeasonClaims.count(props.SeasonState)
		tabs[name] = c(Button, {
			Text = name .. (if ready > 0 then ` ({ready})` else ""),
			TextSize = 18,
			Color = if active == name then C.Pink else C.Surface,
			LipColor = if active == name then C.PinkLip else C.WellLine,
			TextColor = if active == name then C.Surface else C.Ink,
			Shadow = false,
			Native = { Position = UDim2.fromScale((index - 1) / 3, 0), Size = UDim2.new(1 / 3, -8, 1, 0) },
			OnActivated = function()
				if props.OnSelectTab then
					props.OnSelectTab(name)
				end
			end,
		})
	end
	local content = {
		Layout = c("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, if props.Compact then 0 else 2),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 3),
		}),
	}
	if active == "DAILY" then
		content.Daily = dailyContent(props)
	elseif active == "SEASON" then
		content.Season = seasonContent(props)
	elseif props.QuestState == nil then
		content.Loading = message("Loading your daily quests...")
	elseif #props.QuestState.quests == 0 then
		content.Empty = message("No quests available yet.")
	else
		for index, q in props.QuestState.quests do
			content[q.questId] = c(QuestRow, {
				Quest = q,
				Compact = props.Compact,
				Order = index,
				Pending = props.PendingClaims and props.PendingClaims[q.questId],
				OnClaim = props.OnClaimQuest,
			})
		end
	end
	return c(Panel, { Native = props.Native, Tilt = 0, Shadow = false }, {
		Back = if props.OnBack
			then c(Button, {
				Text = "<",
				TextSize = 24,
				TextColor = C.Ink,
				Color = C.Surface,
				LipColor = C.WellLine,
				Shadow = false,
				Native = {
					Position = UDim2.fromOffset(16, S.ProgressTabTop),
					Size = UDim2.fromOffset(44, 44),
				},
				OnActivated = props.OnBack,
			})
			else nil,
		Tabs = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(if props.OnBack then 72 else 16, S.ProgressTabTop),
			Size = UDim2.new(1, if props.OnBack then -80 else -24, 0, S.ProgressTabHeight),
		}, tabs),
		Content = c(Scroll, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(16, contentTop),
			Size = UDim2.new(1, -32, 1, -contentTop - 4),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = C.Pink,
		}, content),
	})
end
