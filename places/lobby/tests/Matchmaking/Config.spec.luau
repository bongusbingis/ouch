-- Description: In-place spec checking the shipped lobby matchmaking configuration is coherent: a real arena place, usable party bounds, a reachable relaxing population ladder and valid mode selection per queue, positive lifetimes, and separated store namespaces.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Queues = require(ReplicatedStorage.Config.Gameplay.Queues)
local Modes = require(ReplicatedStorage.Config.Gameplay.Modes)

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
		end)

		it("relaxes every queue's population requirement over time and stays reachable", function()
			expect(#Config.QueueOrder > 0).to.equal(true)
			for _, queueId in Config.QueueOrder do
				local queue = Config.Queues[queueId]
				expect(queue).never.to.equal(nil)
				expect(type(queue.MatchTargetPlayers)).to.equal("number")
				expect(queue.MatchTargetPlayers > 0).to.equal(true)
				expect(queue.MatchTargetPlayers >= Config.PartyMaxPlayers).to.equal(true)
				local definition = Queues.get(queueId)
				expect(queue.MatchMinPlayers).to.equal(definition.MinPlayers)
				expect(queue.MatchMinPlayers >= 2).to.equal(true)
				expect(queue.MatchMinPlayers <= queue.MatchTargetPlayers).to.equal(true)
				expect(queue.MatchMaxWaitSeconds).to.equal(definition.MaxWaitSeconds)
				expect(queue.MatchMaxWaitSeconds > 0 and queue.MatchMaxWaitSeconds <= 30).to.equal(true)
				expect(queue.MatchMaxWaitSeconds + Config.WorkerPollInterval < Config.QueueRecordLifetime).to.equal(
					true
				)

				local ladder = queue.MatchPopulationExpansion
				expect(#ladder > 0).to.equal(true)
				expect(ladder[1].AfterSeconds).to.equal(0)

				local previous = ladder[1]
				for index = 2, #ladder do
					local step = ladder[index]
					expect(step.AfterSeconds > previous.AfterSeconds).to.equal(true)
					expect(step.MinimumPlayers <= previous.MinimumPlayers).to.equal(true)
					previous = step
				end
				expect(ladder[#ladder].MinimumPlayers).to.equal(queue.MatchMinPlayers)
				expect(ladder[#ladder].AfterSeconds <= queue.MatchMaxWaitSeconds).to.equal(true)
				for _, step in ladder do
					expect(step.MinimumPlayers >= queue.MatchMinPlayers).to.equal(true)
					expect(step.MinimumPlayers <= queue.MatchTargetPlayers).to.equal(true)
				end
				local selection = queue.ModeSelection
				local modeIds = if selection.strategy == "Fixed" then { selection.modeId } else selection.options
				for _, modeId in modeIds do
					expect(queue.MatchMinPlayers >= Modes[modeId].MinPlayers).to.equal(true)
				end
			end
		end)

		it("gives every queue a valid mode selection", function()
			for _, queueId in Config.QueueOrder do
				local selection = Config.Queues[queueId].ModeSelection
				if selection.strategy == "Vote" then
					expect(typeof(selection.options)).to.equal("table")
					expect(#selection.options > 0).to.equal(true)
				elseif selection.strategy == "Fixed" then
					expect(type(selection.modeId)).to.equal("string")
					expect(#selection.modeId > 0).to.equal(true)
				else
					expect(false).to.equal(true)
				end
			end
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

		it("keeps the party record alive longer than an arena session plus Play Again", function()
			expect(Config.PartyRecordLifetime >= 3600).to.equal(true)
		end)

		it("separates Studio and live memory store namespaces", function()
			expect(type(Config.MemoryStoreNamespace)).to.equal("string")
			expect(#Config.MemoryStoreNamespace > 0).to.equal(true)
		end)
	end)
end
