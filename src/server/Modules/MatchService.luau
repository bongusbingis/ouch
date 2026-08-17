--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local Config = ReplicatedStorage:WaitForChild("Config")
local Combat = require(Config:WaitForChild("Combat"))
local MatchSim = require(Game:WaitForChild("Sim"):WaitForChild("MatchSim"))
local GameMode = require(Game:WaitForChild("Modes"):WaitForChild("GameMode"))
local ModeRegistry = require(Game:WaitForChild("Modes"):WaitForChild("ModeRegistry"))
local PartyTeamAllocator = require(Game:WaitForChild("Modes"):WaitForChild("PartyTeamAllocator"))
local PlayerIds = require(Game:WaitForChild("Adapters"):WaitForChild("PlayerIds"))
local Network = require(Shared:WaitForChild("Network"))

local ArenaService = require(script.Parent.ArenaService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local BallService = require(script.Parent.BallService)
local EliminationService = require(script.Parent.EliminationService)

-- Server orchestration of an explicitly selected game mode in the permanent
-- authored arena. Matchmaking arrival and mode selection are separate owners.

local MatchService = {}

local STATE_FOLDER_NAME = "MatchState"

local state = MatchSim.newState()
local mode: GameMode.GameMode? = nil

local listeners: { (event: { [string]: any }) -> () } = {}
local stateFolder: Folder? = nil
local spawnedThisMatch: { [string]: boolean } = {}
-- Bumping a player's generation cancels their pending scheduled respawn.
local respawnGeneration: { [string]: number } = {}
local spawnProtectionGeneration: { [Model]: number } = {}
local playerMatchElims: { [string]: number } = {}
local pendingWaveRespawns: { [string]: Player } = {}
local partyTeamAssignments: { [string]: string } = {}
local waveTimer = 0
local testingEventSequence = 0
local started = false
local startingMatch = false

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
	local character = player.Character
	if character then
		character:SetAttribute("TeamId", teamId)
	end
end

local function matchPlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if ArenaSessionService.isAdmitted(player) then
			table.insert(result, player)
		end
	end
	return result
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
	}
end

local function grantSpawnProtection(character: Model)
	local activeMode = assert(mode, "[MatchService] spawn protection requires an active mode")
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
	table.clear(spawnedThisMatch)
	table.clear(playerMatchElims)
	table.clear(pendingWaveRespawns)
	waveTimer = activeMode.rules.WaveRespawnSeconds or 0
	assignTeams()

	for _, player in matchPlayers() do
		local character = player.Character
		-- Absent characters are handled by the CharacterAdded path, which
		-- also covers their first-spawn mode hook.
		if character then
			local key = PlayerIds.toId(player)
			respawnGeneration[key] = (respawnGeneration[key] or 0) + 1
			EliminationService.up(player)
			spawnedThisMatch[key] = true
			ArenaService.teleport(character, playerTeam(player))
			grantSpawnProtection(character)
		end
	end

	syncPlayers()
	activeMode.onMatchStart(modeContext())
	MatchSim.start(state, activeMode.rules, events)
	setStateAttribute("modeId", activeMode.id)
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
			ArenaService.teleport(character, nil)
		end
	end
end

local function handleMatchEvents(events: { MatchSim.MatchEvent })
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
			resetAllScores()
			setStateAttribute("winnerId", "")
			for _, teamId in teamIds() do
				setTeamScore(teamId, state.scores[teamId] or 0)
			end
		elseif event.kind == "MatchStarted" then
			local activeMode = assert(mode, "[MatchService] MatchStarted without a selected mode")
			print(`[Match] started — {activeMode.id}`)
		elseif event.kind == "MatchEnded" then
			local activeMode = assert(mode, "[MatchService] MatchEnded without a selected mode")
			activeMode.onMatchEnd(modeContext())
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
	syncCharacterTeam(player, character)
	EliminationService.up(player)
	local key = PlayerIds.toId(player)
	if not isArenaJoinPhase() then
		return
	end
	ArenaService.teleport(character, playerTeam(player))
	grantSpawnProtection(character)

	local isFirstSpawn = not spawnedThisMatch[key]
	spawnedThisMatch[key] = true
	local activeMode = assert(mode, "[MatchService] arena join phase without a selected mode")
	activeMode.onPlayerSpawned(modeContext(), player, isFirstSpawn)
