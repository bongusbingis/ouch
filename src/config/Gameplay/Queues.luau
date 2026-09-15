--!strict

-- Matchmaking queues. Each queue is its own MemoryStore queue and worker lease
-- in the lobby, and decides how the arena picks its mode: a ballot over
-- GameModes.VoteOptions, or one fixed mode. MatchCapacity is the roster a match
-- fills to; the population ladder relaxes from it as the oldest ticket waits,
-- in the same shape as the arena ladder that shipped first.
local queues = {
	Arena = {
		Enabled = true,
		Title = "ARENA PVP",
		Description = "Dodgeball and hammer brawls. Vote free-for-all or team deathmatch.",
		SortOrder = 1,
		MatchCapacity = 20,
		MinPlayers = 2,
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
		MinPlayers = 2,
		-- The roster is 20 to 30 by decision: the ladder never relaxes below 20,
		-- so a queue with fewer waiting players keeps searching.
		PopulationExpansion = {
			{ AfterSeconds = 0, MinimumPlayers = 30 },
			{ AfterSeconds = 10, MinimumPlayers = 26 },
			{ AfterSeconds = 20, MinimumPlayers = 23 },
			{ AfterSeconds = 30, MinimumPlayers = 20 },
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
