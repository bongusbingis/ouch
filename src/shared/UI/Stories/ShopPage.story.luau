-- Name: ShopPage.story.luau
-- Author: Jack C.
-- Description: Studio story previewing the storefront page built from the shipped shop configuration.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config = ReplicatedStorage:WaitForChild("Config")
local Bundles = require(Config:WaitForChild("Economy"):WaitForChild("Bundles"))
local Cosmetics = require(Config:WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Crates = require(Config:WaitForChild("Economy"):WaitForChild("Crates"))
local GamePasses = require(Config:WaitForChild("Economy"):WaitForChild("GamePasses"))
local Products = require(Config:WaitForChild("Economy"):WaitForChild("Products"))
local Shop = require(Config:WaitForChild("Economy"):WaitForChild("Shop"))
local Economy = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy")
local CrateBatch = require(Economy:WaitForChild("CrateBatch"))
local CrateOdds = require(Economy:WaitForChild("CrateOdds"))
local FeaturedRotation = require(Economy:WaitForChild("FeaturedRotation"))
local ShopViewModel = require(Economy:WaitForChild("ShopViewModel"))
local ShopPage = require(script.Parent.Parent.Components.ShopPage)
local mount = require(script.Parent.StoryRoot)

local now = os.time()
local model = ShopViewModel.build({
	status = "Ready",
	shopState = {
		serverNow = now,
		offers = {
			{ itemId = "BallRed", rarity = "Common", displayName = "Red Ball", bonksPrice = 1200 },
			{ itemId = "BallOrange", rarity = "Rare", displayName = "Orange Ball", bonksPrice = 3500 },
			{ itemId = "BallPurple", rarity = "Legendary", displayName = "Purple Ball", bonksPrice = 12000 },
		},
		offersExpireAt = now + 86400,
		featured = { kind = "Crate", id = "DodgeballCrate" },
		featuredExpireAt = now + 604800,
		bundle = { bundleId = "StarterOutfitBundle" },
		bundleExpireAt = now + 604800,
	},
	economyData = { Bonks = 2500, Cosmetics = { Owned = {}, Equipped = {} } },
	metadata = {},
	ownedPasses = {},
	pending = {},
	now = now,
	cosmetics = Cosmetics,
	crates = Crates,
	bundles = Bundles,
	gamePasses = GamePasses,
	products = Products.Catalog,
	shopConfig = Shop,
	featuredRotation = FeaturedRotation,
	crateOdds = CrateOdds,
	crateBatch = CrateBatch,
})

return function(target: Instance)
	return mount(
		target,
		React.createElement(ShopPage, {
			Model = model,
			OnCardActivated = function() end,
			OnRefresh = function() end,
		})
	)
end
