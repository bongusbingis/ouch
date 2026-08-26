-- Name: FFA.luau
-- Author: Jack C.
-- Description: Free-for-all game mode: its match rules and the server hooks that provision a ball per entrant and score every elimination individually.
-- Created: 2026-07-13

--!strict

local ReplicatedStorage = script.Parent.Parent.Parent.Parent
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModes"))
local GameMode = require(script.Parent.GameMode)

local FFA = {}
FFA.id = "FFA"
FFA.displayName = "Free For All"
FFA.rules = {
	MinPlayers = 1,
	ScoreTarget = 15,
	TimeCapSeconds = 300,
	ResultsSeconds = 8,
	IntermissionSeconds = GameModes.VoteDurationSeconds,
	StartingSeconds = 3,
	RespawnSeconds = 1,
	SpawnInvulnSeconds = 1.5,
	PreserveDodgeballs = true,
} :: GameMode.MatchRules

function FFA.onMatchStart(ctx: GameMode.ModeContext)
	for _, player in ctx.getPlayers() do
		ctx.balls.grantHeldBall(player)
	end
end

function FFA.onPlayerSpawned(ctx: GameMode.ModeContext, player: Player, isFirstSpawn: boolean)
	if isFirstSpawn then
		ctx.balls.grantHeldBall(player)
	end
end

function FFA.onElim(_ctx: GameMode.ModeContext, _sourceId: string?, _targetId: string?) end

function FFA.onMatchEnd(_ctx: GameMode.ModeContext) end

return (FFA :: any) :: GameMode.GameMode
