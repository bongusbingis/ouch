-- Description: Spec for the starter offer window: active only before it elapses and before conversion, formatted countdowns, and that it points at a real purchasable pass.

--!strict

local T = require(script.Parent.TestKit)
local StarterOffer = require(script.Parent.Parent.Game.Economy.StarterOffer)
local GamePasses = require(script.Parent.Parent.Parent.Config.Economy.GamePasses)

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
		T.expect(pass.CatalogStatus):toEqual("Active")
		T.expect(pass.Id ~= nil):toBeTruthy()
	end)
end)

T.describe("StarterOffer.resolve", function()
	local PASS = { CatalogStatus = "Active", Id = 1968922292 }

	local function context(overrides)
		local base = {
			ready = true,
			ownsPass = false,
			ownsAnyPass = false,
			receipts = {},
			firstJoinAt = JOINED,
			now = JOINED + 3600,
		}
		for key, value in overrides or {} do
			base[key] = value
		end
		return base
	end

	T.it("resolves the window for a stamped new player who has bought nothing", function()
		local resolved = StarterOffer.resolve(CONFIG, PASS, context())
		T.expect(resolved ~= nil):toBeTruthy()
		T.expect((resolved :: any).passKey):toEqual(CONFIG.PassKey)
		T.expect((resolved :: any).expiresAt):toEqual(JOINED + CONFIG.WindowSeconds)
	end)

	T.it("withholds the offer until pass ownership is known", function()
		T.expect(StarterOffer.resolve(CONFIG, PASS, context({ ready = false }))):toBeNil()
	end)

	T.it("withholds the offer from a player who already owns the starter pass", function()
		T.expect(StarterOffer.resolve(CONFIG, PASS, context({ ownsPass = true }))):toBeNil()
	end)

	T.it("withholds the offer after any other pass or any receipt", function()
		T.expect(StarterOffer.resolve(CONFIG, PASS, context({ ownsAnyPass = true }))):toBeNil()
		T.expect(StarterOffer.resolve(CONFIG, PASS, context({ receipts = { ["12345"] = 1 } }))):toBeNil()
	end)

	T.it("withholds the offer from an unstamped profile and past the deadline", function()
		T.expect(StarterOffer.resolve(CONFIG, PASS, context({ firstJoinAt = 0 }))):toBeNil()
		T.expect(StarterOffer.resolve(CONFIG, PASS, context({ now = JOINED + CONFIG.WindowSeconds }))):toBeNil()
	end)

	-- A pass that cannot be bought must never be merchandised as an offer: a
	-- Preview or id-less entry would present a purchase action nobody can complete.
	T.it("refuses to merchandise a pass that is missing, preview, or unconfigured", function()
		T.expect(StarterOffer.resolve(CONFIG, nil, context())):toBeNil()
		T.expect(StarterOffer.resolve(CONFIG, { CatalogStatus = "Preview", Id = 1 }, context())):toBeNil()
		T.expect(StarterOffer.resolve(CONFIG, { CatalogStatus = "Active", Id = nil }, context())):toBeNil()
	end)
end)

return true
