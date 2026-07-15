--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local MatchSim = require(Game:WaitForChild("Sim"):WaitForChild("MatchSim"))
local TeamSpawns = require(Game:WaitForChild("Maps"):WaitForChild("TeamSpawns"))
local GameMode = require(Game:WaitForChild("Modes"):WaitForChild("GameMode"))
local ModeRegistry = require(Game:WaitForChild("Modes"):WaitForChild("ModeRegistry"))

local MapService = require(script.Parent.MapService)
local BallService = require(script.Parent.BallService)
local EliminationService = require(script.Parent.EliminationService)
local LobbyService = require(script.Parent.LobbyService)
local MapFeatureService = require(script.Parent.MapFeatureService)

-- Server orchestration of the match loop: drives MatchSim with the active
-- mode's rules, owns match lifecycle (map spawn, teleports, ball
-- provisioning via mode hooks), and applies elimination consequences.
--
-- UI hook points (no UI exists yet, intentionally):
--   * ReplicatedStorage.MatchState attributes: `phase`, `timeRemaining`
--     (whole seconds), `winnerId` ("" if none), `modeId`, `mapId`.
--     TODO(ui): HUD elements subscribe via GetAttributeChangedSignal; look up
--     display data in Config.Maps / the mode's displayName via ModeRegistry.
--   * Per-player `MatchScore` attribute plus leaderstats "Elims".
--     TODO(ui): scoreboard reads MatchScore attributes across Players.
--   * MatchService.onEvent(listener): MatchSim events plus re-emitted Elims.
--     TODO(ui): killfeed subscribes here (forward via remote).

local MatchService = {}

local STATE_FOLDER_NAME = "MatchState"

local state = MatchSim.newState()
local mode: GameMode.GameMode = ModeRegistry.default()
-- TODO(voting): mode voting replaces this fixed selection.

local listeners: { (event: { [string]: any }) -> () } = {}
local stateFolder: Folder? = nil
local spawnedThisMatch: { [string]: boolean } = {}
-- Bumping a player's generation cancels their pending scheduled respawn.
local respawnGeneration: { [string]: number } = {}
local playerMatchElims: { [string]: number } = {}
local pendingWaveRespawns: { [string]: Player } = {}
local waveTimer = 0
local started = false

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
	created:SetAttribute("modeId", mode.id)
	created:SetAttribute("mapId", "")
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

local function playerKey(player: Player): string
	return tostring(player.UserId)
end

local function playerFromId(playerId: string?): Player?
	local userId = if playerId then tonumber(playerId) else nil
	if userId == nil then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function scoreScope(): GameMode.ScoreScope
	return mode.scoreScope or "Player"
end

local function teamIds(): { string }
	return mode.teams or {}
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

local function clearTeams()
	for _, player in Players:GetPlayers() do
		setPlayerTeam(player, nil)
	end
end

local function assignTeams()
	local teams = teamIds()
	if #teams == 0 then
		clearTeams()
		return
	end

	local counts: { [string]: number } = {}
	for _, teamId in teams do
		counts[teamId] = 0
	end

	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)

	for _, player in players do
		local bestTeam = teams[1]
		for _, teamId in teams do
			if counts[teamId] < counts[bestTeam] then
				bestTeam = teamId
			end
		end
		setPlayerTeam(player, bestTeam)
		counts[bestTeam] += 1
	end
end

local function assignLateJoinTeam(player: Player)
	local teams = teamIds()
	if #teams == 0 then
		setPlayerTeam(player, nil)
		return
	end

	local counts: { [string]: number } = {}
	for _, teamId in teams do
		counts[teamId] = 0
	end
	for _, existing in Players:GetPlayers() do
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
	for _, player in Players:GetPlayers() do
		local key = playerKey(player)
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
		for _, player in Players:GetPlayers() do
			present[playerKey(player)] = true
		end
	end
	MatchSim.setPlayers(state, present)
end

local function modeContext(): GameMode.ModeContext
	local map = assert(MapService.active(), "[MatchService] mode context requires an active map")
	return {
		map = {
			ballSpawns = map.ballSpawns,
			playerSpawns = map.playerSpawns,
		},
		balls = {
			startGroundSpawns = BallService.startGroundSpawns,
			stopGroundSpawns = BallService.stopGroundSpawns,
			grantHeldBall = BallService.grantHeldBall,
			clearAll = BallService.clearAll,
		},
		getPlayers = function()
			return Players:GetPlayers()
		end,
		getPlayerTeam = playerTeam,
	}
end

local function grantSpawnProtection(character: Model)
	character:SetAttribute("minv", true)
	task.delay(mode.rules.SpawnInvulnSeconds, function()
		if character.Parent ~= nil then
			character:SetAttribute("minv", nil)
		end
	end)
end

