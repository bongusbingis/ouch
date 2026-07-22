--!strict

local T = require(script.Parent.TestKit)

local Client = script.Parent.Parent.Parent.Parent.StarterPlayer.StarterPlayerScripts.Client
local LiveScoreboardModel = require(Client.Modules.UI.LiveScoreboardModel)

T.describe("LiveScoreboardModel", function()
	T.it("orders FFA scores and pins the local player below the visible leaders", function()
		local model = LiveScoreboardModel.ffa({
			{ userId = 4, displayName = "Local", score = 1, teamId = nil, isLocal = true },
			{ userId = 3, displayName = "Third", score = 3, teamId = nil, isLocal = false },
			{ userId = 2, displayName = "Second", score = 4, teamId = nil, isLocal = false },
			{ userId = 1, displayName = "First", score = 5, teamId = nil, isLocal = false },
		}, 3)

		T.expect(model.rows[1].userId):toEqual(1)
		T.expect(model.rows[3].userId):toEqual(3)
		T.expect((model.localRow :: LiveScoreboardModel.RankedEntry).rank):toEqual(4)
	end)

	T.it("uses user id as the stable FFA tie breaker without mutating input", function()
		local entries = {
			{ userId = 8, displayName = "Eight", score = 2, teamId = nil, isLocal = false },
			{ userId = 3, displayName = "Three", score = 2, teamId = nil, isLocal = false },
		}
		local model = LiveScoreboardModel.ffa(entries, 3)

		T.expect(model.rows[1].userId):toEqual(3)
		T.expect(entries[1].userId):toEqual(8)
		T.expect(model.localRow):toBeNil()
	end)

	T.it("preserves team order and ranks players within each team", function()
		local model = LiveScoreboardModel.teams({
			{ userId = 3, displayName = "Red Two", score = 2, teamId = "Red", isLocal = false },
			{ userId = 2, displayName = "Blue One", score = 6, teamId = "Blue", isLocal = true },
			{ userId = 1, displayName = "Red One", score = 4, teamId = "Red", isLocal = false },
		}, { "Red", "Blue" }, { Red = 9, Blue = 7 }, 2)

		T.expect(model.teams[1].id):toEqual("Red")
		T.expect(model.teams[1].score):toEqual(9)
		T.expect(model.teams[1].rows[1].userId):toEqual(1)
		T.expect(model.teams[2].rows[1].isLocal):toBeTruthy()
	end)
end)

return true
