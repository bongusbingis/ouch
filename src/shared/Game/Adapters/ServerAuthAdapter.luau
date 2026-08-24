--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SimTypes = require(script.Parent.Parent.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Sim.SimCore)
local SimStateCodec = require(script.Parent.SimStateCodec)
local PlayerIds = require(script.Parent.PlayerIds)
local AssistProjection = require(script.Parent.Parent.Config.AssistProjection)
local PlayerAssist = require(script.Parent.Parent.Parent.Parent.Config.PlayerAssist)
local MobileInput = require(script.Parent.Parent.Parent.Parent.Config.MobileInput)
local Intercept = require(script.Parent.Parent.Sim.Intercept)
local MovementSpeedService = require(script.Parent.MovementSpeedService)
local WeaponRegistry = require(script.Parent.Parent.Sim.WeaponRegistry)
local ModeRegistry = require(script.Parent.Parent.Modes.ModeRegistry)
local Combat = require(script.Parent.Parent.Parent.Parent.Config.Combat)
local InputConfig = require(script.Parent.Parent.Parent.Parent.Config.Input)
local Debug = require(script.Parent.Parent.Parent.Parent.Config.Debug)
local Network = require(script.Parent.Parent.Parent.Network)

type SimEvent = SimTypes.SimEvent
type InputCommand = SimTypes.InputCommand

-- The single bridge between the pure sim and the engine. The server is the only
-- simulator: it consumes throw/catch intents, runs SimCore on a fixed tick, and
-- encodes the result onto the ball instances that replicate to clients.
--
-- Clients send intent only. Every raycast, hit test, catch, and elimination is
-- resolved here from server-known character positions, and the aim origin is
-- taken from the player's own root rather than anything the client supplied, so
-- a client can never report having hit or been hit by anything.

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
		if (admission ~= "Direct" and admission ~= "Matched") or player:GetAttribute("ArenaReady") ~= true then
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

local function socketPosition(entry: CharacterEntry, offset: vector): Vector3
	return (entry.root.CFrame * CFrame.new(offset.x, offset.y, offset.z)).Position
end

local function heldBallPosition(entry: CharacterEntry): Vector3
	local hand = entry.model:FindFirstChild("RightHand") or entry.model:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand.CFrame.Position
	end
	return entry.root.CFrame.Position
end

-- Parts whose transform is driven by the animator. A release socket parented to
-- one of these would make the gameplay launch point depend on which frame of the
-- throw animation happens to be playing, which is exactly the coupling the
-- projectile is kept clear of.
local ANIMATED_PARENTS = {
	RightHand = true,
	RightLowerArm = true,
	RightUpperArm = true,
	LeftHand = true,
	LeftLowerArm = true,
	LeftUpperArm = true,
	Head = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
}

-- Resolved once per character rather than searched every tick: a recursive
-- descendant search at 60Hz per player is pure waste, and caching also gives one
-- place to validate the socket. Weak keys so a respawned character's entry is
-- collected with the old model instead of accumulating one row per death.
local releaseSockets: { [Model]: Attachment | false } = setmetatable({}, { __mode = "k" }) :: any

local function releaseSocket(model: Model): Attachment?
	local cached = releaseSockets[model]
	if cached ~= nil then
		return if cached then cached else nil
	end

	local found = model:FindFirstChild("DodgeballReleaseSocket", true)
	if found == nil or not found:IsA("Attachment") then
		releaseSockets[model] = false
		return nil
	end

	local parent = found.Parent
	if parent and ANIMATED_PARENTS[parent.Name] then
		warn(
			"[ServerAuthAdapter] DodgeballReleaseSocket is parented to "
				.. parent.Name
				.. ", which the animator drives. Move it to HumanoidRootPart or a torso part;"
				.. " falling back to the configured root offset."
		)
		releaseSockets[model] = false
		return nil
	end

	releaseSockets[model] = found
	return found
end

-- The authoritative launch point. Deliberately derived from the character's root
-- (or a socket rigidly attached to it), never from the animated hand: gameplay
-- must not change because an animation is a few frames further along, or because
-- one player's animation is a different length from another's. The held ball is
-- drawn at the hand separately, which is what sells the throw visually.
local function throwPosition(entry: CharacterEntry): Vector3
	local socket = releaseSocket(entry.model)
	if socket then
		return socket.WorldPosition
	end
	return socketPosition(entry, Combat.Dodgeball.OverhandReleaseRootOffset)
end

-- Allocated once and reused every tick. At 60Hz a fresh RaycastParams, closure,
-- and snapshot table per step is pure GC churn; only their contents change.
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
-- Gameplay traces ignore non-collidable geometry (invisible markers, decorative
-- no-clip parts); raycasts hit them by default otherwise.
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
		-- SweepHit.position is the sphere center at contact, matching the
		-- mock-world semantics the sim is tested against.
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

-- Resolves the sim-facing rules from whichever mode is running, read off the
-- replicated MatchState rather than from MatchService, so the adapter keeps no
-- dependency on match orchestration. Between matches there is no mode and the
-- rules fall back to the pre-mode behaviour: balls settle as world pickups.
local function refreshRules()
	local modeId = if matchState then matchState:GetAttribute("modeId") :: string? else nil
	local mode = if modeId then ModeRegistry.get(modeId) else nil
	simRules.preserveDodgeballs = mode ~= nil and mode.rules.PreserveDodgeballs == true
end

