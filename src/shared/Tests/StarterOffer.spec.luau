-- Name: StarterOffer.spec.luau
-- Author: Jack C.
-- Description: Spec for the starter offer window: active only before it elapses and before conversion, formatted countdowns, and that it points at a real purchasable pass.
-- Created: 2026-08-12

--!strict

local T = require(script.Parent.TestKit)
local StarterOffer = require(script.Parent.Parent.Game.Economy.StarterOffer)
local GamePasses = require(script.Parent.Parent.Parent.Config.GamePasses)

local CONFIG = { PassKey = "SplatStarter", WindowSeconds = 72 * 60 * 60 }
local JOINED = 1000000

T.describe("StarterOffer", function()
	T.it("is active inside the window for a player who has never purchased", function()
		local state = StarterOffer.evaluate(CONFIG, JOINED, JOINED + 3600, false)
		T.expect(state.active):toEqual(true)
		T.expect(state.expiresAt):toEqual(JOINED + CONFIG.WindowSeconds)
		T.expect(state.secondsRemaining):toEqual(CONFIG.WindowSeconds - 3600)
	end)

	T.it("expires exactly at the window edge", function()
		local justInside = StarterOffer.evaluate(CONFIG, JOINED, JOINED + CONFIG.WindowSeconds - 1, false)
		T.expect(justInside.active):toEqual(true)

		local atEdge = StarterOffer.evaluate(CONFIG, JOINED, JOINED + CONFIG.WindowSeconds, false)
		T.expect(atEdge.active):toEqual(false)
	end)

	T.it("stops the moment the player converts, even inside the window", function()
		local state = StarterOffer.evaluate(CONFIG, JOINED, JOINED + 60, true)
		T.expect(state.active):toEqual(false)
	end)

	T.it("stays inactive until the profile has been stamped", function()
		T.expect(StarterOffer.evaluate(CONFIG, nil, JOINED, false).active):toEqual(false)
		T.expect(StarterOffer.evaluate(CONFIG, 0, JOINED, false).active):toEqual(false)
	end)

	T.it("treats any receipt or any owned pass as already converted", function()
		T.expect(StarterOffer.hasPurchased({}, false)):toEqual(false)
		T.expect(StarterOffer.hasPurchased(nil, false)):toEqual(false)
		T.expect(StarterOffer.hasPurchased({ ["12345"] = 1700000000 }, false)):toEqual(true)
		T.expect(StarterOffer.hasPurchased({}, true)):toEqual(true)
	end)

	T.it("formats the remaining time at day, hour, and minute scales", function()
		T.expect(StarterOffer.formatRemaining(72 * 3600)):toEqual("3d 0h")
		T.expect(StarterOffer.formatRemaining(50 * 3600)):toEqual("2d 2h")
		T.expect(StarterOffer.formatRemaining(3 * 3600 + 25 * 60)):toEqual("3h 25m")
		T.expect(StarterOffer.formatRemaining(90)):toEqual("1m")
		T.expect(StarterOffer.formatRemaining(-5)):toEqual("0m")
	end)

	T.it("points at a real, purchasable pass in the shipped config", function()
		local offer = GamePasses.StarterOffer
		local pass = GamePasses.Catalog[offer.PassKey]
		T.expect(pass ~= nil):toBeTruthy()
		T.expect(offer.WindowSeconds > 0):toBeTruthy()
		for _, definition in GamePasses.Catalog do
			T.expect(pass.SuggestedRobux <= definition.SuggestedRobux):toBeTruthy()
		end
	end)
end)

return true
