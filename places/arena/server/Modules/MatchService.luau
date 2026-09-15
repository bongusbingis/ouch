-- Description: Drives the match lifecycle from the selected mode's rules: assigns teams, provisions balls, applies elimination consequences and scoring, schedules respawns, publishes the replicated match state, and orchestrates results and reset.

--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local Config = ReplicatedStorage:WaitForChild("Config")
local Combat = require(Config:WaitForChild("Gameplay"):WaitForChild("Combat"))
local GameModes = require(Config:WaitForChild("Gameplay"):WaitForChild("GameModes"))
local PostMatchConfig = require(Config:WaitForChild("Interface"):WaitForChild("PostMatch"))
local MatchSim = require(Game:WaitForChild("Sim"):WaitForChild("MatchSim"))
local GameMode = require(Game:WaitForChild("Modes"):WaitForChild("GameMode"))
local ModeRegistry = require(Game:WaitForChild("Modes"):WaitForChild("ModeRegistry"))
local ModeOptions = require(Game:WaitForChild("Modes"):WaitForChild("ModeOptions"))
local ModeAvailability = require(Game:WaitForChild("Modes"):WaitForChild("ModeAvailability"))
local ScoreTarget = require(Game:WaitForChild("Modes"):WaitForChild("ScoreTarget"))
local PartyTeamAllocator = require(Game:WaitForChild("Modes"):WaitForChild("PartyTeamAllocator"))
local PlayerIds = require(Game:WaitForChild("Adapters"):WaitForChild("PlayerIds"))
local PostMatchResult = require(Game:WaitForChild("PostMatch"):WaitForChild("PostMatchResult"))
local DevSoloPlay = require(Game:WaitForChild("Matchmaking"):WaitForChild("DevSoloPlay"))
local Network = require(Shared:WaitForChild("Network"))

