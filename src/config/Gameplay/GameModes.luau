--!strict

-- Description is static merchandising copy and so never names a score target:
-- the target scales with the roster (Config.Gameplay.Modes), and the ballot
-- prints the number this lobby would actually play to from the vote snapshot.
--
-- ThumbnailId is empty until a mode's key art is authored and uploaded. Empty is
-- the understood "no art" sentinel on both read paths (GameModeCard draws its
-- per-mode placeholder instead, ArenaLoadingClient skips the image), which a
-- stand-in asset id was not: it asked for a missing asset on every ballot render.
local modes = {
	FFA = {
		Enabled = true,
		Title = "FREE-FOR-ALL",
		Description = "Race to the elimination target. Everyone is a target.",
		ThumbnailId = "",
		SortOrder = 1,
	},
	TDM = {
		Enabled = true,
		Title = "TEAM DEATHMATCH",
		Description = "Race your team to the elimination target. Work together to win.",
		ThumbnailId = "",
		SortOrder = 2,
	},
	Infection = {
		Enabled = false,
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
	MatchCapacity = 20,
	NativeRespawnRetrySeconds = 5,
	VoteDurationSeconds = 10,
	OpponentGraceSeconds = 8,
	Modes = table.freeze(modes),
	VoteOptions = table.freeze(voteOptions),
}