end

local function watchPlayer(player: Player)
	if not ArenaSessionService.isAdmitted(player) then
		return
	end
	if scoreScope() == "Team" and playerTeam(player) == nil then
		assignLateJoinTeam(player)
	end
	setScore(player, 0)
	syncPlayers()
	player.CharacterAdded:Connect(function(character)
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
	if not EliminationService.up(player) then
		return
	end
	player:SetAttribute("MatchRespawnAt", nil)
	local character = player.Character
	if character == nil then
		return
	end
	if state.phase == "Active" then
		ArenaService.teleport(character, playerTeam(player))
	end
	grantSpawnProtection(character)
	if state.phase == "Active" then
		local activeMode = assert(mode, "[MatchService] active phase without a selected mode")
		activeMode.onPlayerSpawned(modeContext(), player, false)
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

-- Waves tick on a fixed cadence from match start so respawns come in
-- synchronized batches; the timer keeps running while anyone is pending so
-- deaths during Results still resolve.
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

-- Called with authoritative (server-side) sim events from the adapter.
function MatchService.handleCombatEvent(event: { [string]: any }): boolean
	if event.kind == "BallCaught" then
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
	if state.phase ~= "Active" then
		return false
	end
	local activeMode = assert(mode, "[MatchService] active phase without a selected mode")
	if not eliminateVictim(event.targetId, event) then
		return false
	end

	local events: { MatchSim.MatchEvent } = {}
	MatchSim.applyElim(state, activeMode.rules, scoreIdForElim(event.sourceId), event.targetId, events)
	dispatch(table.clone(event))
	Network.fire("CombatFeed", nil, {
		kind = "Elim",
		tick = event.tick,
		projectileId = event.projectileId,
		sourceId = event.sourceId,
		targetId = event.targetId,
	})
	incrementPlayerElim(event.sourceId)
	if state.phase == "Active" then
		activeMode.onElim(modeContext(), event.sourceId, event.targetId)
	end
	handleMatchEvents(events)
	return true
end

function MatchService.stateForTesting(): { [string]: any }
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

function MatchService.beginMode(modeId: string): (boolean, string?)
	if startingMatch or state.phase ~= "Idle" then
		return false, "match_not_idle"
	end
	local selectedMode = ModeRegistry.get(modeId)
	if selectedMode == nil then
		return false, "unknown_mode"
	end
	if #matchPlayers() < selectedMode.rules.MinPlayers then
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
	return true, nil
end

function MatchService.restartForTesting(modeId: string?): (boolean, string?)
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
	state = MatchSim.newState()
	local events: { MatchSim.MatchEvent } = {}
	startMatch(events)
	handleMatchEvents(events)
	return true
end

function MatchService.endForTesting(): (boolean, string?)
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

function MatchService.setTimeForTesting(seconds: number): (boolean, string?)
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

function MatchService.eliminateForTesting(source: Player?, target: Player): (boolean, { [string]: any })
	testingEventSequence += 1
	local event = {
		kind = "Elim",
		tick = -testingEventSequence,
		sourceId = if source then PlayerIds.toId(source) else nil,
		targetId = PlayerIds.toId(target),
		direction = Vector3.zero,
	}
	return MatchService.handleCombatEvent(event), event
end

function MatchService.reviveForTesting(player: Player): (boolean, string?)
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

function MatchService.teleportToSpawnForTesting(player: Player): (boolean, string?)
	local character = player.Character
	if character == nil then
		return false, "no_character"
	end
	ArenaService.teleport(character, playerTeam(player))
	return true
end

function MatchService.start()
	if started then
		return
	end
	started = true

	ArenaService.start()
	ensureStateFolder()

	Players.PlayerAdded:Connect(function(player)
		task.defer(watchPlayer, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local key = PlayerIds.toId(player)
		respawnGeneration[key] = (respawnGeneration[key] or 0) + 1
		pendingWaveRespawns[key] = nil
		spawnedThisMatch[key] = nil
		task.defer(syncPlayers)
	end)
	for _, player in matchPlayers() do
		watchPlayer(player)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		local events: { MatchSim.MatchEvent } = {}
		local activeMode = mode
		if activeMode then
			MatchSim.tick(state, activeMode.rules, dt, events)
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
