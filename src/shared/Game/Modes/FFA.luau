--!strict

local GameMode = require(script.Parent.GameMode)

-- Classic FFA: balls spawn on the ground at the map's BallSpawns points.

local FFA = {}
FFA.id = "FFA"
FFA.displayName = "Free For All"
FFA.rules = {
	MinPlayers = 2,
	ScoreTarget = 15,
	TimeCapSeconds = 300,
	ResultsSeconds = 8,
	IntermissionSeconds = 15,
	RespawnSeconds = 3,
	SpawnInvulnSeconds = 1.5,
} :: GameMode.MatchRules

function FFA.onMatchStart(ctx: GameMode.ModeContext)
	ctx.balls.startGroundSpawns(ctx.map.ballSpawns)
end

function FFA.onPlayerSpawned(_ctx: GameMode.ModeContext, _player: Player, _isFirstSpawn: boolean) end

function FFA.onElim(_ctx: GameMode.ModeContext, _sourceId: string?, _targetId: string?) end

function FFA.onMatchEnd(ctx: GameMode.ModeContext)
	ctx.balls.stopGroundSpawns()
end

return (FFA :: any) :: GameMode.GameMode
