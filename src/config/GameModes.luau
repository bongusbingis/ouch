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
		Enabled = false,
		Title = "INFECTION",
		Description = "",
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

return table.freeze({
	VoteDurationSeconds = 10,
	Modes = table.freeze(modes),
	VoteOptions = table.freeze(voteOptions),
})
