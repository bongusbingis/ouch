-- Name: Splashdown.luau
-- Author: Jack C.
-- Description: Splashdown race game mode: its outer-match rules and labels, with no-op lifecycle hooks because the arena's SplashdownService owns the rounds, checkpoints and points through MatchService's server seams.
-- Created: 2026-09-14

--!strict

local ReplicatedStorage = script.Parent.Parent.Parent.Parent
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local PostMatch = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("PostMatch"))
local Modes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Modes"))
local GameMode = require(script.Parent.GameMode)

local Splashdown = {}
Splashdown.id = "Splashdown"
Splashdown.displayName = "Splashdown"

function Splashdown.resolveRules(): GameMode.MatchRules
	local m = Modes.Splashdown
	return {
		MinPlayers = m.MinPlayers,
		ScoreTarget = m.ScoreTarget,
		TimeCapSeconds = m.TimeCapSeconds,
		ResultsSeconds = PostMatch.ResultsSeconds,
		IntermissionSeconds = GameModes.VoteDurationSeconds,
		StartingSeconds = m.StartingSeconds,
		RespawnSeconds = m.RespawnSeconds,
		SpawnInvulnSeconds = m.SpawnInvulnSeconds,
		PreserveDodgeballs = m.PreserveDodgeballs,
	}
end

Splashdown.rules = Splashdown.resolveRules()

Splashdown.statLabels = {
	{ id = "BestFinish", label = "BEST FINISH" },
	{ id = "TotalTime", label = "TOTAL TIME (SEC)" },
	{ id = "Splashdowns", label = "SPLASHDOWNS" },
}

function Splashdown.onMatchStart(_ctx: GameMode.ModeContext) end

function Splashdown.onPlayerSpawned(_ctx: GameMode.ModeContext, _player: Player, _isFirstSpawn: boolean) end

function Splashdown.onElim(_ctx: GameMode.ModeContext, _sourceId: string?, _targetId: string?) end

function Splashdown.onMatchEnd(_ctx: GameMode.ModeContext) end

return (Splashdown :: any) :: GameMode.GameMode
