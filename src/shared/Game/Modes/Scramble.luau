--!strict

local GameMode = require(script.Parent.GameMode)

-- Everyone starts holding one ball; no world spawns. Once thrown, a ball must
-- be picked back up (or stolen after someone else's throw). Respawning after
-- a death grants nothing, so the ball count in play stays fixed.

local Scramble = {}
Scramble.id = "Scramble"
Scramble.displayName = "Scramble"
Scramble.rules = {
	MinPlayers = 2,
	ScoreTarget = 15,
	TimeCapSeconds = 300,
	ResultsSeconds = 8,
	IntermissionSeconds = 15,
	RespawnSeconds = 1,
	SpawnInvulnSeconds = 1.5,
} :: GameMode.MatchRules

function Scramble.onMatchStart(ctx: GameMode.ModeContext)
	for _, player in ctx.getPlayers() do
		ctx.balls.grantHeldBall(player)
	end
end

function Scramble.onPlayerSpawned(ctx: GameMode.ModeContext, player: Player, isFirstSpawn: boolean)
	if isFirstSpawn then
		ctx.balls.grantHeldBall(player)
	end
end

function Scramble.onElim(_ctx: GameMode.ModeContext, _sourceId: string?, _targetId: string?) end

function Scramble.onMatchEnd(_ctx: GameMode.ModeContext) end

return (Scramble :: any) :: GameMode.GameMode
