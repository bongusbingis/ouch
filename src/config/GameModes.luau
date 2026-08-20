--!strict

local modes = {
	FFA = {
		Enabled = true,
		Title = "FREE-FOR-ALL",
		Description = "First to 15 eliminations wins. Outlast other players to win.",
		ThumbnailId = "",
		SortOrder = 1,
	},
	TDM = {
		Enabled = true,
		Title = "TEAM DEATHMATCH",
		Description = "First team to 40 eliminations wins. Work together to win.",
		ThumbnailId = "",
		SortOrder = 2,
	},
	Infection = {
		Enabled = true,
		Title = "INFECTION",
		Description = "One player starts infected. Survive to the clock, or join them.",
		ThumbnailId = "",
		SortOrder = 3,
	},
}

local voteOptions = {}
for modeId, definition in modes do
	table.freeze(definition)
	if definition.Enabled then
		table.insert(voteOptions, modeId)
	end
end
table.sort(voteOptions, function(first, second)
	return modes[first].SortOrder < modes[second].SortOrder
end)

-- The outer table stays unfrozen so Config.LiveConfig may override
-- VoteDurationSeconds at runtime. Modes and VoteOptions are frozen because
-- VoteOptions is derived from Modes at load and is copied by the lobby, so
-- neither can be changed live without the two drifting apart.
return {
	VoteDurationSeconds = 10,
	-- Longest the ballot is held back waiting for arriving clients to report their
	-- UI ready. A client that never reports never blocks a match past this.
	ClientReadyWaitSeconds = 10,
	Modes = table.freeze(modes),
	VoteOptions = table.freeze(voteOptions),
}
