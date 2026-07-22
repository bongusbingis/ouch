--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local LeaderboardStandings = require(Client.Modules.UI.LeaderboardStandings)

T.describe("LeaderboardStandings", function()
	T.it("sorts by score, then eliminations, then stable user id", function()
		local sorted = LeaderboardStandings.sorted({
			{ userId = 30, displayName = "C", score = 4, elims = 3 },
			{ userId = 20, displayName = "B", score = 5, elims = 1 },
			{ userId = 10, displayName = "A", score = 5, elims = 2 },
			{ userId = 5, displayName = "D", score = 4, elims = 3 },
		})

		T.expect(sorted[1].userId):toEqual(10)
		T.expect(sorted[2].userId):toEqual(20)
		T.expect(sorted[3].userId):toEqual(5)
		T.expect(sorted[4].userId):toEqual(30)
	end)

	T.it("does not mutate the input order", function()
		local entries = {
			{ userId = 2, displayName = "B", score = 1, elims = 0 },
			{ userId = 1, displayName = "A", score = 2, elims = 0 },
		}
		LeaderboardStandings.sorted(entries)
		T.expect(entries[1].userId):toEqual(2)
	end)
end)

return true
