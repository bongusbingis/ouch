-- Name: FeaturedRotation.spec.luau
-- Author: Jack C.
-- Description: Spec for the featured rotation schedule: one entry per period, agreement across servers from absolute time, countdowns, and discounts that round in the player's favour.
-- Created: 2026-08-12

--!strict

local T = require(script.Parent.TestKit)
local FeaturedRotation = require(script.Parent.Parent.Game.Economy.FeaturedRotation)
local Shop = require(script.Parent.Parent.Parent.Config.Shop)
local Crates = require(script.Parent.Parent.Parent.Config.Crates)

local WEEK = 7 * 24 * 60 * 60
local CONFIG = {
	RotationSeconds = WEEK,
	DiscountPercent = 15,
	Rotation = {
		{ kind = "Crate", id = "TrailCrate" },
		{ kind = "Crate", id = "BallCrate" },
	},
}

T.describe("FeaturedRotation", function()
	T.it("advances one entry per period and wraps around", function()
		T.expect(FeaturedRotation.select(CONFIG, 0).id):toEqual("TrailCrate")
		T.expect(FeaturedRotation.select(CONFIG, WEEK).id):toEqual("BallCrate")
		T.expect(FeaturedRotation.select(CONFIG, 2 * WEEK).id):toEqual("TrailCrate")
		T.expect(FeaturedRotation.select(CONFIG, 3 * WEEK).id):toEqual("BallCrate")
	end)

	T.it("holds the same entry for the whole period", function()
		local start = 10 * WEEK
		T.expect(FeaturedRotation.select(CONFIG, start).id):toEqual("TrailCrate")
		T.expect(FeaturedRotation.select(CONFIG, start + WEEK - 1).id):toEqual("TrailCrate")
		T.expect(FeaturedRotation.select(CONFIG, start + WEEK).id):toEqual("BallCrate")
	end)

	T.it("selects from absolute time only, so every server agrees", function()
		local now = 123456789
		local first = FeaturedRotation.select(CONFIG, now)
		local second = FeaturedRotation.select(CONFIG, now)
		T.expect(first.id):toEqual(second.id)
	end)

	T.it("counts down to the next rotation", function()
		local start = 4 * WEEK
		T.expect(FeaturedRotation.nextRotationAt(CONFIG.RotationSeconds, start)):toEqual(5 * WEEK)
		T.expect(FeaturedRotation.secondsUntilRotation(CONFIG.RotationSeconds, start)):toEqual(WEEK)
		T.expect(FeaturedRotation.secondsUntilRotation(CONFIG.RotationSeconds, start + WEEK - 30)):toEqual(30)
	end)

	T.it("discounts only the currently featured crate", function()
		local featuredWeek = 0
		T.expect(FeaturedRotation.priceFor(CONFIG, "TrailCrate", 1000, featuredWeek)):toEqual(850)
		T.expect(FeaturedRotation.priceFor(CONFIG, "BallCrate", 500, featuredWeek)):toEqual(500)

		local nextWeek = WEEK
		T.expect(FeaturedRotation.priceFor(CONFIG, "TrailCrate", 1000, nextWeek)):toEqual(1000)
		T.expect(FeaturedRotation.priceFor(CONFIG, "BallCrate", 500, nextWeek)):toEqual(425)
	end)

	T.it("rounds discounts in the player's favour and never to zero", function()
		T.expect(FeaturedRotation.discountedPrice(999, 15)):toEqual(849)
		T.expect(FeaturedRotation.discountedPrice(1, 99)):toEqual(1)
		T.expect(FeaturedRotation.discountedPrice(100, 0)):toEqual(100)
	end)

	T.it("returns nothing for an empty rotation rather than erroring", function()
		local empty = { RotationSeconds = WEEK, DiscountPercent = 10, Rotation = {} }
		T.expect(FeaturedRotation.select(empty, 0)):toBeNil()
		T.expect(FeaturedRotation.priceFor(empty, "TrailCrate", 1000, 0)):toEqual(1000)
	end)

	T.it("only ever features crates that actually exist", function()
		for _, entry in Shop.Featured.Rotation do
			if entry.kind == "Crate" then
				T.expect(Crates[entry.id] ~= nil):toBeTruthy()
				T.expect(Crates[entry.id].BonksPrice ~= nil):toBeTruthy()
			end
		end
	end)

	T.it("keeps the shipped discount meaningful but not economy-breaking", function()
		T.expect(Shop.Featured.DiscountPercent >= 5):toBeTruthy()
		T.expect(Shop.Featured.DiscountPercent <= 25):toBeTruthy()
	end)
end)

return true
