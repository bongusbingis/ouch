--!strict

local ReplicatedStorage = script.Parent.Parent.Parent.Parent
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModes"))
local GameMode = require(script.Parent.GameMode)

-- Infection. One player starts infected; every survivor an infected eliminates
-- joins them. Infected win the moment the last survivor falls, survivors win if
-- any are still standing when the clock runs out.
--
-- The asymmetry is carried entirely by ball possession rather than new weapon
-- code: survivors hold a ball so a Throw press routes to the dodgeball, and
-- infected never receive one so the same press routes to the hammer. That is
-- the existing WeaponRegistry ordering, not a special case.
--
-- Survivors can knock an infected down but never reduce their number: an
-- eliminated infected respawns infected. Only one direction is permanent, which
-- is what makes the mode a countdown rather than a deathmatch.

local Infection = {}

Infection.id = "Infection"
Infection.displayName = "Infection"
Infection.scoreScope = "Team"
Infection.SurvivorTeam = "Survivors"
Infection.InfectedTeam = "Infected"
Infection.teams = { Infection.SurvivorTeam, Infection.InfectedTeam }
Infection.rules = {
	MinPlayers = 2,
	-- Not a score race; the mode ends on total conversion or the clock. Kept
	-- above any reachable conversion count so it never ends the match itself.
	ScoreTarget = math.huge,
	TimeCapSeconds = 180,
	ResultsSeconds = 8,
	IntermissionSeconds = GameModes.VoteDurationSeconds,
	StartingSeconds = 3,
	RespawnSeconds = 3,
	SpawnInvulnSeconds = 1.5,
	TimeCapWinnerId = Infection.SurvivorTeam,
	PreserveDodgeballs = true,
} :: GameMode.MatchRules

-- Pure rules, kept out of the hooks so they are testable without a DataModel.

function Infection.countSurvivors(teamIds: { string? }): number
	local survivors = 0
	for _, teamId in teamIds do
		if teamId == Infection.SurvivorTeam then
			survivors += 1
		end
	end
	return survivors
end

-- Index of the player who starts infected. Takes the chooser so a test can pin
-- the pick, matching how ModeVote resolves ties.
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

-- Server hooks.

-- Created on first use rather than at module scope: modes are required by the
-- headless specs, which have no engine globals.
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

-- Late joiners arrive as infected: dropping a fresh survivor into a match the
-- infection is already winning would hand the survivors a free extra life.
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

	-- The dropped ball is released by the sim when its holder dies, so a
	-- converted survivor arrives on the infected side unarmed.
	ctx.setPlayerTeam(target, Infection.InfectedTeam)

	if Infection.countSurvivors(teamsOf(ctx)) == 0 then
		ctx.finishMatch(Infection.InfectedTeam, "Infected")
	end
end

function Infection.onMatchEnd(_ctx: GameMode.ModeContext) end

return (Infection :: any) :: GameMode.GameMode
