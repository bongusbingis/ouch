--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = Shared:WaitForChild("Game")
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local MatchSim = require(Game:WaitForChild("Sim"):WaitForChild("MatchSim"))
local GameMode = require(Game:WaitForChild("Modes"):WaitForChild("GameMode"))
local ModeRegistry = require(Game:WaitForChild("Modes"):WaitForChild("ModeRegistry"))

local MapService = require(script.Parent.MapService)
local BallService = require(script.Parent.BallService)
local EliminationService = require(script.Parent.EliminationService)

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
local started = false

function MatchService.onEvent(listener: (event: { [string]: any }) -> ())
	table.insert(listeners, listener)
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

local function resetAllScores()
	for _, player in Players:GetPlayers() do
		setScore(player, state.scores[playerKey(player)] or 0)
	end
end

local function syncPlayers()
	local present: { [string]: boolean } = {}
	for _, player in Players:GetPlayers() do
		present[playerKey(player)] = true
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

	for _, player in Players:GetPlayers() do
		local character = player.Character
		-- Absent characters are handled by the CharacterAdded path, which
		-- also covers their first-spawn mode hook.
		if character then
			local key = playerKey(player)
			respawnGeneration[key] = (respawnGeneration[key] or 0) + 1
			EliminationService.up(player)
			spawnedThisMatch[key] = true
			MapService.teleport(character)
			grantSpawnProtection(character)
		end
	end

	syncPlayers()
	mode.onMatchStart(modeContext())
	MatchSim.start(state, mode.rules, events)
	setStateAttribute("modeId", mode.id)
	setStateAttribute("mapId", map.id)
end

local function cleanupMatch()
	BallService.stopGroundSpawns()
	BallService.clearAll()
	MapService.despawn()
	-- TODO(lobby): teleport players back to the lobby here; for now the engine
	-- respawns them at the lobby SpawnLocation when the map despawns under them.
end

local function handleMatchEvents(events: { MatchSim.MatchEvent })
	for _, event in events do
		if event.kind == "ScoreChanged" then
			local player = playerFromId(event.playerId)
			if player then
				setScore(player, event.score or 0)
			end
		elseif event.kind == "MatchStarted" then
			resetAllScores()
			setStateAttribute("winnerId", "")
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
		end
		dispatch(event)
	end
	setStateAttribute("phase", state.phase)
end

local function onCharacterAdded(player: Player, character: Model)
	EliminationService.up(player)
	grantSpawnProtection(character)
	if state.phase ~= "Active" or MapService.active() == nil then
		return
	end
	MapService.teleport(character)

	local key = playerKey(player)
	local isFirstSpawn = not spawnedThisMatch[key]
	spawnedThisMatch[key] = true
	mode.onPlayerSpawned(modeContext(), player, isFirstSpawn)
end

local function watchPlayer(player: Player)
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
		MapService.teleport(character)
	end
	grantSpawnProtection(character)
	if state.phase == "Active" and MapService.active() ~= nil then
		mode.onPlayerSpawned(modeContext(), player, false)
	end
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
	task.delay(mode.rules.RespawnSeconds, function()
		if respawnGeneration[key] == generation then
			respawnPlayer(player)
		end
	end)
	return true
end

-- Called with authoritative (server-side) sim events from the adapter.
function MatchService.handleCombatEvent(event: { [string]: any }): boolean
	if event.kind ~= "Elim" then
		return false
	end
	if not eliminateVictim(event.targetId, event) then
		return false
	end

	local events: { MatchSim.MatchEvent } = {}
	MatchSim.applyElim(state, mode.rules, event.sourceId, event.targetId, events)
	if state.phase == "Active" and MapService.active() ~= nil then
		mode.onElim(modeContext(), event.sourceId, event.targetId)
	end
	handleMatchEvents(events)
	dispatch({ kind = "Elim", sourceId = event.sourceId, targetId = event.targetId })
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
		setStateAttribute("timeRemaining", math.floor(state.timeRemaining + 0.5))
	end)
end

return MatchService
