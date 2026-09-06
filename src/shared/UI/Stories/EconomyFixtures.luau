-- Read-only story data from the shipped catalog. No Robux prices or purchase calls are simulated here.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local Economy = ReplicatedStorage.Shared.Game.Economy
local Cosmetics = require(Config.Cosmetics.Cosmetics)
local Crates = require(Config.Economy.Crates)
local Shop = require(Config.Economy.Shop)
local Products = require(Config.Economy.Products)
local GamePasses = require(Config.Economy.GamePasses)
local ShopViewModel = require(Economy.ShopViewModel)
local FeaturedRotation = require(Economy.FeaturedRotation)
local DirectPurchase = require(Economy.DirectPurchase)
local Fixtures = {}

function Fixtures.build(state: string?)
	local now = os.time()
	local offers = {}
	for _, crateId in { "DodgeballCrate", "HammerCrate", "EffectsCrate" } do
		local itemId = Crates[crateId].ItemPool[1]
		local item = Cosmetics.Items[itemId]
		table.insert(offers, {
			itemId = itemId,
			rarity = item.Rarity,
			displayName = item.DisplayName,
			bonksPrice = DirectPurchase.priceFor(itemId, Cosmetics.Items, Cosmetics.Rarities),
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
	options.bundles = require(Config.Economy.Bundles)
	options.gamePasses = GamePasses
	options.products = Products.Catalog
	options.seasons = require(Config.Progression.Seasons).Definitions
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
