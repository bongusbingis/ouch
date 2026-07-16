--!strict

local GameMode = require(script.Parent.GameMode)

local TDM = {}
TDM.id = "TDM"
TDM.displayName = "Team Deathmatch"
TDM.scoreScope = "Team"
TDM.teams = { "Red", "Blue" }
TDM.rules = {
	MinPlayers = 1,
	ScoreTarget = 40,
	TimeCapSeconds = 360,
	ResultsSeconds = 8,
	IntermissionSeconds = 15,
	RespawnSeconds = 3,
	WaveRespawnSeconds = 4.5,
	SpawnInvulnSeconds = 1.5,
} :: GameMode.MatchRules

-- Every player starts holding a ball (and late joiners get one on their
-- first spawn), so per-team ball counts always match team sizes — no ground
-- spawns to contest.
function TDM.onMatchStart(ctx: GameMode.ModeContext)
	for _, player in ctx.getPlayers() do
		ctx.balls.grantHeldBall(player)
	end
end

function TDM.onPlayerSpawned(ctx: GameMode.ModeContext, player: Player, isFirstSpawn: boolean)
	if isFirstSpawn then
		ctx.balls.grantHeldBall(player)
	end
end

function TDM.onElim(_ctx: GameMode.ModeContext, _sourceId: string?, _targetId: string?) end

function TDM.onMatchEnd(_ctx: GameMode.ModeContext) end

return (TDM :: any) :: GameMode.GameMode