local function startMatch(events: { MatchSim.MatchEvent })
	local map = MapService.spawnRandom()
	table.clear(spawnedThisMatch)
	table.clear(playerMatchElims)
	table.clear(pendingWaveRespawns)
	waveTimer = mode.rules.WaveRespawnSeconds or 0
	assignTeams()

	local teams = teamIds()
	if #teams > 0 then
		local positions = table.create(#map.playerSpawns)
		for index, part in map.playerSpawns do
			positions[index] = part.Position
		end
		local assignment = TeamSpawns.split(positions, teams)
		local byTeam: { [string]: { BasePart } } = {}
		for teamId, indices in assignment do
			local parts = table.create(#indices)
			for _, index in indices do
				table.insert(parts, map.playerSpawns[index])
			end
			byTeam[teamId] = parts
		end
		MapService.assignTeamSpawns(byTeam)
	end

	for _, player in Players:GetPlayers() do
		local character = player.Character
		-- Absent characters are handled by the CharacterAdded path, which
		-- also covers their first-spawn mode hook.
		if character then
			local key = playerKey(player)
			respawnGeneration[key] = (respawnGeneration[key] or 0) + 1
			EliminationService.up(player)
			spawnedThisMatch[key] = true
			MapService.teleport(character, playerTeam(player))
			grantSpawnProtection(character)
		end
	end

	syncPlayers()
	MapFeatureService.bind(map.bouncePads, map.foamPits)
	mode.onMatchStart(modeContext())
	MatchSim.start(state, mode.rules, events)
	setStateAttribute("modeId", mode.id)
	setStateAttribute("mapId", map.id)
end

local function cleanupMatch()
	MapFeatureService.unbind()
	BallService.stopGroundSpawns()
	BallService.clearAll()

	for _, player in Players:GetPlayers() do
		local key = playerKey(player)
		respawnGeneration[key] = (respawnGeneration[key] or 0) + 1
		pendingWaveRespawns[key] = nil
		local character = player.Character
		if character then
			EliminationService.up(player)
			LobbyService.teleport(character)
		end
	end

	MapService.despawn()
end

local function handleMatchEvents(events: { MatchSim.MatchEvent })
	for _, event in events do
		if event.kind == "ScoreChanged" then
			if scoreScope() == "Team" and event.playerId ~= nil then
				setTeamScore(event.playerId, event.score or 0)
			else
				local player = playerFromId(event.playerId)
				if player then
					setScore(player, event.score or 0)
				end
			end
		elseif event.kind == "MatchStarted" then
			resetAllScores()
			setStateAttribute("winnerId", "")
			for _, teamId in teamIds() do
				setTeamScore(teamId, state.scores[teamId] or 0)
			end
			local map = MapService.active()
			print(`[Match] started — {mode.id} on {if map then map.id else "?"}`)
		elseif event.kind == "MatchEnded" then
			mode.onMatchEnd(modeContext())
			setStateAttribute("winnerId", event.winnerId or "")
			print(`[Match] ended ({event.reason}) — winner: {event.winnerId or "none (tie)"}`)
		elseif event.kind == "MatchReset" then
			cleanupMatch()
			setStateAttribute("winnerId", "")
			setStateAttribute("mapId", "")
			for _, teamId in teamIds() do
				setTeamScore(teamId, 0)
			end
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
	grantSpawnProtection(character)
	if state.phase ~= "Active" or MapService.active() == nil then
		return
	end
	MapService.teleport(character, playerTeam(player))

	local key = playerKey(player)
	local isFirstSpawn = not spawnedThisMatch[key]
	spawnedThisMatch[key] = true
	mode.onPlayerSpawned(modeContext(), player, isFirstSpawn)
end

local function watchPlayer(player: Player)
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
	local character = player.Character
	if character == nil then
		return
	end
	if state.phase == "Active" and MapService.active() ~= nil then
		MapService.teleport(character, playerTeam(player))
	end
	grantSpawnProtection(character)
	if state.phase == "Active" and MapService.active() ~= nil then
		mode.onPlayerSpawned(modeContext(), player, false)
	end
end

local function scoreIdForElim(sourceId: string?): string?
	if sourceId == nil then
		return nil
	end
	if scoreScope() ~= "Team" then
		return sourceId
	end
	local source = playerFromId(sourceId)
	return if source then playerTeam(source) else nil
end

local function incrementPlayerElim(sourceId: string?)
	if sourceId == nil then
		return
	end
	local source = playerFromId(sourceId)
	if source == nil then
		return
	end
	local key = playerKey(source)
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
	local player = playerFromId(targetId)
	if player == nil or not EliminationService.down(player, knockbackVelocity(event)) then
		return false
	end
	local key = playerKey(player)
	local generation = (respawnGeneration[key] or 0) + 1
	respawnGeneration[key] = generation
	if mode.rules.WaveRespawnSeconds then
		pendingWaveRespawns[key] = player
	else
		task.delay(mode.rules.RespawnSeconds, function()
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
	local waveSeconds = mode.rules.WaveRespawnSeconds
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
		return false
	end

	if event.kind ~= "Elim" then
		return false
	end
	if not eliminateVictim(event.targetId, event) then
		return false
	end

	local events: { MatchSim.MatchEvent } = {}
	MatchSim.applyElim(state, mode.rules, scoreIdForElim(event.sourceId), event.targetId, events)
	dispatch(table.clone(event))
	incrementPlayerElim(event.sourceId)
	if state.phase == "Active" and MapService.active() ~= nil then
		mode.onElim(modeContext(), event.sourceId, event.targetId)
	end
	handleMatchEvents(events)
	return true
end

function MatchService.start()
	if started then
		return
	end
	started = true

	ensureStateFolder()

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local key = playerKey(player)
		respawnGeneration[key] = (respawnGeneration[key] or 0) + 1
		pendingWaveRespawns[key] = nil
		task.defer(syncPlayers)
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		local events: { MatchSim.MatchEvent } = {}

		if state.phase == "Idle" and #Players:GetPlayers() >= mode.rules.MinPlayers then
			startMatch(events)
		end

		MatchSim.tick(state, mode.rules, dt, events)
		handleMatchEvents(events)
		tickWaveRespawns(dt)
		local displaySeconds = if state.phase == "Intermission"
			then state.intermissionRemaining
			else state.timeRemaining
		setStateAttribute("timeRemaining", math.floor(displaySeconds + 0.5))
	end)
end

return MatchService
