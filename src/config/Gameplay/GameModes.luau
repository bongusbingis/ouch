--!strict

local Queues = require(script.Parent.Queues)

-- Description is static merchandising copy and so never names a score target:
-- the target scales with the roster (Config.Gameplay.Modes), and the ballot
-- prints the number this lobby would actually play to from the vote snapshot.
--
-- ThumbnailId is empty until a mode's key art is authored and uploaded. Empty is
-- the understood "no art" sentinel on both read paths (GameModeCard draws its
-- per-mode placeholder instead, ArenaLoadingClient skips the image), which a
-- stand-in asset id was not: it asked for a missing asset on every ballot render.
--
-- Queue names the matchmaking queue a mode is played from; only Arena modes
-- appear on the arena ballot. Combat = false switches off weapons, combat input
-- and the combat HUD for the mode. ScoreLabel is the unit of the mode's score
-- (team rows and per-player standings); team-scope podium plates show each
-- player's eliminations and so always print ELIMS. Spawn says where characters
-- are placed: the authored arena spawns, or the active Splashdown course.
local modes = {
	FFA = {
		Enabled = true,
		Title = "FREE-FOR-ALL",
		Description = "Race to the elimination target. Everyone is a target.",
		ThumbnailId = "",
		SortOrder = 1,
		Queue = "Arena",
		Combat = true,
		ScoreLabel = "ELIMS",
		Spawn = "Arena",
	},
	TDM = {
		Enabled = true,
		Title = "TEAM DEATHMATCH",
		Description = "Race your team to the elimination target. Work together to win.",
		ThumbnailId = "",
		SortOrder = 2,
		Queue = "Arena",
		Combat = true,
		ScoreLabel = "ELIMS",
		Spawn = "Arena",
	},
	Infection = {
		Enabled = true,
		Title = "INFECTION",
		Description = "One player starts infected. Survive to the clock, or join them.",
		ThumbnailId = "",
		SortOrder = 3,
		Queue = "Arena",
		Combat = true,
		ScoreLabel = "PLAYERS",
		Spawn = "Arena",
	},
	Splashdown = {
		Enabled = true,
		Title = "SPLASHDOWN",
		Description = "Race to the finish through three obstacle courses. Fall in the lava and you restart at your last checkpoint.",
		ThumbnailId = "",
		SortOrder = 4,
		Queue = "Splashdown",
		Combat = false,
		ScoreLabel = "POINTS",
		Spawn = "Course",
	},
}

local voteOptions = {}
for modeId, definition in modes do
	table.freeze(definition)
	if definition.Enabled and definition.Queue == "Arena" then
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
local GameModes = {
	MatchCapacity = 20,
	NativeRespawnRetrySeconds = 5,
	VoteDurationSeconds = 10,
	OpponentGraceSeconds = 8,
	Modes = table.freeze(modes),
	VoteOptions = table.freeze(voteOptions),
}

function GameModes.ModeQueue(modeId: any): string?
	local definition = if typeof(modeId) == "string" then modes[modeId] else nil
	return if definition then definition.Queue else nil
end

function GameModes.QueueCapacity(queueId: any): number
	local queue = if typeof(queueId) == "string" then Queues.Queues[queueId] else nil
	return if queue then queue.MatchCapacity else GameModes.MatchCapacity
end

function GameModes.IsCombat(modeId: any): boolean
	local definition = if typeof(modeId) == "string" then modes[modeId] else nil
	return definition == nil or definition.Combat ~= false
end

function GameModes.ScoreLabel(modeId: any): string
	local definition = if typeof(modeId) == "string" then modes[modeId] else nil
	return if definition then definition.ScoreLabel else "ELIMS"
end

return GameModes
