--!strict

local GameMode = require(script.Parent.GameMode)

local TDM = {}
TDM.id = "TDM"
TDM.displayName = "Team Deathmatch"
TDM.scoreScope = "Team"
TDM.teams = { "Red", "Blue" }
TDM.rules = {
	MinPlayers = 2,
	ScoreTarget = 40,
	TimeCapSeconds = 360,
	ResultsSeconds = 8,
	RespawnSeconds = 3,
	WaveRespawnSeconds = 4.5,
	SpawnInvulnSeconds = 1.5,
} :: GameMode.MatchRules

function TDM.onMatchStart(ctx: GameMode.ModeContext)
	local points = {}
	for _, teamId in TDM.teams do
		for _, point in ctx.map.ballSpawnsByTeam[teamId] or {} do
			table.insert(points, point)
		end
	end
	if #points == 0 then
		points = ctx.map.ballSpawns
	end
	ctx.balls.startGroundSpawns(points)
end

function TDM.onPlayerSpawned(_ctx: GameMode.ModeContext, _player: Player, _isFirstSpawn: boolean) end

function TDM.onElim(_ctx: GameMode.ModeContext, _sourceId: string?, _targetId: string?) end

function TDM.onMatchEnd(ctx: GameMode.ModeContext)
	ctx.balls.stopGroundSpawns()
end

return (TDM :: any) :: GameMode.GameMode
