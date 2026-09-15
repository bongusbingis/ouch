-- Name: RacePoints.spec.luau
-- Author: Jack C.
-- Description: Spec for Splashdown scoring: placement points, finish-time ordering with a deterministic tiebreak, cumulative standings that charge the cap for an unfinished round, and no winner when nobody finished.
-- Created: 2026-09-14

--!strict

local T = require(script.Parent.TestKit)
local RacePoints = require(script.Parent.Parent.Game.Splashdown.RacePoints)

T.describe("RacePoints", function()
	T.it("scores first place the capacity and never below one", function()
		T.expect(RacePoints.forPlacement(1, 30)):toEqual(30)
		T.expect(RacePoints.forPlacement(30, 30)):toEqual(1)
		T.expect(RacePoints.forPlacement(31, 30)):toEqual(1)
	end)

	T.it("orders finishers by time and breaks exact ties by id", function()
		local placements = RacePoints.placements({
			{ playerId = "3", time = 42.5 },
			{ playerId = "1", time = 40 },
			{ playerId = "2", time = 40 },
		}, 30)
		T.expect(placements[1].playerId):toEqual("1")
		T.expect(placements[2].playerId):toEqual("2")
		T.expect(placements[3].playerId):toEqual("3")
		T.expect(placements[1].placement):toEqual(1)
		T.expect(placements[3].placement):toEqual(3)
		T.expect(placements[1].points):toEqual(30)
		T.expect(placements[3].points):toEqual(28)
	end)

	T.it("accumulates points and charges the cap for a round a player did not finish", function()
		local standings = RacePoints.standings({
			{
				courseId = "A",
				capSeconds = 120,
				placements = {
					{ playerId = "1", time = 50, placement = 1, points = 30 },
					{ playerId = "2", time = 60, placement = 2, points = 29 },
				},
			},
			{
				courseId = "B",
				capSeconds = 150,
				placements = {
					{ playerId = "2", time = 70, placement = 1, points = 30 },
				},
			},
		}, { "1", "2", "3" })
		T.expect(standings[1].playerId):toEqual("2")
		T.expect(standings[1].points):toEqual(59)
		T.expect(standings[1].time):toEqual(130)
		T.expect(standings[1].bestPlacement):toEqual(1)
		T.expect(standings[2].playerId):toEqual("1")
		T.expect(standings[2].time):toEqual(200)
		T.expect(standings[2].finishes):toEqual(1)
		T.expect(standings[3].playerId):toEqual("3")
		T.expect(standings[3].points):toEqual(0)
		T.expect(standings[3].time):toEqual(270)
		T.expect(standings[3].bestPlacement):toBeNil()
	end)

	T.it("breaks equal points by lower cumulative time", function()
		local standings = RacePoints.standings({
			{
				courseId = "A",
				capSeconds = 120,
				placements = {
					{ playerId = "slow", time = 90, placement = 1, points = 30 },
					{ playerId = "fast", time = 95, placement = 2, points = 30 },
				},
			},
		}, { "fast", "slow" })
		T.expect(standings[1].playerId):toEqual("slow")
		T.expect(RacePoints.winner(standings)):toEqual("slow")
	end)

	T.it("names no winner when nobody scored", function()
		local standings = RacePoints.standings({ { courseId = "A", capSeconds = 120, placements = {} } }, { "1", "2" })
		T.expect(RacePoints.winner(standings)):toBeNil()
		T.expect(RacePoints.winner({})):toBeNil()
	end)
end)

return true
