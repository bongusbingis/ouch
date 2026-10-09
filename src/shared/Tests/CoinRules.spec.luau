-- Description: Spec for the pure coin rules: tally and cap, free-spawn choice, and nearest collector.

--!strict

local T = require(script.Parent.TestKit)
local CoinRules = require(script.Parent.Parent.Game.Coins.CoinRules)

T.describe("CoinRules", function()
	T.it("grants full coins up to the cap, then a partial coin, then nothing", function()
		local tally = {}
		for _ = 1, 9 do
			T.expect(CoinRules.grant(tally, "a", 5, 48)):toEqual(5)
		end
		T.expect(CoinRules.grant(tally, "a", 5, 48)):toEqual(3)
		T.expect(CoinRules.atCap(tally, "a", 48)):toBeTruthy()
		T.expect(CoinRules.grant(tally, "a", 5, 48)):toEqual(0)
		T.expect(tally.a):toEqual(48)
		T.expect(CoinRules.atCap(tally, "b", 48)):toEqual(false)
	end)

	T.it("tallies players independently with the shipped 5/50 values", function()
		local tally = {}
		for _ = 1, 12 do
			CoinRules.grant(tally, "a", 5, 50)
		end
		T.expect(tally.a):toEqual(50)
		T.expect(CoinRules.grant(tally, "b", 5, 50)):toEqual(5)
	end)

	T.it("never picks an occupied spawn and returns nil when all are taken", function()
		local occupied = { [1] = true, [3] = true }
		for roll = 1, 2 do
			local picked = CoinRules.pickSpawn(4, occupied, function()
				return roll
			end)
			T.expect(picked == 2 or picked == 4):toBeTruthy()
		end
		T.expect(CoinRules.pickSpawn(2, { [1] = true, [2] = true }, function()
			return 1
		end)):toBeNil()
		T.expect(CoinRules.pickSpawn(0, {}, function()
			return 1
		end)):toBeNil()
	end)

	T.it("lets only the nearest player in radius collect", function()
		local found = CoinRules.collector({
			{ id = "far", distance = 9 },
			{ id = "b", distance = 3 },
			{ id = "a", distance = 3 },
			{ id = "near", distance = 4 },
		}, 5)
		T.expect(found):toEqual("a")
		T.expect(CoinRules.collector({ { id = "far", distance = 9 } }, 5)):toBeNil()
		T.expect(CoinRules.collector({}, 5)):toBeNil()
	end)
end)

return true
