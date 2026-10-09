--!strict

-- Matchmaking queues. Each queue is its own MemoryStore queue and worker lease
-- in the lobby, and decides how the arena picks its mode: a ballot over
-- GameModes.VoteOptions, or one fixed mode. MatchCapacity is the roster a match
-- fills to; the population ladder relaxes from it as the oldest viable ticket
-- waits. MaxWaitSeconds caps waiting for a larger roster: after that, any
-- roster at or above MinPlayers can start. Reservation/teleport time is extra.
local queues = {
	Arena = {
		Enabled = true,
		Title = "ARENA PVP",
		Description = "Dodgeball and hammer brawls. Vote free-for-all, team deathmatch or Infection, then a map.",
		SortOrder = 1,
		MatchCapacity = 20,
		MinPlayers = 2,
		MaxWaitSeconds = 30,
		PopulationExpansion = {
			{ AfterSeconds = 0, MinimumPlayers = 20 },
			{ AfterSeconds = 8, MinimumPlayers = 16 },
			{ AfterSeconds = 16, MinimumPlayers = 12 },
			{ AfterSeconds = 24, MinimumPlayers = 8 },
			{ AfterSeconds = 30, MinimumPlayers = 2 },
		},
		ModeSelection = { Strategy = "Vote" },
	},
	Splashdown = {
		Enabled = true,
		Title = "SPLASHDOWN",
		Description = "Race three obstacle courses. Fastest to the finish wins.",
		SortOrder = 2,
		MatchCapacity = 30,
		MinPlayers = 1,
		MaxWaitSeconds = 30,
		-- Give busy queues a short chance to fill, then favor getting the
		-- waiting racers into a game. Two racers can play all three rounds.
		PopulationExpansion = {
			{ AfterSeconds = 0, MinimumPlayers = 30 },
			{ AfterSeconds = 5, MinimumPlayers = 20 },
			{ AfterSeconds = 10, MinimumPlayers = 12 },
			{ AfterSeconds = 15, MinimumPlayers = 8 },
			{ AfterSeconds = 20, MinimumPlayers = 4 },
			{ AfterSeconds = 30, MinimumPlayers = 1 },
		},
		ModeSelection = { Strategy = "Fixed", ModeId = "Splashdown" },
	},
}

local order = {}
for queueId, definition in queues do
	table.freeze(definition.PopulationExpansion)
	table.freeze(definition.ModeSelection)
	table.freeze(definition)
	if definition.Enabled then
		table.insert(order, queueId)
	end
end
table.sort(order, function(first, second)
	return queues[first].SortOrder < queues[second].SortOrder
end)

local Queues = {
	DefaultQueueId = "Arena",
	Queues = table.freeze(queues),
	Order = table.freeze(order),
}

function Queues.isEnabled(queueId: any): boolean
	local definition = if typeof(queueId) == "string" then queues[queueId] else nil
	return definition ~= nil and definition.Enabled == true
end

function Queues.get(queueId: string)
	return queues[queueId]
end

return table.freeze(Queues)
