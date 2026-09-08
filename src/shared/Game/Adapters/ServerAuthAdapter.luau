-- Description: The server-only bridge between the engine and the pure simulation: runs the fixed-rate accumulator, builds the world snapshot, turns queued client intents into commands, steps the sim, encodes state back onto instances, and broadcasts events.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SimTypes = require(script.Parent.Parent.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Sim.SimCore)
local SimStateCodec = require(script.Parent.SimStateCodec)
local PlayerIds = require(script.Parent.PlayerIds)
local DodgeballRelease = require(script.Parent.DodgeballRelease)
local AssistProjection = require(script.Parent.Parent.Config.AssistProjection)
local PlayerAssist = require(script.Parent.Parent.Parent.Parent.Config.PlayerAssist)
local MobileInput = require(script.Parent.Parent.Parent.Parent.Config.Interface.MobileInput)
local Intercept = require(script.Parent.Parent.Sim.Intercept)
local MovementSpeedService = require(script.Parent.MovementSpeedService)
local WeaponRegistry = require(script.Parent.Parent.Sim.WeaponRegistry)
local ModeRegistry = require(script.Parent.Parent.Modes.ModeRegistry)
local Combat = require(script.Parent.Parent.Parent.Parent.Config.Gameplay.Combat)
local InputConfig = require(script.Parent.Parent.Parent.Parent.Config.Interface.Input)
local Debug = require(script.Parent.Parent.Parent.Parent.Config.Infra.Debug)
local Network = require(script.Parent.Parent.Parent.Network)
local IntentQueue = require(script.Parent.Parent.Input.IntentQueue)
local CombatEventPackets = require(script.Parent.CombatEventPackets)
local MovementGuard = require(script.Parent.MovementGuard)

type SimEvent = SimTypes.SimEvent
type InputCommand = SimTypes.InputCommand

local ServerAuthAdapter = {}

local BALLS_FOLDER_NAME = "Balls"

local listeners: { (SimEvent) -> () } = {}
local pendingWeaponResets: { [string]: boolean } = {}
local matchState: Folder? = nil
local started = false

local function trace(message: string)
	if Debug.CombatTrace then
		print(`[Combat] {message}`)
	end
end

function ServerAuthAdapter.onEvent(listener: (SimEvent) -> ())
	table.insert(listeners, listener)
end

local function dispatch(events: { SimEvent })
	for _, event in events do
		for _, listener in listeners do
			local eventCopy = table.clone(event)
			task.defer(function()
				local ok, err = pcall(listener, eventCopy)
				if not ok then
					warn(`[ServerAuthAdapter] event listener error: {err}`)
				end
			end)
		end
	end
end

type CharacterEntry = {
	model: Model,
	root: BasePart,
	player: Player,
}

local function collectCharacters(): ({ [string]: CharacterEntry }, { Instance })
	local entries: { [string]: CharacterEntry } = {}
	local excluded: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local model = player.Character
		if model == nil then
			continue
		end
		local admission = player:GetAttribute("ArenaAdmission")
		if
			(admission ~= "Direct" and admission ~= "Matched")
			or player:GetAttribute("ArenaReady") ~= true
			or player:GetAttribute("ArenaRoundEligible") == false
		then
			table.insert(excluded, model)
			continue
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		entries[PlayerIds.toId(player)] = { model = model, root = root, player = player }
		table.insert(excluded, model)
	end
	return entries, excluded
end

local function heldBallPosition(entry: CharacterEntry): Vector3
	local hand = entry.model:FindFirstChild("RightHand") or entry.model:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand.CFrame.Position
	end
	return entry.root.CFrame.Position
end

local function throwPosition(entry: CharacterEntry): Vector3
	return DodgeballRelease.position(entry.model, entry.root, Combat.Dodgeball.OverhandReleaseRootOffset)
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.RespectCanCollide = true

local collisionWorld: SimTypes.CollisionWorld = {
	sweepSphere = function(origin, displacement, radius)
		local distance = vector.magnitude(displacement)
		if distance <= 1e-6 then
			return nil
		end
		local result = Workspace:Spherecast(origin, radius, displacement, raycastParams)
		if result == nil then
			return nil
		end
		if Debug.CollisionTrace then
			trace(`sweep hit {result.Instance:GetFullName()} at d={result.Distance}`)
		end
		return {
			distance = result.Distance,
			position = origin + (displacement / distance) * result.Distance,
			normal = result.Normal,
		}
	end,
}

local simRules: SimTypes.SimRules = { preserveDodgeballs = false }

