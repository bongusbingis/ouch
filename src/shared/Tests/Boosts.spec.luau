--!strict

local T = require(script.Parent.TestKit)
local Boosts = require(script.Parent.Parent.Game.Economy.Boosts)
local GamePasses = require(script.Parent.Parent.Parent.Config.GamePasses)

local CATALOG = {
	Cosmetic = { EntitlementItemIds = { "TrailX" } },
	DoubleXP = { Boosts = { XpMultiplier = 2 } },
	BonksBoost = { Boosts = { BonksMultiplier = 1.5 } },
	Club = { Boosts = { XpMultiplier = 2.5, BonksMultiplier = 1.5 } },
}

T.describe("Boosts", function()
	T.it("defaults to no multiplier when nothing is owned", function()
		local result = Boosts.multipliers(CATALOG, {})
		T.expect(result.Xp):toEqual(1)
		T.expect(result.Bonks):toEqual(1)
	end)

	T.it("ignores cosmetic-only passes", function()
		local result = Boosts.multipliers(CATALOG, { Cosmetic = true })
		T.expect(result.Xp):toEqual(1)
		T.expect(result.Bonks):toEqual(1)
	end)

	T.it("applies a single owned booster", function()
		local result = Boosts.multipliers(CATALOG, { DoubleXP = true })
		T.expect(result.Xp):toEqual(2)
		T.expect(result.Bonks):toEqual(1)
	end)

	T.it("takes the best of overlapping boosters rather than compounding them", function()
		local result = Boosts.multipliers(CATALOG, { DoubleXP = true, BonksBoost = true, Club = true })
		-- Multiplicative would be 2 * 2.5 = 5x XP; max-wins keeps it at 2.5.
		T.expect(result.Xp):toEqual(2.5)
		T.expect(result.Bonks):toEqual(1.5)
	end)

	T.it("combines different multiplier types from separate passes", function()
		local result = Boosts.multipliers(CATALOG, { DoubleXP = true, BonksBoost = true })
		T.expect(result.Xp):toEqual(2)
		T.expect(result.Bonks):toEqual(1.5)
	end)

	T.it("treats a false ownership entry as unowned", function()
		local result = Boosts.multipliers(CATALOG, { DoubleXP = false })
		T.expect(result.Xp):toEqual(1)
	end)

	T.it("floors boosted amounts and never returns less than the base", function()
		T.expect(Boosts.apply(155, 2.5)):toEqual(387)
		T.expect(Boosts.apply(0, 2.5)):toEqual(0)
		T.expect(Boosts.apply(10, 1)):toEqual(10)
		T.expect(Boosts.apply(3, 1.5)):toEqual(4)
	end)

	T.it("keeps the shipped bundle strictly better than the boosters it replaces", function()
		-- A player who already owns DoubleXP must still gain from Brawler's Club,
		-- otherwise the upgrade is a dead purchase under max-wins.
		local club = GamePasses.Catalog.BrawlersClub.Boosts
		local doubleXp = GamePasses.Catalog.DoubleXP.Boosts
		local bonksBoost = GamePasses.Catalog.BonksBoost.Boosts
		T.expect(club.XpMultiplier > doubleXp.XpMultiplier):toBeTruthy()
		T.expect(club.BonksMultiplier >= bonksBoost.BonksMultiplier):toBeTruthy()
	end)

	T.it("never lets a shipped booster touch anything but XP and Bonks", function()
		for key, definition in GamePasses.Catalog do
			if definition.Boosts ~= nil then
				for field in definition.Boosts do
					local allowed = field == "XpMultiplier" or field == "BonksMultiplier"
					T.expect(allowed):toBeTruthy()
					if not allowed then
						error(`game pass "{key}" declares a non-earn-rate boost "{field}"`)
					end
				end
			end
		end
	end)
end)

return true
