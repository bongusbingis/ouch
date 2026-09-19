-- Read-only story data from the shipped catalog. Regional prices are simulated;
-- purchase calls remain disabled.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local Economy = ReplicatedStorage.Shared.Game.Economy
local Cosmetics = require(Config:WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Crates = require(Config:WaitForChild("Economy"):WaitForChild("Crates"))
local Shop = require(Config:WaitForChild("Economy"):WaitForChild("Shop"))
local Products = require(Config:WaitForChild("Economy"):WaitForChild("Products"))
local GamePasses = require(Config:WaitForChild("Economy"):WaitForChild("GamePasses"))
local ShopViewModel = require(Economy.ShopViewModel)
local FeaturedRotation = require(Economy.FeaturedRotation)
local DirectPurchase = require(Economy.DirectPurchase)
local Fixtures = {}

function Fixtures.build(state: string?)
	local now = os.time()
	local offers = {}
	for _, entry in
		{
			{ itemId = "DodgeBall1", role = "RobuxCommon" },
			{ itemId = "DodgeBall10", role = "RobuxPremium" },
			{ itemId = "DodgeBall19", role = "Bonks" },
		}
	do
		local itemId = entry.itemId
		local item = Cosmetics.Items[itemId]
		table.insert(offers, {
			itemId = itemId,
			role = entry.role,
			rarity = item.Rarity,
			displayName = item.DisplayName,
			bonksPrice = if entry.role == "Bonks"
				then DirectPurchase.priceFor(itemId, Cosmetics.Items, Cosmetics.Rarities)
				else nil,
			purchased = state == "Purchased" and entry.role == "RobuxCommon",
		})
	end
	local data = {
		Bonks = if state == "Unaffordable" then 0 else 5000,
		Cosmetics = { Owned = { [Crates.EffectsCrate.ItemPool[1]] = true }, Equipped = {} },
		Crates = { Pity = { EffectsCrate = if state == "Guaranteed" then { Rare = 4, Legendary = 24 } else {} } },
	}
	local snapshot = {
		status = if state == "Error" or state == "Loading" or state == "Refreshing" then state else "Ready",
		shopState = {
			serverNow = now,
			paidRandomAllowed = state ~= "Restricted",
			paidRandomReason = if state == "Restricted" then "paid_random_restricted" else nil,
			offers = if state == "Empty" then {} else offers,
			offersExpireAt = now + 86400,
			featured = { kind = "Crate", id = "EffectsCrate" },
			featuredExpireAt = now + 604800,
			bundleExpireAt = now + 604800,
		},
		metadata = {},
		ownedPasses = {},
		pending = if state == "Pending" then { ["Crate:EffectsCrate"] = true } else {},
	}
	for _, entry in
		{
			{ definition = Products.Catalog.OfferUnlockCommon, price = 99 },
			{ definition = Products.Catalog.OfferUnlockRare, price = 199 },
			{ definition = Products.Catalog.OfferUnlockLegendary, price = 599 },
		}
	do
		snapshot.metadata[`Product:{entry.definition.Id}`] = { priceInRobux = entry.price, isForSale = true }
	end
	if state == "Unavailable" then
		for _, catalog in { Products.Catalog, GamePasses.Catalog } do
			for _, definition in catalog do
				if definition.Id then
					for _, kind in { "Product", "GamePass" } do
						snapshot.metadata[`{kind}:{definition.Id}`] = { failed = true }
					end
				end
			end
		end
	end
	local options = table.clone(snapshot)
	options.economyData = data
	options.now = now
	options.cosmetics = Cosmetics
	options.crates = Crates
	options.bundles = require(Config:WaitForChild("Economy"):WaitForChild("Bundles"))
	options.gamePasses = GamePasses
	options.products = Products.Catalog
	options.seasons = require(Config:WaitForChild("Progression"):WaitForChild("Seasons")).Definitions
	options.shopConfig = Shop
	options.featuredRotation = FeaturedRotation
	options.crateOdds = require(Economy.CrateOdds)
	options.crateBatch = require(Economy.CrateBatch)
	return ShopViewModel.build(options), snapshot, data
end

function Fixtures.client(snapshot)
	local function unavailable()
		return false, "preview_only"
	end
	return {
		snapshot = function()
			return snapshot
		end,
		subscribe = function()
			return function() end
		end,
		refresh = function() end,
		clearGrant = function() end,
		clearReveal = function() end,
		openCrate = unavailable,
		purchaseCosmetic = unavailable,
		promptProduct = unavailable,
		promptGamePass = unavailable,
	}
end

return Fixtures
