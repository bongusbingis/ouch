-- Description: Team deathmatch game mode: its match rules and the server hooks that assign teams, provision balls, and score eliminations to the scorer's team.

--!strict

local ReplicatedStorage = script.Parent.Parent.Parent.Parent
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local PostMatch = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("PostMatch"))
local Modes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Modes"))
local GameMode = require(script.Parent.GameMode)

local TDM = {}
TDM.id = "TDM"
TDM.displayName = "Team Deathmatch"
TDM.scoreScope = "Team"
TDM.teams = { "Red", "Blue" }

function TDM.resolveRules(): GameMode.MatchRules
	local m = Modes.TDM
	return {
		MinPlayers = m.MinPlayers,
		MinParties = m.MinParties,
		ScoreTarget = m.ScoreTarget,
		ReferencePlayers = m.ReferencePlayers,
		MinScoreTarget = m.MinScoreTarget,
		MaxScoreTarget = m.MaxScoreTarget,
		TimeCapSeconds = m.TimeCapSeconds,
		ResultsSeconds = PostMatch.ResultsSeconds,
		IntermissionSeconds = GameModes.VoteDurationSeconds,
		StartingSeconds = m.StartingSeconds,
		RespawnSeconds = m.RespawnSeconds,
		WaveRespawnSeconds = m.WaveRespawnSeconds,
		SpawnInvulnSeconds = m.SpawnInvulnSeconds,
		PreserveDodgeballs = m.PreserveDodgeballs,
	}
end

TDM.rules = TDM.resolveRules()

function TDM.onMatchStart(ctx: GameMode.ModeContext)
	for _, player in ctx.getPlayers() do
		ctx.balls.grantHeldBall(player)
	end
end

-- Every spawn, not only the first: wave respawns return a whole squad at once,
-- and a squad that arrives with nothing to throw cannot contest the push it was
-- respawned for.
function TDM.onPlayerSpawned(ctx: GameMode.ModeContext, player: Player, _isFirstSpawn: boolean)
	ctx.balls.grantHeldBall(player)
end

function TDM.onElim(_ctx: GameMode.ModeContext, _sourceId: string?, _targetId: string?) end

function TDM.onMatchEnd(_ctx: GameMode.ModeContext) end

return (TDM :: any) :: GameMode.GameMode
