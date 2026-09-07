-- Name: ShopViewModel.spec.luau
-- Author: Jack C.
-- Description: Spec for the storefront view model: stable section order, empty sections omitted, aspirational crate previews, live ownership over snapshot ownership, and the same featured discount the server charges.
-- Created: 2026-08-23

--!strict

local T = require(script.Parent.TestKit)
local Config = script.Parent.Parent.Parent.Config
local Bundles = require(Config.Economy.Bundles)
local Cosmetics = require(Config.Cosmetics.Cosmetics)
local Crates = require(Config.Economy.Crates)
local GamePasses = require(Config.Economy.GamePasses)
local Products = require(Config.Economy.Products)
local Seasons = require(Config.Progression.Seasons)
local Shop = require(Config.Economy.Shop)
local Economy = script.Parent.Parent.Game.Economy
local CrateBatch = require(Economy.CrateBatch)
local CrateOdds = require(Economy.CrateOdds)
local FeaturedRotation = require(Economy.FeaturedRotation)
local ShopViewModel = require(Economy.ShopViewModel)

local function build(overrides)
	local now = 1_800_000_000
	local options = {
		status = "Ready",
		shopState = {
			serverNow = now,
			paidRandomAllowed = true,
			offers = {
				{ itemId = "DodgeBall1", rarity = "Common", displayName = "Red Ball", bonksPrice = 1200 },
			},
			offersExpireAt = now + 100,
			featured = { kind = "Crate", id = "DodgeballCrate" },
			featuredExpireAt = now + 200,
			bundle = { bundleId = "StarterOutfitBundle" },
			bundleExpireAt = now + 300,
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
		seasons = Seasons.Definitions,
		shopConfig = Shop,
		featuredRotation = FeaturedRotation,
		crateOdds = CrateOdds,
		crateBatch = CrateBatch,
	}
	for key, value in overrides or {} do
		options[key] = value
	end
	return ShopViewModel.build(options)
end

T.describe("ShopViewModel", function()
	T.it("derives outfit ownership from pieces and keeps every bundle item inspectable", function()
		local owned = { DodgeBall1 = true }
		for _, itemId in Cosmetics.Items.FoamLeague.Contents do
			owned[itemId] = true
		end
		local model = build({
			shopState = {
				offers = { { itemId = "FoamLeague", bonksPrice = 1000 } },
				bundle = { bundleId = "TestBundle" },
			},
			economyData = { Bonks = 2400, Cosmetics = { Owned = owned, Equipped = {} } },
			bundles = {
				Catalog = {
					TestBundle = {
						CatalogStatus = "Preview",
						DisplayName = "Test",
						Description = "Test",
						ItemIds = { "FoamLeague", "DodgeBall1", "StarPop", "Hammer1" },
					},
				},
			},
		})
		T.expect(model.byId["Cosmetic:FoamLeague"].owned):toEqual(true)
		T.expect(model.byId["Cosmetic:FoamLeague"].bonksAvailable):toEqual(2400)
		local bundle = model.byId["Bundle:TestBundle"]
		T.expect(#bundle.previewItems):toEqual(4)
		T.expect(bundle.previewItems[1].owned):toEqual(true)
		T.expect(bundle.previewItems[3].owned):toEqual(false)
		T.expect(bundle.owned):toEqual(false)
	end)

	T.it("keeps default inventory entries inspectable without inventing an owned item id", function()
		local card = ShopViewModel.inventory({
			id = "Default_CostumeAssets",
			category = "CostumeAssets",
			displayName = "No Costume",
			rarity = "Common",
			definition = Cosmetics.Defaults.CostumeAssets,
		})
		T.expect(card.status):toEqual("Owned")
		T.expect(card.previewItems[1].itemId):toBeNil()
		T.expect(card.previewItems[1].category):toEqual("CostumeAssets")
	end)

	T.it("keeps a granted reward inspectable while authoritative ownership is still arriving", function()
		local awaiting = ShopViewModel.reward("DodgeBall1", Cosmetics, {})
		T.expect(awaiting.owned):toEqual(false)
		T.expect(awaiting.pending):toEqual(true)
		T.expect(awaiting.status):toEqual("Loading")
		T.expect(awaiting.previewItems[1].itemId):toEqual("DodgeBall1")
		T.expect(awaiting.previewItems[1].owned):toEqual(false)
		T.expect(awaiting.productId):toBeNil()
		local delivered = ShopViewModel.reward("DodgeBall1", Cosmetics, { DodgeBall1 = true })
		T.expect(delivered.owned):toEqual(true)
		T.expect(delivered.pending):toEqual(false)
		T.expect(delivered.status):toEqual("Owned")
		T.expect(delivered.id):toEqual(awaiting.id)
	end)

	T.it("requires every outfit piece before a reward inspection offers equip", function()
		local owned = {}
		local pieces = Cosmetics.Items.FoamLeague.Contents
		for index = 1, #pieces - 1 do
			owned[pieces[index]] = true
		end
		T.expect(ShopViewModel.reward("FoamLeague", Cosmetics, owned).owned):toEqual(false)
		owned[pieces[#pieces]] = true
		T.expect(ShopViewModel.reward("FoamLeague", Cosmetics, owned).owned):toEqual(true)
		T.expect(ShopViewModel.reward("UnknownReward", Cosmetics, owned)):toBeNil()
	end)

	T.it("builds the storefront in stable section order", function()
		local model = build(nil)
		T.expect(#model.hero):toEqual(1)
		T.expect(model.hero[1].id):toEqual("FeaturedCrate:DodgeballCrate")
		T.expect(model.sections[1].title):toEqual("FOR YOU")
		T.expect(model.sections[2].title):toEqual("CRATES")
		T.expect(model.sections[3].title):toEqual("BONKS")
		T.expect(model.sections[4].title):toEqual("PASSES & MORE")
	end)

	T.it("omits an empty rotating section", function()
		local model = build({
			shopState = {
				serverNow = 1_800_000_000,
				paidRandomAllowed = true,
				offers = {},
				offersExpireAt = 1_800_000_100,
				featured = { kind = "Crate", id = "DodgeballCrate" },
				featuredExpireAt = 1_800_000_200,
				bundle = { bundleId = "StarterOutfitBundle" },
				bundleExpireAt = 1_800_000_300,
			},
		})
		T.expect(model.sections[1].title):toEqual("CRATES")
	end)

	T.it("uses an aspirational crate reward instead of the first alphabetic item", function()
		local model = build(nil)
		local card = model.byId["FeaturedCrate:DodgeballCrate"]
		T.expect(card.previewItems[1].itemId):toEqual("DodgeBall19")
	end)

	T.it("uses Replica ownership instead of the offer snapshot", function()
		local model = build({
			economyData = { Bonks = 2500, Cosmetics = { Owned = { DodgeBall1 = true }, Equipped = {} } },
		})
		local card = model.byId["Cosmetic:DodgeBall1"]
		T.expect(card.owned):toEqual(true)
		T.expect(card.status):toEqual("Owned")
	end)

	T.it("omits redundant card hints while retaining useful crate pricing", function()
		local model = build(nil)
		T.expect(model.byId["Cosmetic:DodgeBall1"].hintText):toBeNil()
		T.expect(model.byId["FeaturedCrate:DodgeballCrate"].hintText):toEqual("425 BONKS  |  WAS 500")
	end)

	T.it("shows the same featured discount charged by the server", function()
		local model = build(nil)
		local card = model.byId["FeaturedCrate:DodgeballCrate"]
		T.expect(card.originalBonksPrice):toEqual(500)
		T.expect(card.bonksPrice):toEqual(425)
		T.expect(model.byId["Crate:DodgeballCrate"].bonksPrice):toEqual(card.bonksPrice)
	end)

	T.it("hides unconfigured launch offers and keeps active products pending metadata", function()
		local model = build(nil)
		T.expect(model.byId["Bundle:StarterOutfitBundle"]):toBeNil()
		T.expect(model.byId["Crate:HammerCrate"].status):toEqual("Active")
		T.expect(model.byId["Product:Bonks500"].status):toEqual("Loading")
	end)

	T.it("uses each supplied regional price without a catalog fallback", function()
		for _, price in { 7, 83, 421 } do
			local metadata = {}
			for kind, definition in { Product = Products.Catalog.Bonks500, GamePass = GamePasses.Catalog.DoubleXP } do
				metadata[kind .. ":" .. definition.Id] = { priceInRobux = price, isForSale = true }
			end
			local model = build({ metadata = metadata })
			T.expect(model.byId["Product:Bonks500"].robuxPrice):toEqual(price)
			T.expect(model.byId["GamePass:DoubleXP"].robuxPrice):toEqual(price)
		end
		for _, info in { { loading = true }, { failed = true }, { isForSale = false, priceInRobux = 83 }, {} } do
			local model = build({ metadata = { ["Product:" .. Products.Catalog.Bonks500.Id] = info } })
			local card = model.byId["Product:Bonks500"]
			T.expect(card.robuxPrice):toBeNil()
			T.expect(card.productId):toBeNil()
			T.expect(card.status):toEqual(if info.loading then "Loading" else "Unavailable")
		end
	end)

	T.it("uses replicated pity and ownership to disclose actual next-open outcomes", function()
		local model = build({
			economyData = {
				Bonks = 1000,
				Cosmetics = { Owned = { BubbleBurst = true }, Equipped = {} },
				Crates = { Pity = { EffectsCrate = { Legendary = 24 } } },
			},
		})
		local card = model.byId["Crate:EffectsCrate"]
		local total = 0
		for _, outcome in card.odds do
			total += outcome.percent
			if outcome.rarity ~= "Legendary" then
				T.expect(outcome.percent):toEqual(0)
			end
			if outcome.itemId == "BubbleBurst" then
				T.expect(outcome.owned):toEqual(true)
				T.expect(outcome.bonksRefund):toEqual(400)
				T.expect(outcome.preview.itemId):toEqual("BubbleBurst")
			end
		end
		T.expect(total):toBeNear(100, 0.0001)
		T.expect(card.pityRemaining.Legendary):toEqual(1)
	end)

	T.it("blocks both crate purchase paths until policy explicitly allows them", function()
		for _, allowed in { false, "unknown" } do
			local model = build({ shopState = { offers = {}, paidRandomAllowed = allowed } })
			local card = model.byId["Crate:EffectsCrate"]
			T.expect(card.status):toEqual("Unavailable")
			T.expect(card.productId):toBeNil()
			T.expect(card.robuxPrice):toBeNil()
		end
	end)

	T.it("uses configured product and game pass icons instead of marketplace icons", function()
		local products = table.clone(Products.Catalog)
		products.Bonks500 = table.clone(products.Bonks500)
		products.Bonks500.Icon = "rbxassetid://101"
		local pass = table.clone(GamePasses.Catalog.DoubleXP)
		pass.Icon = "rbxassetid://202"
		local model = build({
			products = products,
			gamePasses = { Catalog = { DoubleXP = pass } },
			metadata = {
				[`Product:{products.Bonks500.Id}`] = {
					name = "Marketplace Product",
					priceInRobux = 49,
					iconImageAssetId = 303,
					isForSale = true,
				},
				[`GamePass:{pass.Id}`] = {
					name = "Marketplace Pass",
					priceInRobux = 199,
					iconImageAssetId = 404,
					isForSale = true,
				},
			},
		})
		T.expect(model.byId["Product:Bonks500"].thumbnail):toEqual("rbxassetid://101")
		T.expect(model.byId["GamePass:DoubleXP"].thumbnail):toEqual("rbxassetid://202")
	end)

	T.it("leaves product and game pass artwork absent when Icon is missing", function()
		local products = table.clone(Products.Catalog)
		products.Bonks500 = table.clone(products.Bonks500)
		products.Bonks500.Icon = nil
		local pass = table.clone(GamePasses.Catalog.DoubleXP)
		pass.Icon = nil
		local model = build({
			products = products,
			gamePasses = { Catalog = { DoubleXP = pass } },
			metadata = {
				[`Product:{products.Bonks500.Id}`] = {
					priceInRobux = 49,
					iconImageAssetId = 303,
					isForSale = true,
				},
				[`GamePass:{pass.Id}`] = {
					priceInRobux = 199,
					iconImageAssetId = 404,
					isForSale = true,
				},
			},
		})
		T.expect(model.byId["Product:Bonks500"].thumbnail):toBeNil()
		T.expect(model.byId["GamePass:DoubleXP"].thumbnail):toBeNil()
	end)
end)

T.describe("Season storefront expiry", function()
	T.it("removes the seasonal purchase at its exact deadline", function()
		local seasons = { Test = { Id = "Test", StartsAt = 100, EndsAt = 200 } }
		local products = {
			TestPass = {
				Type = "SeasonPass",
				SeasonId = "Test",
				CatalogStatus = "Preview",
				DisplayName = "Test",
				Description = "",
				DisplayOrder = 1,
			},
		}
		T.expect(build({ now = 199, seasons = seasons, products = products }).byId["Product:TestPass"] ~= nil)
			:toEqual(true)
		T.expect(build({ now = 200, seasons = seasons, products = products }).byId["Product:TestPass"]):toBeNil()
	end)
end)

return true
