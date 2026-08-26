-- Name: ShopViewModel.spec.luau
-- Author: Jack C.
-- Description: Spec for the storefront view model: stable section order, empty sections omitted, aspirational crate previews, live ownership over snapshot ownership, and the same featured discount the server charges.
-- Created: 2026-08-23

--!strict

local T = require(script.Parent.TestKit)
local Config = script.Parent.Parent.Parent.Config
local Bundles = require(Config.Bundles)
local Cosmetics = require(Config.Cosmetics)
local Crates = require(Config.Crates)
local GamePasses = require(Config.GamePasses)
local Products = require(Config.Products)
local Shop = require(Config.Shop)
local Economy = script.Parent.Parent.Game.Economy
local CrateOdds = require(Economy.CrateOdds)
local FeaturedRotation = require(Economy.FeaturedRotation)
local ShopViewModel = require(Economy.ShopViewModel)

local function build(overrides)
	local now = 1_800_000_000
	local options = {
		status = "Ready",
		shopState = {
			serverNow = now,
			offers = {
				{ itemId = "BallRed", rarity = "Common", displayName = "Red Ball", bonksPrice = 1200 },
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
		shopConfig = Shop,
		featuredRotation = FeaturedRotation,
		crateOdds = CrateOdds,
	}
	for key, value in overrides or {} do
		options[key] = value
	end
	return ShopViewModel.build(options)
end

T.describe("ShopViewModel", function()
	T.it("builds the storefront in stable section order", function()
		local model = build(nil)
		T.expect(#model.hero):toEqual(2)
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
		T.expect(card.previewItems[1].itemId):toEqual("BallPurple")
	end)

	T.it("uses Replica ownership instead of the offer snapshot", function()
		local model = build({
			economyData = { Bonks = 2500, Cosmetics = { Owned = { BallRed = true }, Equipped = {} } },
		})
		local card = model.byId["Cosmetic:BallRed"]
		T.expect(card.owned):toEqual(true)
		T.expect(card.status):toEqual("Owned")
	end)

	T.it("omits redundant card hints while retaining useful crate pricing", function()
		local model = build(nil)
		T.expect(model.byId["Cosmetic:BallRed"].hintText):toBeNil()
		T.expect(model.byId["FeaturedCrate:DodgeballCrate"].hintText):toEqual("425 BONKS  |  WAS 500")
	end)

	T.it("shows the same featured discount charged by the server", function()
		local model = build(nil)
		local card = model.byId["FeaturedCrate:DodgeballCrate"]
		T.expect(card.originalBonksPrice):toEqual(500)
		T.expect(card.bonksPrice):toEqual(425)
	end)

	T.it("keeps previews disabled and active products pending metadata", function()
		local model = build(nil)
		T.expect(model.byId["Bundle:StarterOutfitBundle"].status):toEqual("Preview")
		T.expect(model.byId["Crate:HammerCrate"].status):toEqual("Preview")
		T.expect(model.byId["Product:Bonks500"].status):toEqual("Loading")
	end)
end)

return true
