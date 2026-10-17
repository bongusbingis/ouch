-- Name: ShopCardStyle.spec.luau
-- Author: Jack C.
-- Description: Headless checks that storefront cards resolve their sticker, ribbon, ownership stamp, tints, names and action labels from the existing view-model fields without inventing rarity or dropping an explicit badge.
-- Created: 2026-09-15
--!strict

local T = require(script.Parent.TestKit)
local Style = require(script.Parent.Parent.UI.Models.ShopCardStyle)
local Tokens = require(script.Parent.Parent.UI.Tokens)
local C = Tokens.Colors

local function card(fields)
	local base = { id = "x", kind = "Cosmetic", displayName = "Jelly Splash", previewItems = {}, owned = false }
	for key, value in fields do
		base[key] = value
	end
	return base
end

T.describe("ShopCardStyle", function()
	T.it("keeps rarity as a ribbon and never turns it into a sticker", function()
		local style = Style.resolve(card({ badge = "Rare", bonksPrice = 1000 }))
		T.expect(style.rarity):toEqual("Rare")
		T.expect(style.sticker):toBeNil()
		T.expect(style.accent == Tokens.Rarity.Rare.Color):toBeTruthy()
		T.expect(style.action.BonksAmount):toEqual(1000)
		T.expect(style.action.Text):toBeNil()
	end)
	T.it("shows every explicit badge as a sticker with its own palette", function()
		local featured = Style.resolve(card({ kind = "Crate", badge = "FEATURED", displayName = "Dodgeballs" }))
		T.expect(featured.sticker and featured.sticker.Text):toEqual("FEATURED")
		T.expect(featured.sticker and featured.sticker.Color == C.Pink):toBeTruthy()
		T.expect(featured.sticker and featured.sticker.TextColor == C.Surface):toBeTruthy()
		local pass = Style.resolve(card({ kind = "GamePass", badge = "PERMANENT", displayName = "Showtime" }))
		T.expect(pass.sticker and pass.sticker.Text):toEqual("PERMANENT")
		T.expect(pass.sticker and pass.sticker.Color == C.Grape):toBeTruthy()
		local starter = Style.resolve(card({ kind = "GamePass", badge = "STARTER OFFER" }))
		T.expect(starter.sticker and starter.sticker.Text):toEqual("STARTER OFFER")
		local other = Style.resolve(card({ kind = "Bundle", badge = "Limited" }))
		T.expect(other.sticker and other.sticker.Text):toEqual("LIMITED")
	end)
	T.it("drops a sticker that repeats its block's header", function()
		local featured = Style.resolve(
			card({ kind = "Crate", badge = "FEATURED", displayName = "Dodgeballs" }),
			nil,
			{ Headline = true, SectionTitle = "FEATURED" }
		)
		T.expect(featured.sticker):toBeNil()
		local pass = Style.resolve(card({ kind = "GamePass", badge = "PERMANENT" }), nil, { SectionTitle = "PASSES" })
		T.expect(pass.sticker and pass.sticker.Text):toEqual("PERMANENT")
	end)
	T.it("drops the kind-derived label that only repeated the section title", function()
		local crate = Style.resolve(card({ kind = "Crate", displayName = "Hammers", bonksPrice = 425 }))
		T.expect(crate.sticker):toBeNil()
		T.expect(crate.rarity):toBeNil()
		T.expect(crate.action.Text):toEqual("VIEW ODDS")
		T.expect(crate.secondary):toEqual("425 BONKS / OPEN")
		local bonks = Style.resolve(
			card({
				kind = "Bonks",
				displayName = "Pouch",
				definition = { BonksAmount = 2500 },
				robuxPrice = 199,
			}),
			nil,
			{ RobuxSymbol = "R$" }
		)
		T.expect(bonks.sticker):toBeNil()
		T.expect(bonks.currency):toBeTruthy()
		T.expect(bonks.name):toEqual("2,500 BONKS")
		T.expect(bonks.action.Text):toEqual("R$199")
	end)
	T.it("labels the season once and never stamps it OWNED", function()
		local state = {
			active = true,
			displayName = "Season 1: First Splat",
			tier = 4,
			tierCount = 30,
			xpIntoTier = 50,
			xpForNextTier = 200,
		}
		local style = Style.resolve(
			card({ kind = "SeasonPass", owned = true, displayName = "Premium Pass" }),
			state,
			{ Headline = true }
		)
		T.expect(style.season):toBeTruthy()
		T.expect(style.owned):toBeFalsy()
		T.expect(style.sticker and style.sticker.Text):toEqual("SEASON PASS")
		T.expect(style.sticker and style.sticker.Color == C.Gold):toBeTruthy()
		T.expect(style.name):toEqual("SEASON 1: FIRST SPLAT")
		T.expect(style.secondary):toEqual("TIER 4 · PREMIUM OWNED")
		T.expect(style.progress):toEqual(0.25)
		T.expect(style.action.Text):toEqual("VIEW REWARDS")
		T.expect(style.primary):toBeTruthy()
		local compact =
			Style.resolve(card({ kind = "SeasonPass", displayName = "Premium Pass" }), state, { ShowProgress = false })
		T.expect(compact.progress):toBeNil()
		T.expect(compact.secondary):toEqual("FREE + PREMIUM REWARDS")
	end)
	T.it("stamps owned catalog items while keeping their ribbon and inspect action", function()
		local style = Style.resolve(card({ badge = "Legendary", owned = true, bonksPrice = 5000 }))
		T.expect(style.owned):toBeTruthy()
		T.expect(style.rarity):toEqual("Legendary")
		T.expect(style.action.Text):toEqual("VIEW ITEM")
		T.expect(style.action.BonksAmount):toBeNil()
	end)
	T.it("marks a purchased rotation slot without offering it again", function()
		local style = Style.resolve(card({ badge = "Rare", purchased = true, robuxPrice = 199 }))
		T.expect(style.owned):toBeTruthy()
		T.expect(style.ownedText):toEqual("PURCHASED")
		T.expect(style.action.Text):toEqual("PURCHASED")
		T.expect(style.action.RobuxAmount):toBeNil()
	end)
	T.it("preserves the pending and availability labels", function()
		T.expect(Style.resolve(card({ pending = true, bonksPrice = 10 })).action.Text):toEqual("PROCESSING…")
		T.expect(Style.resolve(card({ status = "Preview" })).action.Text):toEqual("COMING SOON")
		T.expect(Style.resolve(card({ status = "Loading" })).action.Text):toEqual("LOADING PRICE…")
		T.expect(Style.resolve(card({ status = "Loading" })).actionState):toEqual("Muted")
		T.expect(Style.resolve(card({ status = "Retry" })).action.Text):toEqual("RETRY PRICE")
		T.expect(Style.resolve(card({ status = "Retry" })).actionState):toEqual("Retry")
		T.expect(Style.resolve(card({ status = "Unavailable" })).actionState):toEqual("Muted")
		T.expect(Style.resolve(card({ bonksPrice = 10 })).actionState):toEqual("Action")
		T.expect(Style.resolve(card({ status = "Unavailable" })).action.Text):toEqual("UNAVAILABLE")
		T.expect(Style.resolve(card({})).action.Text):toEqual("VIEW")
	end)
	T.it("tints only headline bodies and keeps catalog cards cream", function()
		local catalog = Style.resolve(card({ kind = "Crate" }))
		T.expect(catalog.bodyColor == C.SurfaceWarm):toBeTruthy()
		local headline = Style.resolve(card({ kind = "Crate", badge = "FEATURED" }), nil, { Headline = true })
		T.expect(headline.bodyColor == C.SurfaceWarm):toBeFalsy()
		T.expect(catalog.tileColor == catalog.accent):toBeFalsy()
		T.expect(catalog.tileColor.R >= catalog.accent.R and catalog.tileColor.B >= catalog.accent.B):toBeTruthy()
	end)
	T.it("picks the costume as the hero when a card previews several items", function()
		local items = { { category = "BallAssets" }, { category = "CostumeAssets" }, { category = "EmoteAssets" } }
		local style = Style.resolve(card({ kind = "Bundle", badge = "WEEKLY BUNDLE", previewItems = items }))
		T.expect(#style.previewItems):toEqual(1)
		T.expect(style.previewItems[1].category):toEqual("CostumeAssets")
		T.expect(#Style.resolve(card({ previewItems = { items[1] } })).previewItems):toEqual(1)
	end)
end)
return true