local ArenaService = require(script.Parent.ArenaService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local BallService = require(script.Parent.BallService)
local EliminationService = require(script.Parent.EliminationService)
local SpawnRouter = require(script.Parent.SpawnRouter)

local PlayerData = require(script.Parent.PlayerData)

local MatchService = {}

local STATE_FOLDER_NAME = "MatchState"

local state = MatchSim.newState()
local mode: GameMode.GameMode? = nil

local listeners: { (event: { [string]: any }) -> () } = {}
local stateFolder: Folder? = nil
local spawnedThisMatch: { [string]: boolean } = {}
local respawnGeneration: { [string]: number } = {}
local spawnProtectionGeneration: { [Model]: number } = {}
local playerMatchElims: { [string]: number } = {}
local pendingWaveRespawns: { [string]: Player } = {}
local partyTeamAssignments: { [string]: string } = {}
local waveTimer = 0
local externalEventSequence = 0
local started = false
local startingMatch = false
local watchedPlayers: { [number]: RBXScriptConnection } = {}
local nativeDeathConnections: { [number]: RBXScriptConnection } = {}
local lastResult: PostMatchResult.GlobalResult? = nil
local resultRosterByUserId: { [number]: PostMatchResult.Contestant } = {}
local contestantStatsByUserId: { [number]: { [string]: number } } = {}
local opponentDeadline: number? = nil
local refreshPopulation: () -> ()

function MatchService.onEvent(listener: (event: { [string]: any }) -> ())
	table.insert(listeners, listener)
end

function MatchService.phase(): MatchSim.MatchPhase
	return state.phase
end

local function dispatch(event: { [string]: any })
	for _, listener in listeners do
		local ok, err = pcall(listener, event)
		if not ok then
			warn(`[MatchService] listener error: {err}`)
		end
	end
end

local function ensureStateFolder(): Folder
	if stateFolder then
		return stateFolder
	end
	local created = Instance.new("Folder")
	created.Name = STATE_FOLDER_NAME
	created:SetAttribute("phase", state.phase)
	created:SetAttribute("timeRemaining", 0)
	created:SetAttribute("winnerId", "")
	created:SetAttribute("modeId", "")
	created.Parent = ReplicatedStorage
	stateFolder = created
	return created
end

local function setStateAttribute(name: string, value: any)
	local target = ensureStateFolder()
	if target:GetAttribute(name) ~= value then
		target:SetAttribute(name, value)
	end
end

local function scoreScope(): GameMode.ScoreScope
	return if mode then mode.scoreScope or "Player" else "Player"
end

local function teamIds(): { string }
	return if mode then mode.teams or {} else {}
end

local function isArenaJoinPhase(): boolean
	return startingMatch or state.phase == "Starting" or state.phase == "Active"
end

local function teamAttrName(teamId: string): string
	return `TeamScore_{teamId}`
end

local function playerTeam(player: Player): string?
	return player:GetAttribute("TeamId") :: string?
end

local function setPlayerTeam(player: Player, teamId: string?)
	player:SetAttribute("TeamId", teamId)
	local contestant = resultRosterByUserId[player.UserId]
	if contestant then
		contestant.teamId = teamId
	end
	local character = player.Character
	if character then
		character:SetAttribute("TeamId", teamId)
	end
end

local function rememberContestant(player: Player)
	resultRosterByUserId[player.UserId] = {
		playerId = PlayerIds.toId(player),
		userId = player.UserId,
		username = player.Name,
		displayName = player.DisplayName,
		teamId = playerTeam(player),
		colorId = player:GetAttribute("Equip_CharacterColor"),
		costumeId = player:GetAttribute("Equip_CostumeAssets"),
		emoteId = player:GetAttribute("EmoteSlot_1"),
		ballId = player:GetAttribute("Equip_BallAssets"),
		hammerId = player:GetAttribute("Equip_HammerAssets"),
		contribution = playerMatchElims[PlayerIds.toId(player)] or 0,
		stats = contestantStatsByUserId[player.UserId],
	}
end

local function matchPlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if ArenaSessionService.isRoundEligible(player) then
			table.insert(result, player)
		end
	end
	return result
end

local function buildResult(activeMode: GameMode.GameMode, event: { [string]: any })
	for _, player in Players:GetPlayers() do
		if resultRosterByUserId[player.UserId] then
			rememberContestant(player)
		end
	end
	local contestants = {}
	for _, contestant in resultRosterByUserId do
		table.insert(contestants, table.clone(contestant))
	end
	local now = Workspace:GetServerTimeNow()
	lastResult = PostMatchResult.build({
		resultId = HttpService:GenerateGUID(false),
		modeId = activeMode.id,
		modeName = activeMode.displayName,
		scoreScope = activeMode.scoreScope or "Player",
		scoreLabel = GameModes.ScoreLabel(activeMode.id),
		statLabels = activeMode.statLabels,
		winnerId = event.winnerId,
		reason = tostring(event.reason or "Complete"),
		interactiveAt = now + PostMatchConfig.RevealSeconds,
		endsAt = now + activeMode.rules.ResultsSeconds,
		contestants = contestants,
		scores = table.clone(state.scores),
		teamIds = activeMode.teams,
	})
end

local function clearTeams()
	for _, player in matchPlayers() do
		setPlayerTeam(player, nil)
	end
end

local function assignTeams()
	local teams = teamIds()
	table.clear(partyTeamAssignments)
	if #teams == 0 then
		clearTeams()
		return
	end

	local players = matchPlayers()
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	local entrants = {}
	for _, player in players do
		table.insert(entrants, {
			id = PlayerIds.toId(player),
			partyId = ArenaSessionService.partyIdFor(player),
		})
	end

	local assignments = PartyTeamAllocator.assign(entrants, teams)
	for _, player in players do
		local teamId = assert(assignments[PlayerIds.toId(player)], "[MatchService] every entrant must have a team")
		setPlayerTeam(player, teamId)
		local partyId = ArenaSessionService.partyIdFor(player)
		if partyId then
			partyTeamAssignments[partyId] = teamId
		end
	end
end

local function assignLateJoinTeam(player: Player)
	local teams = teamIds()
	if #teams == 0 then
		setPlayerTeam(player, nil)
		return
	end
	local partyId = ArenaSessionService.partyIdFor(player)
	local partyTeam = if partyId then partyTeamAssignments[partyId] else nil
	if partyTeam then
		setPlayerTeam(player, partyTeam)
		return
	end

	local counts: { [string]: number } = {}
	for _, teamId in teams do
		counts[teamId] = 0
	end
	for _, existing in matchPlayers() do
		if existing ~= player then
			local teamId = playerTeam(existing)
			if teamId and counts[teamId] ~= nil then
				counts[teamId] += 1
			end
		end
	end

	local bestTeam = teams[1]
	for _, teamId in teams do
		if counts[teamId] < counts[bestTeam] then
			bestTeam = teamId
		end
	end
	setPlayerTeam(player, bestTeam)
	if partyId then
		partyTeamAssignments[partyId] = bestTeam
	end
end

local function ensureLeaderstats(player: Player): IntValue
	local statsFolder = player:FindFirstChild("leaderstats")
	if statsFolder == nil then
		statsFolder = Instance.new("Folder")
		statsFolder.Name = "leaderstats"
		statsFolder.Parent = player
	end
	local elims = statsFolder:FindFirstChild("Elims")
	if elims == nil or not elims:IsA("IntValue") then
		elims = Instance.new("IntValue")
		elims.Name = "Elims"
		elims.Parent = statsFolder
	end
	return elims :: IntValue
end

local function setScore(player: Player, score: number)
	player:SetAttribute("MatchScore", score)
	ensureLeaderstats(player).Value = score
end

local function setTeamScore(teamId: string, score: number)
	setStateAttribute(teamAttrName(teamId), score)
end

local function resetAllScores()
	for _, player in matchPlayers() do
		local key = PlayerIds.toId(player)
		playerMatchElims[key] = 0
		setScore(player, if scoreScope() == "Team" then 0 else state.scores[key] or 0)
	end
	for _, teamId in teamIds() do
		setTeamScore(teamId, state.scores[teamId] or 0)
	end
end

local function syncPlayers()
	local present: { [string]: boolean } = {}
	if scoreScope() == "Team" then
		for _, teamId in teamIds() do
			present[teamId] = true
		end
	else
		for _, player in matchPlayers() do
			present[PlayerIds.toId(player)] = true
		end
	end
	MatchSim.setPlayers(state, present)
end

local handleMatchEvents: ({ MatchSim.MatchEvent }) -> ()

local function modeContext(): GameMode.ModeContext
	return {
		balls = {
			grantHeldBall = BallService.grantHeldBall,
			clearAll = BallService.clearAll,
		},
		getPlayers = function()
			return matchPlayers()
		end,
		getPlayerTeam = playerTeam,
		getPlayerById = PlayerIds.fromId,
		setPlayerTeam = setPlayerTeam,
		finishMatch = function(winnerId: string?, reason: string)
			local activeMode = mode
			if activeMode == nil then
				return
			end
			local events: { MatchSim.MatchEvent } = {}
			if MatchSim.finish(state, activeMode.rules, reason, events, winnerId) then
				handleMatchEvents(events)
			end
		end,
	}
end

-- Modes that own their scoreboard (GameMode.teamScore) have it recomputed here
-- rather than accumulated, so a player leaving, joining or changing side moves
-- the number the same way an elimination does.
local function refreshTeamScores()
	local activeMode = mode
	if activeMode == nil or activeMode.teamScore == nil then
		return
	end
	-- Frozen once the match is decided, so players drifting away during results
	-- cannot walk the final scoreboard away from what it was won with.
	if state.phase ~= "Starting" and state.phase ~= "Active" then
		return
	end
	local scorer = activeMode.teamScore
	local ctx = modeContext()
	local events: { MatchSim.MatchEvent } = {}
	for _, teamId in teamIds() do
		MatchSim.setScore(state, teamId, scorer(ctx, teamId), events)
	end
	if #events > 0 then
		handleMatchEvents(events)
	end
end

local function grantSpawnProtection(character: Model)
	local activeMode = assert(mode, "[MatchService] spawn protection requires an active mode")
	if activeMode.rules.SpawnInvulnSeconds <= 0 then
		return
	end
	local generation = (spawnProtectionGeneration[character] or 0) + 1
	spawnProtectionGeneration[character] = generation
	character:SetAttribute("minv", true)
	task.delay(activeMode.rules.SpawnInvulnSeconds, function()
		if spawnProtectionGeneration[character] ~= generation then
			return
		end
		spawnProtectionGeneration[character] = nil
		if character.Parent ~= nil then
			character:SetAttribute("minv", nil)
		end
	end)
end

local function startMatch(events: { MatchSim.MatchEvent })
	local activeMode = assert(mode, "[MatchService] startMatch requires a selected mode")
	table.clear(resultRosterByUserId)
	table.clear(contestantStatsByUserId)
	table.clear(spawnedThisMatch)
	table.clear(playerMatchElims)
	table.clear(pendingWaveRespawns)
	waveTimer = activeMode.rules.WaveRespawnSeconds or 0
	assignTeams()
	for _, player in matchPlayers() do
		rememberContestant(player)
	end

	for _, player in matchPlayers() do
		local character = player.Character
		if character then
			local key = PlayerIds.toId(player)
			respawnGeneration[key] = (respawnGeneration[key] or 0) + 1
			EliminationService.up(player)
			spawnedThisMatch[key] = true
			SpawnRouter.spawn(character, player, playerTeam(player), "MatchStart")
			grantSpawnProtection(character)
		end
	end

	syncPlayers()
	activeMode.onMatchStart(modeContext())
	MatchSim.start(state, activeMode.rules, events)
	setStateAttribute("modeId", activeMode.id)
	-- A mode with no elimination target replicates zero rather than infinity: the
	-- HUD reads zero as "no target, play to the clock", and an infinite attribute
	-- reaches the objective line as the literal word.
	local target = activeMode.rules.ScoreTarget
	setStateAttribute("scoreTarget", if target == math.huge then 0 else target)
	setStateAttribute("scoreScope", activeMode.scoreScope or "Player")
end

local function cleanupMatch()
	BallService.clearAll()

	for _, player in matchPlayers() do
		local key = PlayerIds.toId(player)
		player:SetAttribute("MatchRespawnAt", nil)
		if not spawnedThisMatch[key] then
			continue
		end
		respawnGeneration[key] = (respawnGeneration[key] or 0) + 1
		pendingWaveRespawns[key] = nil
		local character = player.Character
		if character then
			EliminationService.up(player)
			SpawnRouter.spawn(character, player, nil, "Cleanup")
		end
	end
end

function handleMatchEvents(events: { MatchSim.MatchEvent })
	for _, event in events do
		if event.kind == "ScoreChanged" then
			if scoreScope() == "Team" and event.playerId ~= nil then
				setTeamScore(event.playerId, event.score or 0)
			else
				local player = PlayerIds.fromId(event.playerId)
				if player then
					setScore(player, event.score or 0)
				end
			end
		elseif event.kind == "MatchPreparing" then
			opponentDeadline = nil
			setStateAttribute("opponentDeadline", nil)
			lastResult = nil
			resetAllScores()
			setStateAttribute("winnerId", "")
			for _, teamId in teamIds() do
				setTeamScore(teamId, state.scores[teamId] or 0)
			end
		elseif event.kind == "MatchStarted" then
			refreshPopulation()
			local activeMode = assert(mode, "[MatchService] MatchStarted without a selected mode")
			print(`[Match] started — {activeMode.id}`)
		elseif event.kind == "MatchEnded" then
			opponentDeadline = nil
			setStateAttribute("opponentDeadline", nil)
			local activeMode = assert(mode, "[MatchService] MatchEnded without a selected mode")
			activeMode.onMatchEnd(modeContext())
			buildResult(activeMode, event)
			setStateAttribute("winnerId", event.winnerId or "")
			print(`[Match] ended ({event.reason}) — winner: {event.winnerId or "none (tie)"}`)
		elseif event.kind == "MatchReset" then
			cleanupMatch()
			setStateAttribute("winnerId", "")
			for _, teamId in teamIds() do
				setTeamScore(teamId, 0)
			end
		elseif event.kind == "IntermissionEnded" then
			for _, teamId in teamIds() do
				setStateAttribute(teamAttrName(teamId), nil)
			end
			clearTeams()
			table.clear(partyTeamAssignments)
			mode = nil
			setStateAttribute("modeId", "")
		end
		dispatch(event)
	end
	setStateAttribute("phase", state.phase)
end

local function syncCharacterTeam(player: Player, character: Model)
	character:SetAttribute("TeamId", playerTeam(player))
end

local function onCharacterAdded(player: Player, character: Model)
	if not ArenaSessionService.isRoundEligible(player) then
		return
	end
	local humanoid = character:WaitForChild("Humanoid")
	assert(humanoid:IsA("Humanoid"), "[MatchService] character Humanoid must be a Humanoid")
	if player.Character ~= character or player.Parent == nil then
		return
	end
	local previous = nativeDeathConnections[player.UserId]
	if previous then
		previous:Disconnect()
	end
	nativeDeathConnections[player.UserId] = humanoid.Died:Connect(function()
		if player.Character == character and state.phase == "Active" then
			MatchService.eliminate(player, nil)
		end
	end)
	syncCharacterTeam(player, character)
	local key = PlayerIds.toId(player)
	local deadline = player:GetAttribute("MatchRespawnAt")
	if type(deadline) == "number" and state.phase == "Active" and mode and mode.rules.WaveRespawnSeconds then
		EliminationService.down(player)
		pendingWaveRespawns[key] = player
		player:SetAttribute("MatchRespawnAt", Workspace:GetServerTimeNow() + math.max(waveTimer, 0))
		return
	end
	if type(deadline) == "number" and deadline > Workspace:GetServerTimeNow() then
		EliminationService.down(player)
		local generation = respawnGeneration[key]
		task.delay(deadline - Workspace:GetServerTimeNow(), function()
			if
				player.Character == character
				and respawnGeneration[key] == generation
				and player:GetAttribute("MatchRespawnAt") == deadline
			then
				onCharacterAdded(player, character)
			end
		end)
		return
	end
	if humanoid.Health <= 0 then
		return
	end
	EliminationService.up(player)
	player:SetAttribute("MatchRespawnAt", nil)
	if not isArenaJoinPhase() then
		SpawnRouter.spawn(character, player, playerTeam(player), "Idle")
		return
	end
	SpawnRouter.spawn(character, player, playerTeam(player), "Join")
	grantSpawnProtection(character)

	local isFirstSpawn = not spawnedThisMatch[key]
	spawnedThisMatch[key] = true
	local activeMode = assert(mode, "[MatchService] arena join phase without a selected mode")
	activeMode.onPlayerSpawned(modeContext(), player, isFirstSpawn)
	refreshTeamScores()
end

local function watchPlayer(player: Player)
	if not ArenaSessionService.isRoundEligible(player) or watchedPlayers[player.UserId] ~= nil then
		return
	end
	if scoreScope() == "Team" and playerTeam(player) == nil then
		assignLateJoinTeam(player)
	end
	if isArenaJoinPhase() then
		rememberContestant(player)
	end
	setScore(player, 0)
	syncPlayers()
	watchedPlayers[player.UserId] = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character then
		onCharacterAdded(player, character)
	end
end

local function respawnPlayer(player: Player)
	if player.Parent == nil then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil then
		return
	end
	if humanoid.Health <= 0 then
		-- A native death (fall/void/etc.) can reach here without ever going through
		-- EliminationService.down, so forget() has nothing to tear down and must not
		-- gate this replacement retry -- doing so left the corpse in place indefinitely,
		-- relying on Roblox's own (slower, uncoordinated) auto-respawn timer.
		EliminationService.forget(character)
		player:SetAttribute("MatchRespawnAt", nil)
		task.spawn(function()
			while player.Parent ~= nil and player.Character == character do
				local ok, err = pcall(player.LoadCharacterAsync, player)
				if ok then
					return
				end
				warn(`[MatchService] Native character replacement failed: {err}`)
				task.wait(GameModes.NativeRespawnRetrySeconds)
			end
		end)
		return
	end
	if not EliminationService.up(player) then
		return
	end
	player:SetAttribute("MatchRespawnAt", nil)
	if state.phase == "Active" then
		SpawnRouter.spawn(character, player, playerTeam(player), "Respawn")
	end
	grantSpawnProtection(character)
	if state.phase == "Active" then
		local activeMode = assert(mode, "[MatchService] active phase without a selected mode")
		activeMode.onPlayerSpawned(modeContext(), player, false)
		refreshTeamScores()
	end
end

local function scoreIdForElim(sourceId: string?): string?
	if sourceId == nil then
		return nil
	end
	if scoreScope() ~= "Team" then
		return sourceId
	end
	local source = PlayerIds.fromId(sourceId)
	return if source then playerTeam(source) else nil
end

local function incrementPlayerElim(sourceId: string?)
	if sourceId == nil then
		return
	end
	local source = PlayerIds.fromId(sourceId)
	if source == nil then
		return
	end
	local key = PlayerIds.toId(source)
	playerMatchElims[key] = (playerMatchElims[key] or 0) + 1
	setScore(source, playerMatchElims[key])
end

local function knockbackVelocity(event: { [string]: any }): Vector3?
	local direction = event.direction
	local flat: Vector3
	if typeof(direction) == "Vector3" then
		flat = Vector3.new(direction.X, 0, direction.Z)
	elseif typeof(direction) == "vector" then
		flat = Vector3.new(direction.x, 0, direction.z)
	else
		return nil
	end

	if flat.Magnitude <= 1e-6 then
		return nil
	end

	local unit = flat.Unit
	local speed = if event.projectileId ~= nil then Combat.Dodgeball.KnockbackSpeed else Combat.Hammer.KnockbackSpeed
	local upSpeed = if event.projectileId ~= nil
		then Combat.Dodgeball.KnockbackUpSpeed
		else Combat.Hammer.KnockbackUpSpeed
	return Vector3.new(unit.X * speed, upSpeed, unit.Z * speed)
end

local function eliminateVictim(targetId: string?, event: { [string]: any }): boolean
	local activeMode = assert(mode, "[MatchService] elimination without a selected mode")
	local player = PlayerIds.fromId(targetId)
	if player == nil or not EliminationService.down(player, knockbackVelocity(event)) then
		return false
	end
	local key = PlayerIds.toId(player)
	local generation = (respawnGeneration[key] or 0) + 1
	respawnGeneration[key] = generation
	if activeMode.rules.WaveRespawnSeconds then
		pendingWaveRespawns[key] = player
		player:SetAttribute("MatchRespawnAt", Workspace:GetServerTimeNow() + math.max(waveTimer, 0))
	else
		player:SetAttribute("MatchRespawnAt", Workspace:GetServerTimeNow() + activeMode.rules.RespawnSeconds)
		task.delay(activeMode.rules.RespawnSeconds, function()
			if respawnGeneration[key] == generation then
				respawnPlayer(player)
			end
		end)
	end
	return true
end

local function tickWaveRespawns(dt: number)
	local activeMode = mode
	if activeMode == nil then
		return
	end
	local waveSeconds = activeMode.rules.WaveRespawnSeconds
	if waveSeconds == nil then
		return
	end
	if state.phase ~= "Active" and next(pendingWaveRespawns) == nil then
		return
	end

	waveTimer -= dt
	if waveTimer > 0 then
		return
	end
	waveTimer = waveSeconds

	local pending = pendingWaveRespawns
	pendingWaveRespawns = {}
	for _, player in pending do
		respawnPlayer(player)
	end
end

function MatchService.handleCombatEvent(event: { [string]: any }): boolean
	if event.kind == "BallWindup" or event.kind == "HammerSwing" then
		local player = PlayerIds.fromEvent(event)
		local character = if player then player.Character else nil
		if character then
			character:SetAttribute("minv", nil)
		end
		if state.phase == "Active" then
			dispatch(table.clone(event))
		end
	end
	if event.kind == "BallCaught" then
		if state.phase ~= "Active" then
			return false
		end
		local catcher = PlayerIds.fromId(event.playerId or event.sourceId)
		if catcher == nil or not ArenaSessionService.isRoundEligible(catcher) then
			return false
		end
		dispatch(table.clone(event))
		Network.fire("CombatFeed", nil, {
			kind = "BallCaught",
			tick = event.tick,
			projectileId = event.projectileId,
			sourceId = event.sourceId,
			targetId = event.targetId,
		})
		return false
	end

	if event.kind ~= "Elim" then
		return false
	end
	if state.phase ~= "Active" or (mode ~= nil and not GameModes.IsCombat(mode.id)) then
		return false
	end
	local target = PlayerIds.fromId(event.targetId)
	if target == nil or not ArenaSessionService.isRoundEligible(target) then
		return false
	end
	local source = PlayerIds.fromId(event.sourceId)
	if event.sourceId ~= nil and (source == nil or not ArenaSessionService.isRoundEligible(source)) then
		return false
	end
	local acceptedEvent = table.clone(event)
	if acceptedEvent.position == nil then
		local character = target.Character
		if character ~= nil then
			acceptedEvent.position = character:GetPivot().Position
		end
	end
	local equippedItemId = if source then source:GetAttribute("Equip_ElimEffectAssets") else nil
	acceptedEvent.elimEffectItemId = if typeof(equippedItemId) == "string" and equippedItemId ~= ""
		then equippedItemId
		else nil
	local activeMode = assert(mode, "[MatchService] active phase without a selected mode")
	if not eliminateVictim(acceptedEvent.targetId, acceptedEvent) then
		return false
	end

	local events: { MatchSim.MatchEvent } = {}
	if activeMode.teamScore == nil then
		MatchSim.applyElim(
			state,
			activeMode.rules,
			scoreIdForElim(acceptedEvent.sourceId),
			acceptedEvent.targetId,
			events
		)
	end
	dispatch(table.clone(acceptedEvent))
	Network.fire("CombatFeed", nil, {
		kind = "Elim",
		tick = acceptedEvent.tick,
		projectileId = acceptedEvent.projectileId,
		sourceId = acceptedEvent.sourceId,
		targetId = acceptedEvent.targetId,
		position = acceptedEvent.position,
		direction = acceptedEvent.direction,
		elimEffectItemId = acceptedEvent.elimEffectItemId,
	})
	incrementPlayerElim(acceptedEvent.sourceId)
	if state.phase == "Active" then
		activeMode.onElim(modeContext(), acceptedEvent.sourceId, acceptedEvent.targetId)
	end
	handleMatchEvents(events)
	refreshTeamScores()
	return true
end

function MatchService.stateForAdmin(): { [string]: any }
	return {
		phase = state.phase,
		modeId = if mode then mode.id else nil,
		timeRemaining = state.timeRemaining,
		startingRemaining = state.startingRemaining,
		resultsRemaining = state.resultsRemaining,
		intermissionRemaining = state.intermissionRemaining,
		winnerId = state.winnerId,
		scoreTarget = if mode then mode.rules.ScoreTarget else 0,
		scores = table.clone(state.scores),
	}
end

function MatchService.resultSnapshot(): PostMatchResult.GlobalResult?
	return lastResult
end

local function rosterAllows(rules: GameMode.MatchRules, players: { Player }): boolean
	local entrants = {}
	for _, player in players do
		table.insert(entrants, { id = PlayerIds.toId(player), partyId = ArenaSessionService.partyIdFor(player) })
	end
	local practice = #players == 1 and (RunService:IsStudio() or DevSoloPlay.canUse(players[1]))
	return ModeAvailability.canStart(rules, entrants, practice)
end

local function captureRules(selectedMode: GameMode.GameMode)
	selectedMode.rules = selectedMode.resolveRules()
	local players = matchPlayers()
	if #players == 1 and (RunService:IsStudio() or DevSoloPlay.canUse(players[1])) then
		selectedMode.rules.MinPlayers = 1
		selectedMode.rules.MinParties = 1
	end
	-- Resolved once, here, against the roster that is actually starting. Players
	-- join and leave mid-match; a target that moved with them would change what
	-- winning takes while the match is being played.
	selectedMode.rules.ScoreTarget = ScoreTarget.resolve(selectedMode.rules, #players)
end

refreshPopulation = function()
	if state.phase ~= "Active" or mode == nil then
		return
	end
	local entrants = {}
	for _, player in matchPlayers() do
		table.insert(entrants, { teamId = playerTeam(player) })
	end
	if ModeAvailability.canContinue(mode.rules, entrants) then
		opponentDeadline = nil
	elseif opponentDeadline == nil then
		opponentDeadline = Workspace:GetServerTimeNow() + GameModes.OpponentGraceSeconds
	end
	setStateAttribute("opponentDeadline", opponentDeadline)
end

function MatchService.availableModes(): { string }
	local players = matchPlayers()
	local options = {}
	for _, modeId in ModeOptions.resolve(ArenaSessionService.modeOptions()) do
		local candidate = ModeRegistry.get(modeId)
		if candidate and rosterAllows(candidate.resolveRules(), players) then
			table.insert(options, modeId)
		end
	end
	return options
end

function MatchService.beginMode(modeId: string): (boolean, string?)
	if startingMatch or state.phase ~= "Idle" then
		return false, "match_not_idle"
	end
	local selectedMode = ModeRegistry.get(modeId)
	if selectedMode == nil then
		return false, "unknown_mode"
	end
	-- Snapshot the mode's rules from live config at the boundary so an override
	-- staged during the previous match lands here and holds for the whole match.
	captureRules(selectedMode)
	for _, player in matchPlayers() do
		if not PlayerData.canQueueMatchAward(player) then
			player:SetAttribute("RewardsRecoveryPending", true)
			ArenaSessionService.setRoundEligible(player, false)
		end
	end
	if not rosterAllows(selectedMode.rules, matchPlayers()) then
		return false, "not_enough_players"
	end

	startingMatch = true
	mode = selectedMode
	local events: { MatchSim.MatchEvent } = {}
	local success, startError = pcall(startMatch, events)
	startingMatch = false
	if not success then
		warn(`[MatchService] startMatch failed: {startError}`)
		BallService.clearAll()
		clearTeams()
		table.clear(partyTeamAssignments)
		mode = nil
		state = MatchSim.newState()
		setStateAttribute("modeId", "")
		return false, "start_failed"
	end

	handleMatchEvents(events)
	refreshTeamScores()
	return true, nil
end

function MatchService.restartForAdmin(modeId: string?): (boolean, string?)
	local nextMode = if modeId then ModeRegistry.get(modeId) else mode or ModeRegistry.default()
	if nextMode == nil then
		return false, "unknown_mode"
	end

	local previousTeams = teamIds()
	if mode ~= nil and state.phase ~= "Idle" then
		if state.phase == "Active" then
			(mode :: GameMode.GameMode).onMatchEnd(modeContext())
		end
		cleanupMatch()
	end
	for _, teamId in previousTeams do
		setStateAttribute(teamAttrName(teamId), nil)
	end

	mode = nextMode
	captureRules(nextMode)
	state = MatchSim.newState()
	local events: { MatchSim.MatchEvent } = {}
	startMatch(events)
	handleMatchEvents(events)
	refreshTeamScores()
	return true
end

function MatchService.endForAdmin(): (boolean, string?)
	local activeMode = mode
	if activeMode == nil then
		return false, "no_selected_mode"
	end
	local events: { MatchSim.MatchEvent } = {}
	if not MatchSim.finish(state, activeMode.rules, "Developer", events) then
		return false, "match_not_active"
	end
	handleMatchEvents(events)
	return true
end

function MatchService.devEndMatchForPlayer(player: Player): (boolean, string?)
	local activeMode = mode
	if activeMode == nil then
		return false, "no_selected_mode"
	end
	local winnerId: string?
	if scoreScope() == "Team" then
		winnerId = playerTeam(player)
		if winnerId == nil then
			return false, "no_team"
		end
	else
		winnerId = PlayerIds.toId(player)
	end
	local events: { MatchSim.MatchEvent } = {}
	if not MatchSim.finish(state, activeMode.rules, "DevSkip", events, winnerId) then
		return false, "match_not_active"
	end
	handleMatchEvents(events)
	return true
end

function MatchService.setTimeForAdmin(seconds: number): (boolean, string?)
	if state.phase ~= "Active" then
		return false, "match_not_active"
	end
	if seconds < 0 or seconds ~= seconds or math.abs(seconds) == math.huge then
		return false, "invalid_time"
	end
	state.timeRemaining = seconds
	setStateAttribute("timeRemaining", math.floor(state.timeRemaining + 0.5))
	return true
end

local function buildElimEvent(source: Player?, target: Player): { [string]: any }
	externalEventSequence += 1
	local character = target.Character
	return {
		kind = "Elim",
		tick = -externalEventSequence,
		sourceId = if source then PlayerIds.toId(source) else nil,
		targetId = PlayerIds.toId(target),
		position = if character then character:GetPivot().Position else nil,
		direction = Vector3.zero,
	}
end

function MatchService.eliminate(target: Player, source: Player?): boolean
	return MatchService.handleCombatEvent(buildElimEvent(source, target))
end

function MatchService.eliminateForAdmin(source: Player?, target: Player): (boolean, { [string]: any })
	local event = buildElimEvent(source, target)
	return MatchService.handleCombatEvent(event), event
end

function MatchService.reviveForAdmin(player: Player): (boolean, string?)
	local character = player.Character
	if character == nil then
		return false, "no_character"
	end
	if not EliminationService.isDown(character) then
		return false, "not_eliminated"
	end
	local key = PlayerIds.toId(player)
	respawnGeneration[key] = (respawnGeneration[key] or 0) + 1
	pendingWaveRespawns[key] = nil
	respawnPlayer(player)
	return true
end

function MatchService.teleportToSpawnForAdmin(player: Player): (boolean, string?)
	local character = player.Character
	if character == nil then
		return false, "no_character"
	end
	SpawnRouter.spawn(character, player, playerTeam(player), "Admin")
	return true
end

-- Server seams for a mode owner that scores something other than eliminations
-- (Splashdown points): the score still flows through MatchSim so the replicated
-- attribute, leaderstats and results all read from one place.
function MatchService.setPlayerScore(player: Player, score: number): boolean
	if state.phase ~= "Active" and state.phase ~= "Starting" then
		return false
	end
	local events: { MatchSim.MatchEvent } = {}
	if not MatchSim.setScore(state, PlayerIds.toId(player), score, events) then
		return false
	end
	handleMatchEvents(events)
	return true
end

function MatchService.finishMatch(winnerId: string?, reason: string): boolean
	local activeMode = mode
	if activeMode == nil then
		return false
	end
	local events: { MatchSim.MatchEvent } = {}
	if not MatchSim.finish(state, activeMode.rules, reason, events, winnerId) then
		return false
	end
	handleMatchEvents(events)
	return true
end

function MatchService.setContestantStats(player: Player, stats: { [string]: number })
	contestantStatsByUserId[player.UserId] = table.clone(stats)
	local contestant = resultRosterByUserId[player.UserId]
	if contestant then
		contestant.stats = contestantStatsByUserId[player.UserId]
	end
end

function MatchService.activeModeId(): string?
	return if mode then mode.id else nil
end

function MatchService.start()
	if started then
		return
	end
	started = true

	ArenaService.start()
	ensureStateFolder()

	Network.handleProtected("DevEndMatch", {
		rateLimit = 2,
		validate = function(player)
			return DevSoloPlay.canUse(player), "not_authorized"
		end,
	}, function(player)
		local ok, reason = MatchService.devEndMatchForPlayer(player)
		if not ok then
			warn(`[MatchService] DevEndMatch refused for {player.Name}: {reason}`)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(watchPlayer, player)
	end)
	ArenaSessionService.onReady(function(player)
		watchPlayer(player)
		refreshPopulation()
	end)
	ArenaSessionService.onRoundEligibilityChanged(function()
		task.defer(function()
			refreshPopulation()
			refreshTeamScores()
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if resultRosterByUserId[player.UserId] then
			rememberContestant(player)
		end
		local deathConnection = nativeDeathConnections[player.UserId]
		if deathConnection then
			deathConnection:Disconnect()
			nativeDeathConnections[player.UserId] = nil
		end
		local watchedConnection = watchedPlayers[player.UserId]
		if watchedConnection then
			watchedConnection:Disconnect()
			watchedPlayers[player.UserId] = nil
		end
		local key = PlayerIds.toId(player)
		respawnGeneration[key] = (respawnGeneration[key] or 0) + 1
		pendingWaveRespawns[key] = nil
		spawnedThisMatch[key] = nil
		task.defer(function()
			syncPlayers()
			refreshPopulation()
			refreshTeamScores()
		end)
	end)
	for _, player in matchPlayers() do
		watchPlayer(player)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		local events: { MatchSim.MatchEvent } = {}
		local activeMode = mode
		if activeMode then
			if state.phase == "Active" and opponentDeadline and Workspace:GetServerTimeNow() >= opponentDeadline then
				MatchSim.noContest(state, activeMode.rules, events)
			else
				MatchSim.tick(state, activeMode.rules, dt, events)
			end
		end
		handleMatchEvents(events)
		tickWaveRespawns(dt)
		local displaySeconds = if state.phase == "Intermission"
			then state.intermissionRemaining
			else if state.phase == "Starting" then state.startingRemaining else state.timeRemaining
		setStateAttribute("timeRemaining", math.floor(displaySeconds + 0.5))
	end)
end

return MatchService
