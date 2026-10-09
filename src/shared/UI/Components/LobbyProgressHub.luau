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
local Ribbon = require(script.Parent.RarityRibbon)
local ResponsiveText = require(script.Parent.ResponsiveText)
local SplashLayout = require(script.Parent.Parent.Models.SplashLayout)
local Cosmetics = require(RS:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local c, C, S, K = React.createElement, T.Colors, T.Splash, T.Collectible
local DAY_GAP = 6

local function message(text)
	return c(Text, {
		Text = text,
		TextColor3 = C.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -8, 0, 76),
	})
end

-- Title and reward share the top line; the bar and one right-hand status slot
-- (count, CLAIM or CLAIMED) share the bottom line, so every row keeps the same
-- baselines whatever its state.
local function QuestRow(props)
	local q = props.Quest
	local dense = props.Compact == true
	local rowHeight = if dense then T.LobbyLandscape.QuestHeight else S.QuestHeight
	local inset = if dense then 6 else 12
	local titleY = if dense then 6 else 10
	local barHeight = if dense then 8 else 12
	local bottomY = rowHeight - inset - T.Layout.MinTarget
	local slotWidth = 104
	local reserve = slotWidth + 34
	local complete = q.progress >= q.goal
	local ready = complete and not q.claimed
	local slot
	if ready then
		slot = c(Button, {
			Text = if props.Pending then "WAIT..." else "CLAIM",
			TextSize = T.Type.Minimum,
			Enabled = props.OnClaim ~= nil and not props.Pending,
			Shadow = false,
			Color = C.Pink,
			LipColor = C.PinkLip,
			StrokeColor = C.Ink,
			Native = {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, bottomY),
				Size = UDim2.fromOffset(slotWidth, T.Layout.MinTarget),
			},
			OnActivated = function()
				if props.OnClaim then
					props.OnClaim(q.questId)
				end
			end,
		})
	elseif q.claimed then
		slot = c(Ribbon, {
			Text = "CLAIMED",
			Color = C.Lime,
			Native = {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0, bottomY + T.Layout.MinTarget / 2),
				Size = UDim2.fromOffset(slotWidth, K.TagHeight),
				ZIndex = 9,
			},
		})
	else
		slot = c(Text, {
			Text = `{q.progress} / {q.goal}`,
			TextColor3 = C.InkSoft,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, bottomY),
			Size = UDim2.fromOffset(slotWidth, T.Layout.MinTarget),
		})
	end
	return c("Frame", {
		BackgroundColor3 = if ready then C.Yellow:Lerp(C.Surface, 0.8) else C.Well,
		BorderSizePixel = 0,
		LayoutOrder = props.Order,
		Size = UDim2.new(1, -8, 0, rowHeight),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
		Outline = c("UIStroke", { Color = if ready then C.Yellow else C.WellLine, Thickness = T.Shape.StrokeInner }),
		Title = c(Text, {
			Text = string.upper(q.title),
			Position = UDim2.fromOffset(14, titleY),
			Size = UDim2.new(1, -reserve, 0, bottomY - titleY),
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Meter = c(Progress, {
			Progress = math.clamp(q.progress / math.max(q.goal, 1), 0, 1),
			Color = if complete then C.Lime else C.Pink,
			Native = {
				Position = UDim2.fromOffset(14, bottomY + (T.Layout.MinTarget - barHeight) / 2),
				Size = UDim2.new(1, -reserve, 0, barHeight),
			},
		}),
		Reward = if q.reward.kind == "Bonks"
			then c(Bonks, {
				Amount = q.reward.amount or 0,
				TextColor = C.Ink,
				TextStroke = 0,
				MaxTextSize = T.Type.Body,
				Native = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, titleY),
					Size = UDim2.fromOffset(slotWidth, 24),
				},
			})
			else c(Text, {
				Text = "REWARD",
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, titleY),
				Size = UDim2.fromOffset(slotWidth, 24),
			}),
		Status = slot,
	})
end

local function seasonContent(props)
	local landscape = props.Landscape == true
	local state = props.SeasonState
	if not state then
		return message("LOADING SEASON...")
	end
	if state.active == false then
		return message("NO ACTIVE SEASON")
	end
	local maxed = (state.tier or 0) >= (state.tierCount or 0)
	local ready = SeasonClaims.count(state)
	local xp = state.xpIntoTier or 0
	local actionHeight = if landscape then 44 else 48
	local actionInset = 4
	local actionY = if landscape then 76 else 86
	return c(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, SplashLayout.seasonContentHeight(landscape)) },
		{
			Name = c(ResponsiveText, {
				MeasurementFont = T.Type.Display,
				MinTextSize = T.Type.Minimum,
				MaxTextSize = if landscape then T.Type.Minimum else T.Type.TileLabel,
				Native = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, if landscape then -74 else -110, 0, 32),
					Font = T.Type.Display,
					Text = string.upper(state.displayName or "SEASON"),
					TextColor3 = C.Ink,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 8,
				},
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
				Progress = if maxed then 1 else xp / math.max(state.xpForNextTier or 1, 1),
				Native = {
					Position = UDim2.fromOffset(0, if landscape then 34 else 38),
					Size = UDim2.new(1, 0, 0, if landscape then 8 else 12),
				},
			}),
			-- An empty bar says what fills it rather than reading as a broken meter.
			XP = c(Text, {
				Text = if maxed
					then "MAX TIER"
					elseif xp <= 0 then "PLAY A MATCH TO EARN XP"
					else `{xp} / {state.xpForNextTier or 1} XP`,
				TextColor3 = C.InkSoft,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(0, if landscape then 46 else 58),
				Size = UDim2.new(1, 0, 0, 24),
			}),
			Actions = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(actionInset, actionY),
				Size = UDim2.new(1, -actionInset * 2, 0, actionHeight),
			}, {
				View = c(Button, {
					Text = "VIEW REWARDS",
					TextSize = T.Type.Minimum,
					TextColor = C.Ink,
					Color = C.Surface,
					LipColor = C.WellLine,
					Shadow = false,
					Enabled = props.OnViewSeasonRewards ~= nil,
					OnActivated = props.OnViewSeasonRewards,
					Native = {
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.new(if ready > 0 then 0.58 else 1, if ready > 0 then -8 else 0, 1, 0),
					},
				}),
				Claim = if ready > 0
					then c(Button, {
						Text = if props.PendingClaims and props.PendingClaims.Season
							then "WAIT..."
							else `CLAIM {ready}`,
						TextSize = T.Type.Minimum,
						Color = C.Pink,
						LipColor = C.PinkLip,
						Shadow = false,
						Enabled = props.OnClaimSeason ~= nil
							and not (props.PendingClaims and props.PendingClaims.Season),
						OnActivated = props.OnClaimSeason,
						Native = {
							Position = UDim2.new(0.58, 8, 0, 0),
							Size = UDim2.new(0.42, -8, 1, 0),
						},
					})
					else nil,
			}),
		}
	)
