--!nonstrict
-- Cloud port of the TeamSpawns spec: axis selection by spread, odd-count
-- distribution, determinism, and input validation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local TeamSpawns = require(Shared:WaitForChild("Game"):WaitForChild("Maps"):WaitForChild("TeamSpawns"))

local TEAMS = { "Red", "Blue" }

local function contains(group, index): boolean
	return table.find(group, index) ~= nil
end

return function()
	describe("TeamSpawns", function()
		it("splits along the X axis when X has the greater spread", function()
			local positions = {
				vector.create(0, 0, 3),
				vector.create(30, 0, 0),
				vector.create(10, 0, 5),
				vector.create(20, 0, 2),
			}
			local split = TeamSpawns.split(positions, TEAMS)
			expect(contains(split.Red, 1) and contains(split.Red, 3)).to.equal(true)
			expect(contains(split.Blue, 4) and contains(split.Blue, 2)).to.equal(true)
		end)

		it("splits along the Z axis when Z has the greater spread", function()
			local positions = {
				vector.create(3, 0, 0),
				vector.create(0, 0, 40),
				vector.create(5, 0, 10),
				vector.create(2, 0, 30),
			}
			local split = TeamSpawns.split(positions, TEAMS)
			expect(contains(split.Red, 1) and contains(split.Red, 3)).to.equal(true)
			expect(contains(split.Blue, 4) and contains(split.Blue, 2)).to.equal(true)
		end)

		it("gives earlier teams the extra spawn on odd counts", function()
			local positions = {
				vector.create(0, 0, 0),
				vector.create(10, 0, 0),
				vector.create(20, 0, 0),
				vector.create(30, 0, 0),
				vector.create(40, 0, 0),
			}
			local split = TeamSpawns.split(positions, TEAMS)
			expect(#split.Red).to.equal(3)
			expect(#split.Blue).to.equal(2)
		end)

		it("is deterministic for tied coordinates", function()
			local positions = {
				vector.create(0, 0, 0),
				vector.create(0, 0, 0),
				vector.create(0, 0, 0),
				vector.create(0, 0, 0),
			}
			local first = TeamSpawns.split(positions, TEAMS)
			local second = TeamSpawns.split(positions, TEAMS)
			for _, teamId in TEAMS do
				expect(#first[teamId]).to.equal(#second[teamId])
				for slot, index in first[teamId] do
					expect(second[teamId][slot]).to.equal(index)
				end
			end
		end)

		it("rejects fewer spawn points than teams", function()
			expect(function()
				TeamSpawns.split({ vector.create(0, 0, 0) }, TEAMS)
			end).to.throw()
		end)

		it("assigns every spawn point to exactly one team", function()
			local positions = {
				vector.create(0, 0, 0),
				vector.create(10, 0, 0),
				vector.create(20, 0, 0),
				vector.create(30, 0, 0),
			}
			local split = TeamSpawns.split(positions, TEAMS)
			local seen = {}
			for _, teamId in TEAMS do
				for _, index in split[teamId] do
					expect(seen[index]).never.to.be.ok()
					seen[index] = true
				end
			end
			for index = 1, #positions do
				expect(seen[index]).to.equal(true)
			end
		end)
	end)
end
