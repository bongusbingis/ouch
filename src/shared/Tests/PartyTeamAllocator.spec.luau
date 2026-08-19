--!strict

local T = require(script.Parent.TestKit)
local PartyTeamAllocator = require(script.Parent.Parent.Game.Modes.PartyTeamAllocator)

local TEAMS = { "Red", "Blue" }

T.describe("PartyTeamAllocator", function()
	T.it("keeps parties together while finding the closest two-team balance", function()
		local assignments = PartyTeamAllocator.assign({
			{ id = "1", partyId = "alpha" },
			{ id = "2", partyId = "alpha" },
			{ id = "3", partyId = "alpha" },
			{ id = "4", partyId = "beta" },
			{ id = "5", partyId = "beta" },
			{ id = "6", partyId = nil },
		}, TEAMS)

		T.expect(assignments["1"]):toEqual(assignments["2"])
		T.expect(assignments["2"]):toEqual(assignments["3"])
		T.expect(assignments["4"]):toEqual(assignments["5"])

		local counts = { Red = 0, Blue = 0 }
		for _, teamId in assignments do
			counts[teamId] += 1
		end
		T.expect(math.abs(counts.Red - counts.Blue)):toEqual(0)
	end)

	T.it("is deterministic for the same entrants", function()
		local entrants = {
			{ id = "4", partyId = nil },
			{ id = "2", partyId = "party" },
			{ id = "1", partyId = "party" },
			{ id = "3", partyId = nil },
		}
		local first = PartyTeamAllocator.assign(entrants, TEAMS)
		local second = PartyTeamAllocator.assign(entrants, TEAMS)
		for entrantId, teamId in first do
			T.expect(second[entrantId]):toEqual(teamId)
		end
	end)
end)

return true
