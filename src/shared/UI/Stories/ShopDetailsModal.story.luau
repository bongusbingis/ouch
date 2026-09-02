--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ShopDetailsModal = require(script.Parent.Parent.Components.ShopDetailsModal)
local mount = require(script.Parent.StoryRoot)

local CARD = {
	id = "story-crate",
	kind = "Crate",
	displayName = "Splat Crate",
	description = "Contains one cosmetic reward with duplicate protection refunds.",
	thumbnail = "",
	previewItems = {},
	bonksPrice = 500,
	bonksAvailable = 2500,
	affordable = true,
	pending = false,
	openQuantities = { 1, 5, 10 },
	odds = {
		{ itemId = "common", displayName = "Common Reward", rarity = "Common", percent = 70 },
		{ itemId = "rare", displayName = "Rare Reward", rarity = "Rare", percent = 25 },
		{ itemId = "legendary", displayName = "Legendary Reward", rarity = "Legendary", percent = 5 },
	},
	pity = { Legendary = 20 },
}

return function(target: Instance)
	return mount(
		target,
		React.createElement(ShopDetailsModal, {
			Card = CARD,
			OnClose = function() end,
			OnPurchaseBonks = function() end,
			OnPurchaseRobux = function() end,
		})
	)
end
