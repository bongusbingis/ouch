-- Name: SplashPage.story.luau
-- Author: Jack C.
-- Description: Studio story previewing the lobby splash page.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SplashPage = require(script.Parent.Parent.Components.SplashPage)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(
		target,
		React.createElement(SplashPage, {
			PartyState = "PRESS PLAY TO MATCHMAKE",
			ShowMatchmakingActivity = false,
			PlayText = "PLAY",
			PlayEnabled = true,
			OnPlay = function() end,
			OnInvite = function() end,
			OnJoinCode = function() end,
			DailyReward = {
				canClaim = true,
				currentDay = 2,
				nextDay = 2,
				totalClaimed = 1,
				days = {
					{
						day = 1,
						reward = { kind = "Bonks", amount = 100 },
						claimed = true,
						available = false,
						current = false,
					},
					{
						day = 2,
						reward = { kind = "Bonks", amount = 125 },
						claimed = false,
						available = true,
						current = true,
					},
					{
						day = 3,
						reward = { kind = "Bonks", amount = 150 },
						claimed = false,
						available = false,
						current = false,
					},
					{
						day = 4,
						reward = { kind = "Bonks", amount = 200 },
						claimed = false,
						available = false,
						current = false,
					},
					{
						day = 5,
						reward = { kind = "Bonks", amount = 250 },
						claimed = false,
						available = false,
						current = false,
					},
					{
						day = 6,
						reward = { kind = "Bonks", amount = 300 },
						claimed = false,
						available = false,
						current = false,
					},
					{
						day = 7,
						reward = { kind = "Bonks", amount = 500 },
						claimed = false,
						available = false,
						current = false,
					},
				},
			},
			OnViewDailyReward = function() end,
			SeasonState = {
				active = true,
				displayName = "Season 1: First Splat",
				tier = 3,
				tierCount = 30,
				xpIntoTier = 260,
				xpForNextTier = 608,
				tiers = {
					{ unlocked = true, freeReward = { kind = "Bonks", amount = 100 } },
					{ unlocked = false, freeReward = { kind = "Bonks", amount = 250 } },
				},
			},
			QuestState = {
				dailyKey = "story",
				resetAt = 0,
				quests = {
					{
						id = "hammer",
						title = "Hit 5 players with the hammer",
						progress = 2,
						goal = 5,
						claimed = false,
						reward = { kind = "Bonks", amount = 150 },
					},
					{
						id = "throws",
						title = "Throw 10 dodgeballs",
						progress = 10,
						goal = 10,
						claimed = false,
						reward = { kind = "Bonks", amount = 125 },
					},
					{
						id = "elims",
						title = "Get 3 dodgeball eliminations",
						progress = 3,
						goal = 3,
						claimed = true,
						reward = { kind = "Bonks", amount = 175 },
					},
				},
			},
			OnClaimQuest = function() end,
		})
	)
end
