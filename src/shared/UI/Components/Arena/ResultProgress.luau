-- Personal match rewards remain a read-only projection, including delayed persistence.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Colors = require(ReplicatedStorage.Config.Interface.ArenaPresentation).Colors
local Label = require(script.Parent.Label)
local Surface = require(script.Parent.Surface)
local Avatar = require(script.Parent.CelebrationAvatar)
local BonksLabel = require(script.Parent.Parent.BonksLabel)
local formatNumber = require(script.Parent.Parent.Parent.Models.NumberText)
local c = React.createElement

return function(props)
	local result = props.Result
	local compact = props.Compact
	local appearance = result.personalAppearance
	local avatarHeight = if compact then 90 else 160
	local rewardsTop = if appearance and not compact then avatarHeight + 36 else 38
	local rewards = result.rewards
	local stats = {}
	for _, stat in result.personalStats do
		if stat.id ~= "Placement" then
			table.insert(stats, stat)
		end
	end
	local rows = {
		Header = c(Label, {
			Text = "YOUR ROUND",
			Title = true,
			Size = 27,
			Native = { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 30) },
		}),
		Avatar = if appearance and not compact
			then c(Avatar, {
				ColorId = appearance.colorId,
				EmoteId = appearance.emoteId,
				Native = { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, avatarHeight) },
			})
			else nil,
		XP = if rewards
			then c(Label, {
				Text = `+{formatNumber(rewards.matchXp)} XP`,
				Title = true,
				Color = Colors.Cyan,
				Size = 28,
				Native = { Position = UDim2.fromOffset(8, rewardsTop), Size = UDim2.new(0.5, -8, 0, 38) },
			})
			else nil,
		Bonks = if rewards
			then c(BonksLabel, {
				Amount = rewards.bonks,
				MaxTextSize = 28,
				Native = {
					Position = UDim2.new(0.5, 0, 0, rewardsTop),
					Size = UDim2.new(0.5, -8, 0, 38),
					ZIndex = 4,
				},
			})
			else nil,
		Pending = if result.rewardsPending or not rewards
			then c(Label, {
				Text = if result.rewardsPending then "Saving your rewards…" else "Rewards are on their way…",
				Size = 19,
				Color = Colors.Muted,
				Native = { Position = UDim2.fromOffset(8, rewardsTop), Size = UDim2.new(1, -16, 0, 38) },
			})
			else nil,
	}
	local y = rewardsTop + 46
	for _, stat in stats do
		rows[stat.id] = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14, y),
			Size = UDim2.new(1, -28, 0, if compact then 23 else 30),
		}, {
			Name = c(Label, {
				Text = stat.label,
				Size = 17,
				Color = Colors.Muted,
				Align = Enum.TextXAlignment.Left,
				Native = { Size = UDim2.fromScale(0.72, 1) },
			}),
			Value = c(Label, {
				Text = formatNumber(stat.value),
				Title = true,
				Size = 25,
				Color = if stat.highlight then Colors.Yellow else Colors.White,
				Align = Enum.TextXAlignment.Right,
				Native = { Position = UDim2.fromScale(0.73, 0), Size = UDim2.fromScale(0.27, 1) },
			}),
		})
		y += if compact then 24 else 31
	end
	local season = result.seasonProgress
	if season then
		y += 8
		rows.Season = c(Label, {
			Text = if season.afterTier > season.beforeTier
				then `TIER {season.afterTier} UNLOCKED!`
				else `SEASON TIER {season.afterTier}`,
			Title = true,
			Size = 23,
			Color = Colors.Yellow,
			Native = { Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, 30) },
		})
		y += 36
		rows.Progress = c("Frame", {
			BackgroundColor3 = Colors.Ink,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(16, y),
			Size = UDim2.new(1, -32, 0, 10),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = c("Frame", {
				BackgroundColor3 = Colors.Pink,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(math.clamp(season.xpIntoTier / season.xpForNextTier, 0, 1), 1),
			}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		})
		y += 15
		rows.ProgressText = c(Label, {
			Text = `{formatNumber(season.xpIntoTier)} / {formatNumber(season.xpForNextTier)} XP`,
			Size = 15,
			Color = Colors.Muted,
			Native = { Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, 22) },
		})
		y += 28
	end
	for _, challenge in result.challenges or {} do
		rows["Challenge" .. challenge.id] = c(Label, {
			Text = `{challenge.label}  {challenge.current}/{challenge.target}`,
			Size = 17,
			Native = { Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, 30) },
		})
		y += 32
	end
	for _, unlock in result.unlocks or {} do
		rows["Unlock" .. unlock.id] = c(Label, {
			Text = `UNLOCKED: {unlock.name}`,
			Size = 19,
			Color = Colors.Yellow,
			Native = { Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, 32) },
		})
		y += 34
	end
	if appearance and compact then
		rows.Emote = c(Avatar, {
			ColorId = appearance.colorId,
			EmoteId = appearance.emoteId,
			Native = { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, avatarHeight) },
		})
		y += avatarHeight
	end
	rows.EmoteHint = c(Label, {
		Text = "VICTORY EMOTES IN SHOP\nCHOOSE YOURS IN BACKPACK",
		Size = 14,
		Color = Colors.Muted,
		Native = { Position = UDim2.fromOffset(12, y + 8), Size = UDim2.new(1, -24, 0, 42) },
	})
	y += 54
	return c(Surface, { Color = Colors.Surface, Native = { Size = UDim2.fromScale(1, 1) } }, {
		Content = c("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.fromOffset(0, y + 12),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Colors.Cyan,
			ZIndex = 3,
		}, rows),
	})
end
