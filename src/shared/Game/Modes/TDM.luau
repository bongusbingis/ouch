-- Name: TDM.luau
-- Author: Jack C.
-- Description: Team deathmatch game mode: its match rules and the server hooks that assign teams, provision balls, and score eliminations to the scorer's team.
-- Created: 2026-07-13

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
		ScoreTarget = m.ScoreTarget,
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

function TDM.onPlayerSpawned(ctx: GameMode.ModeContext, player: Player, isFirstSpawn: boolean)
	if isFirstSpawn then
		ctx.balls.grantHeldBall(player)
	end
end

function TDM.onElim(_ctx: GameMode.ModeContext, _sourceId: string?, _targetId: string?) end

function TDM.onMatchEnd(_ctx: GameMode.ModeContext) end

return (TDM :: any) :: GameMode.GameMode
