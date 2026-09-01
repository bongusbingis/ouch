-- Name: Infection.luau
-- Author: Jack C.
-- Description: Infection game mode: picks patient zero, converts eliminated survivors to the infected side instead of scoring, and hands the win to the survivors if the clock runs out.
-- Created: 2026-08-19

--!strict

local ReplicatedStorage = script.Parent.Parent.Parent.Parent
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModes"))
local PostMatch = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PostMatch"))
local GameMode = require(script.Parent.GameMode)

local Infection = {}

Infection.id = "Infection"
Infection.displayName = "Infection"
Infection.scoreScope = "Team"
Infection.SurvivorTeam = "Survivors"
Infection.InfectedTeam = "Infected"
Infection.teams = { Infection.SurvivorTeam, Infection.InfectedTeam }
Infection.rules = {
	MinPlayers = 2,
	ScoreTarget = math.huge,
	TimeCapSeconds = 180,
	ResultsSeconds = PostMatch.ResultsSeconds,
	IntermissionSeconds = GameModes.VoteDurationSeconds,
	StartingSeconds = 3,
	RespawnSeconds = 3,
	SpawnInvulnSeconds = 1.5,
	TimeCapWinnerId = Infection.SurvivorTeam,
	PreserveDodgeballs = true,
} :: GameMode.MatchRules

function Infection.countSurvivors(teamIds: { string? }): number
	local survivors = 0
	for _, teamId in teamIds do
		if teamId == Infection.SurvivorTeam then
			survivors += 1
		end
	end
	return survivors
end

function Infection.pickPatientZero(playerCount: number, chooseIndex: (number) -> number): number?
	if playerCount < 2 then
		return nil
	end
	local index = chooseIndex(playerCount)
	assert(
		index % 1 == 0 and index >= 1 and index <= playerCount,
		"[Infection] patient zero chooser returned an invalid index"
	)
	return index
end

function Infection.isConversion(sourceTeam: string?, targetTeam: string?): boolean
	return sourceTeam == Infection.InfectedTeam and targetTeam == Infection.SurvivorTeam
end

local random: Random? = nil

local function randomIndex(count: number): number
	local generator = random
	if generator == nil then
		generator = Random.new()
		random = generator
	end
	return generator:NextInteger(1, count)
end

local function teamsOf(ctx: GameMode.ModeContext): { string? }
	local teamIds = {}
	for _, player in ctx.getPlayers() do
		table.insert(teamIds, ctx.getPlayerTeam(player))
	end
	return teamIds
end

function Infection.onMatchStart(ctx: GameMode.ModeContext)
	local players = ctx.getPlayers()
	local patientZero = Infection.pickPatientZero(#players, randomIndex)

	for index, player in players do
		local infected = index == patientZero
		ctx.setPlayerTeam(player, if infected then Infection.InfectedTeam else Infection.SurvivorTeam)
		if not infected then
			ctx.balls.grantHeldBall(player)
		end
	end
end

function Infection.onPlayerSpawned(ctx: GameMode.ModeContext, player: Player, isFirstSpawn: boolean)
	if isFirstSpawn and ctx.getPlayerTeam(player) == nil then
		ctx.setPlayerTeam(player, Infection.InfectedTeam)
		return
	end
	if isFirstSpawn and ctx.getPlayerTeam(player) == Infection.SurvivorTeam then
		ctx.balls.grantHeldBall(player)
	end
end

function Infection.onElim(ctx: GameMode.ModeContext, sourceId: string?, targetId: string?)
	if sourceId == nil or targetId == nil then
		return
	end
	local source = ctx.getPlayerById(sourceId)
	local target = ctx.getPlayerById(targetId)
	if source == nil or target == nil then
		return
	end
	if not Infection.isConversion(ctx.getPlayerTeam(source), ctx.getPlayerTeam(target)) then
		return
	end

	ctx.setPlayerTeam(target, Infection.InfectedTeam)

	if Infection.countSurvivors(teamsOf(ctx)) == 0 then
		ctx.finishMatch(Infection.InfectedTeam, "Infected")
	end
end

function Infection.onMatchEnd(_ctx: GameMode.ModeContext) end

return (Infection :: any) :: GameMode.GameMode