-- Rolling window of each character's velocity, kept here rather than in SimState
-- because it is a measurement of the engine world, not a sim decision, and the
-- sim must stay a pure function of the snapshot it is handed.
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
			-- CombatAlive is the single source of truth for aliveness (custom
			-- elimination flow; native Humanoid health is not used).
			alive = entry.model:GetAttribute("CombatAlive") ~= false,
			teamId = entry.model:GetAttribute("TeamId") :: string?,
			-- Spawn protection flag, set by MatchService on the character model.
			invulnerable = entry.model:GetAttribute("minv") == true,
			velocityConsistency = sampleConsistency(id, entry.root.AssemblyLinearVelocity),
		}
	end
	for id in velocityHistory do
		if entries[id] == nil then
			velocityHistory[id] = nil
		end
	end

	-- World ball spawning happens outside the sim (BallSpawner); the sim never
	-- sees spawn points under this backend.
	worldSnapshot.characters = characters
	refreshRules()
	return worldSnapshot
end

local STEP_SECONDS = 1 / 60
local MAX_QUEUED_INTENTS = 16
local MAX_CATCHUP_STEPS = 8

local droppedSeconds = 0

type Intent = {
	playerId: string,
	kind: SimTypes.CommandKind,
	aimDir: Vector3,
	targetId: string?,
	charge: number?,
}

local pendingIntents: { Intent } = {}
-- Equip requests are kept apart from aimed intents: they carry no aim, and they
-- are a preference rather than an action, so they are not subject to the queue
-- cap that protects the action path from flooding.
local pendingEquips: { [string]: string } = {}

local function queueEquip(player: Player, weapon: string)
	if player:GetAttribute("ArenaReady") ~= true then
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
	if player:GetAttribute("ArenaReady") ~= true then
		return
	end
	if #pendingIntents >= MAX_QUEUED_INTENTS then
		return
	end
	table.insert(pendingIntents, {
		playerId = PlayerIds.toId(player),
		kind = kind,
		aimDir = aimDir,
		targetId = targetId,
		charge = charge,
	})
end

-- Intents become commands only against a live character the server can see, and
-- the origin is derived from that character rather than sent by the client.
local function buildCommands(entries: { [string]: CharacterEntry }): { InputCommand }
	local commands: { InputCommand } = {}
	local active = matchState ~= nil and matchState:GetAttribute("phase") == "Active"
	if not active then
		table.clear(pendingIntents)
	end

	-- Equips survive the phase gate above on purpose: an inactive match discards
	-- queued attacks, but choosing a slot during the countdown is exactly when a
	-- player wants to, and it changes nothing in the world until they attack.
	for playerId, weapon in pendingEquips do
		if entries[playerId] ~= nil then
			table.insert(commands, { playerId = playerId, kind = "Equip", weapon = weapon })
		end
	end
	table.clear(pendingEquips)

	for _, intent in pendingIntents do
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
			aimOrigin = entry.root.CFrame.Position + aimDir * 2,
			aimDir = aimDir,
			-- Only a proposal: validateTarget re-checks it server-side against the
			-- wider validation cone and falls back to an unguided throw.
			targetId = intent.targetId,
			charge = intent.charge,
			deviceClass = deviceClass,
			-- Read from the same projection the client reads, so an assist can
			-- never be stronger on one side than the other.
			assist = AssistProjection.strengths(assistFolder, deviceClass),
		})
	end
	table.clear(pendingIntents)
	return commands
end

local function step(dt: number)
	local ballsFolder = Workspace:FindFirstChild(BALLS_FOLDER_NAME)
	if ballsFolder == nil then
		-- Client before first replication, or server before BallSpawner ran.
		return
	end

	local entries, excluded = collectCharacters()
	table.insert(excluded, ballsFolder)

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
	if #events > 0 then
		Network.fire("CombatSimEvent", nil, events)
	end
end

function ServerAuthAdapter.resetWeaponsForTesting(player: Player): boolean
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
		for index = #pendingIntents, 1, -1 do
			if pendingIntents[index].playerId == id then
				table.remove(pendingIntents, index)
			end
		end
	end)

	Network.handleProtected("SubmitWeaponEquip", {
		-- Generous: this is a HUD slot a player may flick between, and a rejected
		-- equip leaves them holding a weapon they did not choose.
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
			if kind ~= "Throw" and kind ~= "Catch" then
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
			-- Charge is clamped again in the kit; rejecting garbage here keeps a
			-- NaN from ever reaching the sim.
			if charge ~= nil and (typeof(charge) ~= "number" or charge ~= charge or charge < 0 or charge > 1) then
				return false, "invalid_charge"
			end
			-- The lob throw no longer exists anywhere in the sim. Rejecting the
			-- argument outright means an old client cannot reach a throw style
			-- the game no longer has, rather than having it silently ignored.
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
		-- Time past the clamp is discarded, not deferred, so the simulation ends
		-- up permanently behind wall clock and every cooldown stretches. The
		-- clamp is correct -- without it a long hitch spirals into catch-up --
		-- but it used to fail silently. Counting it makes the regression visible.
		droppedSeconds += math.max(wanted - accumulator, 0)
		while accumulator >= STEP_SECONDS do
			accumulator -= STEP_SECONDS
			step(STEP_SECONDS)
		end
	end)
end

-- Simulation time discarded by the catch-up clamp since the last read, in
-- milliseconds. Reading resets it, so each report covers one interval and two
-- consumers cannot double-count the same hitch.
function ServerAuthAdapter.takeDroppedMilliseconds(): number
	local value = droppedSeconds * 1000
	droppedSeconds = 0
	return value
end

return ServerAuthAdapter
