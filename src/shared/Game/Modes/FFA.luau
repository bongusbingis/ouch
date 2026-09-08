-- Description: Free-for-all game mode: its match rules and the server hooks that provision a ball per entrant and score every elimination individually.

--!strict

local ReplicatedStorage = script.Parent.Parent.Parent.Parent
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local PostMatch = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("PostMatch"))
local Modes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Modes"))
local GameMode = require(script.Parent.GameMode)

local FFA = {}
FFA.id = "FFA"
FFA.displayName = "Free For All"

function FFA.resolveRules(): GameMode.MatchRules
	local m = Modes.FFA
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

FFA.rules = FFA.resolveRules()

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
