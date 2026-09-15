-- Name: RaceRound.spec.luau
-- Author: Jack C.
-- Description: Spec for one Splashdown round: checkpoints only count in order, finishing needs every checkpoint, the first finisher shortens the close, everyone finishing closes at once, the cap closes regardless, and splashes respawn at the last checkpoint.
-- Created: 2026-09-14

--!strict

local T = require(script.Parent.TestKit)
local RaceRound = require(script.Parent.Parent.Game.Splashdown.RaceRound)

local function racing(): RaceRound.Round
	local round = RaceRound.new("WhirlPool", 3, 120, 30)
	RaceRound.addRacer(round, "a")
	RaceRound.addRacer(round, "b")
	RaceRound.start(round, 100)
	return round
end

T.describe("RaceRound", function()
	T.it("only counts the next checkpoint in order", function()
		local round = racing()
		T.expect(RaceRound.reachCheckpoint(round, "a", 2)):toEqual(false)
		T.expect(RaceRound.reachCheckpoint(round, "a", 1)):toEqual(true)
		T.expect(RaceRound.reachCheckpoint(round, "a", 1)):toEqual(false)
		T.expect(RaceRound.reachCheckpoint(round, "a", 3)):toEqual(false)
		T.expect(RaceRound.reachCheckpoint(round, "a", 2)):toEqual(true)
		T.expect(RaceRound.respawnIndex(round, "a")):toEqual(2)
		T.expect(RaceRound.respawnIndex(round, "b")):toEqual(0)
		T.expect(RaceRound.reachCheckpoint(round, "missing", 1)):toEqual(false)
	end)

	T.it("refuses a finish before every checkpoint and records the race time", function()
		local round = racing()
		T.expect(RaceRound.finish(round, "a", 130)):toEqual(false)
		for index = 1, 3 do
			RaceRound.reachCheckpoint(round, "a", index)
		end
		T.expect(RaceRound.finish(round, "a", 145.5)):toEqual(true)
		T.expect(round.racers.a.finishTime):toBeNear(45.5)
		T.expect(RaceRound.finish(round, "a", 150)):toEqual(false)
		T.expect(RaceRound.reachCheckpoint(round, "a", 1)):toEqual(false)
		T.expect(RaceRound.hasFinished(round, "a")):toEqual(true)
	end)

	T.it("closes the window after the first finisher, when everyone finishes, or at the cap", function()
		local round = racing()
		T.expect(RaceRound.shouldClose(round, 219)):toEqual(false)
		T.expect(RaceRound.shouldClose(round, 220)):toEqual(true)

		local second = racing()
		for index = 1, 3 do
			RaceRound.reachCheckpoint(second, "a", index)
		end
		RaceRound.finish(second, "a", 150)
		T.expect(second.closesAt):toEqual(180)
		T.expect(RaceRound.shouldClose(second, 179)):toEqual(false)
		T.expect(RaceRound.shouldClose(second, 180)):toEqual(true)

		for index = 1, 3 do
			RaceRound.reachCheckpoint(second, "b", index)
		end
		RaceRound.finish(second, "b", 160)
		T.expect(RaceRound.shouldClose(second, 161)):toEqual(true)
		T.expect(second.closesAt):toEqual(180)
	end)

	T.it("never lets the close window extend the cap", function()
		local round = RaceRound.new("SummitSplash", 1, 100, 30)
		RaceRound.addRacer(round, "a")
		RaceRound.start(round, 0)
		RaceRound.reachCheckpoint(round, "a", 1)
		RaceRound.finish(round, "a", 90)
		T.expect(round.closesAt):toEqual(100)
	end)

	T.it("counts splashes only for racers still racing", function()
		local round = racing()
		T.expect(RaceRound.splash(round, "a")):toEqual(1)
		T.expect(RaceRound.splash(round, "a")):toEqual(2)
		for index = 1, 3 do
			RaceRound.reachCheckpoint(round, "a", index)
		end
		RaceRound.finish(round, "a", 150)
		T.expect(RaceRound.splash(round, "a")):toBeNil()
		T.expect(RaceRound.splash(round, "missing")):toBeNil()
	end)

	T.it("closes into finishers and DNFs and stops accepting progress", function()
		local round = racing()
		RaceRound.addRacer(round, "c")
		RaceRound.removeRacer(round, "c")
		for index = 1, 3 do
			RaceRound.reachCheckpoint(round, "b", index)
		end
		RaceRound.finish(round, "b", 140)
		local outcome = RaceRound.close(round)
		T.expect(#outcome.finishers):toEqual(1)
		T.expect(outcome.finishers[1].playerId):toEqual("b")
		T.expect(outcome.finishers[1].time):toEqual(40)
		T.expect(table.concat(outcome.dnf, ",")):toEqual("a")
		T.expect(round.phase):toEqual("Closed")
		T.expect(RaceRound.reachCheckpoint(round, "a", 1)):toEqual(false)
		T.expect(RaceRound.shouldClose(round, 1000)):toEqual(false)
	end)

	T.it("does not race before it starts", function()
		local round = RaceRound.new("DiscJockey", 2, 120, 30)
		RaceRound.addRacer(round, "a")
		T.expect(RaceRound.reachCheckpoint(round, "a", 1)):toEqual(false)
		T.expect(RaceRound.shouldClose(round, 1000)):toEqual(false)
		T.expect(RaceRound.start(round, 5)):toEqual(true)
		T.expect(RaceRound.start(round, 6)):toEqual(false)
	end)
end)

return true
