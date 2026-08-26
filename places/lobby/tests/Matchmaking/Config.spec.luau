-- Name: Config.spec.luau
-- Author: Jack C.
-- Description: In-place spec checking the shipped lobby matchmaking configuration is coherent: a real arena place, usable party bounds, a reachable relaxing population target, positive lifetimes, and separated store namespaces.
-- Created: 2026-08-18

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))

return function()
	describe("Matchmaking config", function()
		it("points at a real arena place", function()
			expect(type(Config.ArenaPlaceId)).to.equal("number")
			expect(Config.ArenaPlaceId > 0).to.equal(true)
			expect(Config.ArenaPlaceId).never.to.equal(game.PlaceId)
		end)

		it("keeps party bounds usable", function()
			expect(Config.PartyMinPlayers >= 1).to.equal(true)
			expect(Config.PartyMaxPlayers >= Config.PartyMinPlayers).to.equal(true)
			expect(Config.MatchTargetPlayers >= Config.PartyMaxPlayers).to.equal(true)
		end)

		it("relaxes the population requirement over time and stays reachable", function()
			local ladder = Config.MatchPopulationExpansion
			expect(#ladder > 0).to.equal(true)
			expect(ladder[1].AfterSeconds).to.equal(0)

			local previous = ladder[1]
			for index = 2, #ladder do
				local step = ladder[index]
				expect(step.AfterSeconds > previous.AfterSeconds).to.equal(true)
				expect(step.MinimumPlayers <= previous.MinimumPlayers).to.equal(true)
				previous = step
			end
			expect(ladder[#ladder].MinimumPlayers <= Config.PartyMaxPlayers).to.equal(true)
		end)

		it("keeps every lifetime and interval positive", function()
			local durations = {
				"PartyRecordLifetime",
				"PresenceLifetime",
				"PresenceHeartbeatInterval",
				"QueueRecordLifetime",
				"ClaimLifetime",
				"WorkerLeaseLifetime",
				"WorkerPollInterval",
				"MatchRecordLifetime",
			}
			for _, name in durations do
				local value = (Config :: any)[name]
				expect(type(value)).to.equal("number")
				expect(value > 0).to.equal(true)
			end
		end)

		it("separates Studio and live memory store namespaces", function()
			expect(type(Config.MemoryStoreNamespace)).to.equal("string")
			expect(#Config.MemoryStoreNamespace > 0).to.equal(true)
		end)
	end)
end
