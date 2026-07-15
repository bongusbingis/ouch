--!strict

local T = require(script.Parent.TestKit)
local TeamSpawns = require(script.Parent.Parent.Game.Maps.TeamSpawns)

local TEAMS = { "Red", "Blue" }

local function contains(group: { number }, index: number): boolean
	return table.find(group, index) ~= nil
end

T.describe("TeamSpawns", function()
	T.it("splits along the X axis when X has the greater spread", function()
		local positions = {
			vector.create(0, 0, 3),
			vector.create(30, 0, 0),
			vector.create(10, 0, 5),
			vector.create(20, 0, 2),
		}
		local split = TeamSpawns.split(positions, TEAMS)
		T.expect(contains(split.Red, 1) and contains(split.Red, 3)):toBeTruthy()
		T.expect(contains(split.Blue, 4) and contains(split.Blue, 2)):toBeTruthy()
	end)

	T.it("splits along the Z axis when Z has the greater spread", function()
		local positions = {
			vector.create(3, 0, 0),
			vector.create(0, 0, 40),
			vector.create(5, 0, 10),
			vector.create(2, 0, 30),
		}
		local split = TeamSpawns.split(positions, TEAMS)
		T.expect(contains(split.Red, 1) and contains(split.Red, 3)):toBeTruthy()
		T.expect(contains(split.Blue, 4) and contains(split.Blue, 2)):toBeTruthy()
	end)

	T.it("gives earlier teams the extra spawn on odd counts", function()
		local positions = {
			vector.create(0, 0, 0),
			vector.create(10, 0, 0),
			vector.create(20, 0, 0),
			vector.create(30, 0, 0),
			vector.create(40, 0, 0),
		}
		local split = TeamSpawns.split(positions, TEAMS)
		T.expect(#split.Red):toEqual(3)
		T.expect(#split.Blue):toEqual(2)
	end)

	T.it("is deterministic for tied coordinates", function()
		local positions = {
			vector.create(0, 0, 0),
			vector.create(0, 0, 0),
			vector.create(0, 0, 0),
			vector.create(0, 0, 0),
		}
		local first = TeamSpawns.split(positions, TEAMS)
		local second = TeamSpawns.split(positions, TEAMS)
		for teamIndex, teamId in TEAMS do
			T.expect(#first[teamId]):toEqual(#second[teamId])
			for slot, index in first[teamId] do
				T.expect(second[teamId][slot]):toEqual(index)
			end
			T.expect(teamIndex <= 2):toBeTruthy()
		end
	end)

	T.it("rejects fewer spawn points than teams", function()
		local ok = pcall(function()
			TeamSpawns.split({ vector.create(0, 0, 0) }, TEAMS)
		end)
		T.expect(ok):toEqual(false)
	end)
end)

return true
