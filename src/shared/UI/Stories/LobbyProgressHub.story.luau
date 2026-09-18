-- Description: Edit-mode preview of Season, Quests, and Daily progression with local claim data.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local LobbyProgressHub = require(script.Parent.Parent.Components.LobbyProgressHub)
local mount = require(script.Parent.StoryRoot)

local daily = { canClaim = true, currentDay = 3, nextDay = 3, totalClaimed = 2, days = {} }
for day = 1, 7 do
	table.insert(daily.days, {
		day = day,
		reward = { kind = "Bonks", amount = 75 + day * 25 },
		claimed = day < 3,
		available = day == 3,
		current = day == 3,
	})
end

local function Story(props)
	local selected, setSelected = React.useState("SEASON")
	return React.createElement(LobbyProgressHub, {
		Native = { Size = UDim2.fromScale(1, 1) },
		SelectedTab = selected,
		Compact = props.Compact,
		SeasonState = {
			active = true,
			displayName = "SEASON 1: FIRST SPLAT",
			tier = 3,
			tierCount = 30,
			xpIntoTier = 260,
			xpForNextTier = 608,
			tiers = { { unlocked = true, freeClaimed = false } },
		},
		QuestState = {
			quests = {
				{
					questId = "hammer",
					title = "Hit 5 players with the hammer",
					progress = 2,
					goal = 5,
					claimed = false,
					reward = { kind = "Bonks", amount = 150 },
				},
				{
					questId = "throws",
					title = "Throw 10 dodgeballs",
					progress = 10,
					goal = 10,
					claimed = false,
					reward = { kind = "Bonks", amount = 125 },
				},
			},
		},
		DailyReward = daily,
		OnSelectTab = setSelected,
		OnClaimQuest = function() end,
		OnClaimSeason = function() end,
		OnViewDailyReward = function() end,
		OnViewSeasonRewards = function() end,
	})
end

return function(target: Instance)
	return mount(target, React.createElement(Story, { Compact = target:GetAttribute("Compact") == true }))
end