local worldSnapshot: SimTypes.WorldSnapshot = {
	characters = {},
	collision = collisionWorld,
	ballSpawns = {},
	rules = simRules,
}

local function refreshRules()
	local modeId = if matchState then matchState:GetAttribute("modeId") :: string? else nil
	local mode = if modeId then ModeRegistry.get(modeId) else nil
	simRules.preserveDodgeballs = mode ~= nil and mode.rules.PreserveDodgeballs == true
end

local velocityHistory: { [string]: { SimTypes.Vec } } = {}

local function sampleConsistency(id: string, velocity: SimTypes.Vec): number
	local samples = velocityHistory[id]
	if samples == nil then
		samples = {}
		velocityHistory[id] = samples
	end
	table.insert(samples, velocity)
	if #samples > MobileInput.Assist.VelocitySamples then
		table.remove(samples, 1)
	end
	return Intercept.consistency(samples)
end

local function buildSnapshot(entries: { [string]: CharacterEntry }, excluded: { Instance }): SimTypes.WorldSnapshot
	local capsule = Combat.CharacterCapsule
	local characters: { [string]: SimTypes.CharacterSnapshot } = {}
	raycastParams.FilterDescendantsInstances = excluded
	for id, entry in entries do
		characters[id] = {
			position = entry.root.CFrame.Position,
			handPosition = heldBallPosition(entry),
			throwPosition = throwPosition(entry),
			velocity = entry.root.AssemblyLinearVelocity,
			height = capsule.Height,
			radius = capsule.Radius,
			alive = entry.model:GetAttribute("CombatAlive") ~= false,
			teamId = entry.model:GetAttribute("TeamId") :: string?,
			invulnerable = entry.model:GetAttribute("minv") == true,
			velocityConsistency = sampleConsistency(id, entry.root.AssemblyLinearVelocity),
		}
	end
	for id in velocityHistory do
		if entries[id] == nil then
			velocityHistory[id] = nil
		end
	end

	worldSnapshot.characters = characters
	refreshRules()
	return worldSnapshot
end

local STEP_SECONDS = 1 / 60
local MAX_CATCHUP_STEPS = 8

local droppedSeconds = 0

type Intent = {
	playerId: string,
	kind: SimTypes.CommandKind,
	aimDir: Vector3,
	targetId: string?,
	charge: number?,
	sequence: number?,
}

local pendingIntents = IntentQueue.new(Combat.Network.MaxQueuedIntentsPerPlayer)
local pendingEquips: { [string]: string } = {}

local function queueEquip(player: Player, weapon: string)
	if player:GetAttribute("ArenaReady") ~= true or player:GetAttribute("ArenaRoundEligible") == false then
		return
	end
	pendingEquips[PlayerIds.toId(player)] = weapon
end

local function queueIntent(
	player: Player,
	kind: SimTypes.CommandKind,
	aimDir: Vector3,
	targetId: string?,
	charge: number?
)
	if player:GetAttribute("ArenaReady") ~= true or player:GetAttribute("ArenaRoundEligible") == false then
		return
	end
	pendingIntents.push(PlayerIds.toId(player), {
		playerId = PlayerIds.toId(player),
		kind = kind,
		aimDir = aimDir,
		targetId = targetId,
		charge = charge,
	})
end

local function buildCommands(entries: { [string]: CharacterEntry }): { InputCommand }
	local commands: { InputCommand } = {}
	local active = matchState ~= nil and matchState:GetAttribute("phase") == "Active"
	local intents = pendingIntents.drain()

	for playerId, weapon in pendingEquips do
		if entries[playerId] ~= nil then
			table.insert(commands, { playerId = playerId, kind = "Equip", weapon = weapon })
		end
	end
	table.clear(pendingEquips)

	for _, intent in if active then intents else {} do
		local entry = entries[intent.playerId]
		if entry == nil or entry.model:GetAttribute("CombatAlive") == false then
			continue
		end
		local aimDir = vector.normalize(intent.aimDir)
		local deviceClass = (entry.player:GetAttribute("DeviceClass") :: string?) or "Mouse"
		local projected = entry.player:FindFirstChild(PlayerAssist.FolderName)
		local assistFolder = if projected and projected:IsA("Folder") then projected else nil
		table.insert(commands, {
			playerId = intent.playerId,
			kind = intent.kind,
			sequence = intent.sequence,
			aimOrigin = entry.root.CFrame.Position + aimDir * 2,
			aimDir = aimDir,
			targetId = intent.targetId,
			charge = intent.charge,
			deviceClass = deviceClass,
			assist = AssistProjection.strengths(assistFolder, deviceClass),
		})
	end
	return commands
