-- Description: Infection game mode: picks patient zero, converts eliminated survivors to the infected side instead of scoring, scores both sides by headcount, and hands the win to the survivors if the clock runs out.

--!strict

local ReplicatedStorage = script.Parent.Parent.Parent.Parent
local GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("GameModes"))
local PostMatch = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("PostMatch"))
local Modes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Modes"))
local GameMode = require(script.Parent.GameMode)

local Infection = {}

Infection.id = "Infection"
Infection.displayName = "Infection"
Infection.scoreScope = "Team"
Infection.SurvivorTeam = "Survivors"
Infection.InfectedTeam = "Infected"
Infection.teams = { Infection.SurvivorTeam, Infection.InfectedTeam }

function Infection.resolveRules(): GameMode.MatchRules
	local m = Modes.Infection
	return {
		MinPlayers = m.MinPlayers,
		ScoreTarget = m.ScoreTarget,
		TimeCapSeconds = m.TimeCapSeconds,
		ResultsSeconds = PostMatch.ResultsSeconds,
		IntermissionSeconds = GameModes.VoteDurationSeconds,
		StartingSeconds = m.StartingSeconds,
		RespawnSeconds = m.RespawnSeconds,
		SpawnInvulnSeconds = m.SpawnInvulnSeconds,
		TimeCapWinnerId = Infection.SurvivorTeam,
		PreserveDodgeballs = m.PreserveDodgeballs,
	}
end

Infection.rules = Infection.resolveRules()

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

-- Both sides score their own headcount, so the scoreboard reads as the thing the
-- mode is actually about -- how many are left -- rather than a kill tally that
-- climbs every time a survivor knocks an infected player down for three seconds.
-- MatchService recomputes this whenever the roster or anyone's team changes.
function Infection.teamScore(ctx: GameMode.ModeContext, teamId: string): number
	local count = 0
	for _, player in ctx.getPlayers() do
		if ctx.getPlayerTeam(player) == teamId then
			count += 1
		end
	end
	return count
end

-- Split out from onMatchStart with the chooser passed in, the same way
-- pickPatientZero takes one: side assignment is the part worth pinning down, and
-- it cannot be if reaching it means going through a live Random.
function Infection.assignSides(ctx: GameMode.ModeContext, chooseIndex: (number) -> number)
	local players = ctx.getPlayers()
	local patientZero = Infection.pickPatientZero(#players, chooseIndex)

	for index, player in players do
		local infected = index == patientZero
		ctx.setPlayerTeam(player, if infected then Infection.InfectedTeam else Infection.SurvivorTeam)
		-- Patient zero is armed like everyone else. Opening the round with the one
		-- player who has to start the chain holding nothing but a seven-stud hammer
		-- left the first half-minute with nothing happening in it.
		ctx.balls.grantHeldBall(player)
	end
end

function Infection.onMatchStart(ctx: GameMode.ModeContext)
	Infection.assignSides(ctx, randomIndex)
end

function Infection.onPlayerSpawned(ctx: GameMode.ModeContext, player: Player, isFirstSpawn: boolean)
	if isFirstSpawn and ctx.getPlayerTeam(player) == nil then
		ctx.setPlayerTeam(player, Infection.InfectedTeam)
	end
	ctx.balls.grantHeldBall(player)
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
