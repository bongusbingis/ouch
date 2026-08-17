--!strict

local T = require(script.Parent.TestKit)
local PopulationPolicy = require(script.Parent.Parent.Game.Matchmaking.PopulationPolicy)

local EXPANSIONS = {
	{ AfterSeconds = 0, MinimumPlayers = 20 },
	{ AfterSeconds = 8, MinimumPlayers = 16 },
	{ AfterSeconds = 16, MinimumPlayers = 12 },
	{ AfterSeconds = 24, MinimumPlayers = 8 },
	{ AfterSeconds = 30, MinimumPlayers = 1 },
}

T.describe("PopulationPolicy", function()
	T.it("relaxes the required population as the oldest ticket waits", function()
		T.expect(PopulationPolicy.requiredPlayers(EXPANSIONS, 0, 20)):toEqual(20)
		T.expect(PopulationPolicy.requiredPlayers(EXPANSIONS, 7.99, 20)):toEqual(20)
		T.expect(PopulationPolicy.requiredPlayers(EXPANSIONS, 8, 20)):toEqual(16)
		T.expect(PopulationPolicy.requiredPlayers(EXPANSIONS, 24, 20)):toEqual(8)
		T.expect(PopulationPolicy.requiredPlayers(EXPANSIONS, 30, 20)):toEqual(1)
	end)

	T.it("clamps configured thresholds to a viable target range", function()
		T.expect(PopulationPolicy.requiredPlayers({ { AfterSeconds = 0, MinimumPlayers = 50 } }, 0, 20)):toEqual(20)
		T.expect(PopulationPolicy.requiredPlayers({ { AfterSeconds = 0, MinimumPlayers = 0 } }, 0, 20)):toEqual(1)
	end)
end)

return true