end

-- Today is pink with a white outlined number, claimed days are lime with an ink
-- check and days still to come stay pale: the same stamps as the Daily Rewards modal.
local function DayStamp(props)
	local day = props.Day
	local claimed = day.claimed and not day.available
	return c("Frame", {
		BackgroundColor3 = if day.available then C.Pink elseif claimed then C.Lime else C.Surface,
		BorderSizePixel = 0,
		LayoutOrder = props.Order,
		Size = UDim2.new(1 / 7, -DAY_GAP * 6 / 7, 1, 0),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, K.WellRadius) }),
		Stroke = c("UIStroke", {
			Color = if day.available or claimed then C.Ink else C.WellLine,
			Thickness = T.Shape.StrokeInner,
		}),
		Mark = if claimed
			then c(Icon, {
				Name = "Check",
				Color = C.Ink,
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.6, 0.6),
					ZIndex = 9,
				},
			}, { Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }) })
			else c(Text, {
				Text = tostring(day.day),
				Font = T.Type.Display,
				TextSize = T.Type.TileLabel,
				TextColor3 = if day.available then C.Surface else C.InkSoft,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = false,
				Size = UDim2.fromScale(1, 1),
			}, {
				Outline = if day.available then c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }) else nil,
			}),
	})
end

local function dailyContent(props)
	local state = props.DailyReward
	if not state then
		return message("LOADING DAILY REWARDS...")
	end
	local days = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, DAY_GAP),
		}),
	}
	local upcoming = nil
	for index, day in state.days or {} do
		days[`Day{index}`] = c(DayStamp, { Day = day, Order = index })
		if day.day == state.nextDay then
			upcoming = day.reward
		end
	end
	local item = if upcoming and upcoming.itemId then Cosmetics.Items[upcoming.itemId] else nil
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, S.DailyContentHeight) }, {
		Week = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 40),
		}, days),
		Next = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 48),
			Size = UDim2.new(1, -8, 0, 40),
		}, {
			Caption = c(Text, {
				Text = if state.canClaim then `TODAY • DAY {state.nextDay}` else `TOMORROW • DAY {state.nextDay}`,
				TextColor3 = C.InkSoft,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.fromScale(0.58, 1),
			}),
			Reward = if upcoming == nil
				then nil
				elseif upcoming.kind == "Bonks" then c(Bonks, {
					Amount = upcoming.amount or 0,
					TextColor = C.Ink,
					TextStroke = 0,
					MaxTextSize = T.Type.TileLabel,
					Alignment = Enum.HorizontalAlignment.Right,
					Native = {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0.42, 1),
						ZIndex = 8,
					},
				})
				else c(Text, {
					Text = if item then string.upper(item.DisplayName) else "GIFT",
					Font = T.Type.Display,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextTruncate = Enum.TextTruncate.AtEnd,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromScale(0.42, 1),
				}),
		}),
		View = c(Button, {
			Text = if state.canClaim then "OPEN DAILY REWARD" else "VIEW DAILY REWARDS",
			TextSize = T.Type.Minimum,
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
			TextSize = T.Type.Minimum,
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
		-- Room for the rows' outside strokes at the clip edge; the left edge lines up
		-- with the tab rail and the right keeps the scrollbar clear of the rows.
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, T.Shape.StrokeInner + 1),
			PaddingBottom = UDim.new(0, T.Shape.StrokeInner + 3),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 4),
		}),
	}
	if active == "DAILY" then
		content.Daily = dailyContent(props)
	elseif active == "SEASON" then
		content.Season = seasonContent(props)
	elseif props.QuestState == nil then
		content.Loading = message("LOADING QUESTS...")
	elseif #props.QuestState.quests == 0 then
		content.Empty = message("NO QUESTS RIGHT NOW")
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
			Position = UDim2.fromOffset(4, contentTop),
			Size = UDim2.new(1, -8, 1, -contentTop - 4),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = T.Layout.ScrollBar,
			ScrollBarImageColor3 = C.Pink,
		}, content),
	})
end
