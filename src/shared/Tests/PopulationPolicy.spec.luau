-- Regression coverage for quiet queues, population boundaries, and the viable floor.
--!strict

local T = require(script.Parent.TestKit)
local PopulationPolicy = require(script.Parent.Parent.Game.Matchmaking.PopulationPolicy)
local Queues = require(script.Parent.Parent.Parent.Config.Gameplay.Queues)

local function required(queue, seconds)
	return PopulationPolicy.requiredPlayers(
		queue.PopulationExpansion,
		seconds,
		queue.MatchCapacity,
		queue.MinPlayers,
		queue.MaxWaitSeconds
	)
end

T.describe("PopulationPolicy", function()
	T.it("relaxes Splashdown at each boundary while giving larger races a chance to fill", function()
		local queue = Queues.get("Splashdown")
		local boundaries = {}
		for _, step in queue.PopulationExpansion do
			table.insert(boundaries, { seconds = step.AfterSeconds, players = step.MinimumPlayers })
		end
		T.expect(boundaries[1].players):toEqual(queue.MatchCapacity)
		T.expect(boundaries[#boundaries].players):toEqual(queue.MinPlayers)
		for index, boundary in boundaries do
			T.expect(required(queue, boundary.seconds)):toEqual(boundary.players)
			if index > 1 then
				T.expect(required(queue, boundary.seconds - 0.001)):toEqual(boundaries[index - 1].players)
			end
		end
	end)

	T.it("makes the minimum roster eligible by 30 seconds and keeps it eligible after three minutes", function()
		for _, queueId in Queues.Order do
			local queue = Queues.get(queueId)
			T.expect(queue.MinPlayers <= 2):toEqual(true)
			T.expect(queue.MaxWaitSeconds <= 30):toEqual(true)
			T.expect(required(queue, 30)):toEqual(queue.MinPlayers)
			T.expect(required(queue, 180)):toEqual(queue.MinPlayers)
			T.expect(required(queue, 3600)):toEqual(queue.MinPlayers)
		end
	end)

	T.it("preserves Arena's existing population schedule", function()
		local queue = Queues.get("Arena")
		for index, seconds in { 0, 8, 16, 24, 30 } do
			T.expect(required(queue, seconds)):toEqual(({ 20, 16, 12, 8, 2 })[index])
		end
	end)

	T.it("reaches the viable minimum even if the ladder never relaxes that far", function()
		local incomplete = { { AfterSeconds = 0, MinimumPlayers = 30 }, { AfterSeconds = 10, MinimumPlayers = 20 } }
		T.expect(PopulationPolicy.requiredPlayers(incomplete, 29.999, 30, 2, 30)):toEqual(20)
		T.expect(PopulationPolicy.requiredPlayers(incomplete, 30, 30, 2, 30)):toEqual(2)
		T.expect(PopulationPolicy.requiredPlayers({}, 180, 30, 2, 30)):toEqual(2)
	end)

	T.it("never relaxes below the playable floor or above capacity", function()
		T.expect(PopulationPolicy.requiredPlayers({ { AfterSeconds = 0, MinimumPlayers = 50 } }, 0, 20, 2, 30))
			:toEqual(20)
		T.expect(PopulationPolicy.requiredPlayers({ { AfterSeconds = 0, MinimumPlayers = 0 } }, 0, 20, 2, 30))
			:toEqual(2)
		T.expect(PopulationPolicy.requiredPlayers({}, 30, 20, 4, 30)):toEqual(4)
		for _, queueId in Queues.Order do
			local queue = Queues.get(queueId)
			local previous = queue.MatchCapacity
			for seconds = 0, 180 do
				local players = required(queue, seconds)
				T.expect(players >= queue.MinPlayers and players <= previous):toEqual(true)
				previous = players
			end
		end
	end)
end)

return true
