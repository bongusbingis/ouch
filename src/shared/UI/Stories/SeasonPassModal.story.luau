-- Description: Edit-mode preview of the season pass modal with a local active-season projection.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SeasonPassModal = require(script.Parent.Parent.Components.SeasonPassModal)
local mount = require(script.Parent.StoryRoot)

local seasonState = {
	seasonId = "S1",
	active = true,
	displayName = "SEASON 1: FIRST SPLAT",
	tier = 2,
	tierCount = 25,
	xpIntoTier = 260,
	xpForNextTier = 608,
	hasPremium = false,
	tiers = {
		{
			tier = 1,
			unlocked = true,
			freeReward = { kind = "Bonks", amount = 100 },
			freeClaimed = true,
			premiumReward = { kind = "Bonks", amount = 300 },
			premiumClaimed = false,
		},
		{
			tier = 2,
			unlocked = true,
			freeReward = { kind = "Bonks", amount = 250 },
			freeClaimed = false,
			premiumReward = { kind = "Bonks", amount = 500 },
			premiumClaimed = false,
		},
		{
			tier = 3,
			unlocked = false,
			freeReward = { kind = "Bonks", amount = 350 },
			freeClaimed = false,
			premiumReward = { kind = "Bonks", amount = 600 },
			premiumClaimed = false,
		},
	},
}

return function(target: Instance)
	return mount(
		target,
		React.createElement(SeasonPassModal, {
			FocusEnabled = false,
			Card = {
				id = "Season:S1",
				definition = { SeasonId = "S1" },
				status = "Active",
				robuxPrice = 399,
				productId = 1,
				pending = false,
			},
			SeasonState = seasonState,
			Equipped = { CharacterColor = "CharacterColorBlue", CostumeAssets = "" },
			OnClose = function() end,
			OnClaimSeason = function() end,
			OnPurchaseRobux = function() end,
		})
	)
end