end

local function step(dt: number)
	local ballsFolder = Workspace:FindFirstChild(BALLS_FOLDER_NAME)
	if ballsFolder == nil then
		return
	end

	local entries, excluded = collectCharacters()
	table.insert(excluded, ballsFolder)
	for id, entry in entries do
		if entry.model:GetAttribute("CombatAlive") == false then
			MovementGuard.reset(entry.root)
		elseif not MovementGuard.check(entry.root, excluded) then
			pendingIntents.forget(id)
			pendingEquips[id] = nil
			entries[id] = nil
		end
	end

	local characterModels: { [string]: Model } = {}
	for id, entry in entries do
		characterModels[id] = entry.model
	end

	local snapshot = buildSnapshot(entries, excluded)
	local state = SimStateCodec.decode(ballsFolder, characterModels)
	for playerId in pendingWeaponResets do
		local playerState = state.players[playerId]
		if playerState then
			for _, kit in WeaponRegistry.all() do
				playerState.weapons[kit.kind] = kit.init()
			end
			pendingWeaponResets[playerId] = nil
		end
	end
	local commands = buildCommands(entries)

	local events = SimCore.step(state, commands, snapshot, dt)

	MovementSpeedService.step(state, characterModels, events)
	SimStateCodec.encode(state, ballsFolder, characterModels)
	dispatch(events)
	for _, batch in CombatEventPackets.encode(events) do
		Network.fire("CombatSimEvent", nil, batch)
	end
end

function ServerAuthAdapter.resetWeaponsForAdmin(player: Player): boolean
	if player.Parent ~= Players then
		return false
	end
	pendingWeaponResets[PlayerIds.toId(player)] = true
	return true
end

function ServerAuthAdapter.start()
	if started then
		return
	end
	started = true
	if not RunService:IsServer() then
		return
	end

	local resolvedMatchState = ReplicatedStorage:WaitForChild("MatchState")
	assert(resolvedMatchState:IsA("Folder"), "[ServerAuthAdapter] ReplicatedStorage.MatchState must be a Folder")
	matchState = resolvedMatchState

	Players.PlayerRemoving:Connect(function(player)
		local id = PlayerIds.toId(player)
		pendingWeaponResets[id] = nil
		pendingEquips[id] = nil
		pendingIntents.forget(id)
	end)

	Network.handleProtected("SubmitWeaponEquip", {
		rateLimit = 10,
		validate = function(_player, weapon)
			if typeof(weapon) ~= "string" or not WeaponRegistry.isKind(weapon) then
				return false, "invalid_weapon"
			end
			return true
		end,
	}, function(player, weapon)
		queueEquip(player, weapon)
	end)

	Network.handleProtected("SubmitCombatInput", {
		rateLimit = 20,
		validate = function(_player, kind, aimDir, targetId, charge, lob)
			if kind ~= "Throw" and kind ~= "Catch" and kind ~= "BeginCharge" and kind ~= "CancelCharge" then
				return false, "invalid_kind"
			end
			if typeof(aimDir) ~= "Vector3" then
				return false, "invalid_aim"
			end
			local magnitude = vector.magnitude(aimDir)
			if magnitude ~= magnitude or magnitude <= 1e-6 or magnitude == math.huge then
				return false, "invalid_aim"
			end
			if targetId ~= nil and (typeof(targetId) ~= "string" or #targetId == 0 or #targetId > 32) then
				return false, "invalid_target"
			end
			if charge ~= nil and (typeof(charge) ~= "number" or charge ~= charge or charge < 0 or charge > 1) then
				return false, "invalid_charge"
			end
			if lob ~= nil then
				return false, "invalid_lob"
			end
			return true
		end,
	}, queueIntent)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local wanted = accumulator + deltaTime
		accumulator = math.min(wanted, STEP_SECONDS * MAX_CATCHUP_STEPS)
		droppedSeconds += math.max(wanted - accumulator, 0)
		while accumulator >= STEP_SECONDS do
			accumulator -= STEP_SECONDS
			step(STEP_SECONDS)
		end
	end)
end

function ServerAuthAdapter.takeDroppedMilliseconds(): number
	local value = droppedSeconds * 1000
	droppedSeconds = 0
	return value
end

function ServerAuthAdapter.takeRejectedInputs(): number
	return pendingIntents.takeRejected()
end

return ServerAuthAdapter
