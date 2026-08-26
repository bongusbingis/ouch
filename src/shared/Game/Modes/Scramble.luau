-- Name: Scramble.luau
-- Author: Jack C.
-- Description: Scramble game mode: its match rules and the server hooks for its ball provisioning, spawning, and scoring behavior.
-- Created: 2026-07-13

--!strict

local GameMode = require(script.Parent.GameMode)

local Scramble = {}
Scramble.id = "Scramble"
Scramble.displayName = "Scramble"
Scramble.rules = {
	MinPlayers = 1,
	ScoreTarget = 15,
	TimeCapSeconds = 300,
	ResultsSeconds = 8,
	IntermissionSeconds = 15,
	StartingSeconds = 3,
	RespawnSeconds = 1,
	SpawnInvulnSeconds = 1.5,
	PreserveDodgeballs = true,
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
