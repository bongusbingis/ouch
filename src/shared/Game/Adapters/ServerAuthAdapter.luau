--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SimTypes = require(script.Parent.Parent.Sim.SimTypes)
local SimCore = require(script.Parent.Parent.Sim.SimCore)
local SimStateCodec = require(script.Parent.SimStateCodec)
local PlayerIds = require(script.Parent.PlayerIds)
local MovementSpeedService = require(script.Parent.MovementSpeedService)
local WeaponRegistry = require(script.Parent.Parent.Sim.WeaponRegistry)
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
		if player:GetAttribute("ArenaAdmission") == "Rejected" then
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

local function throwPosition(entry: CharacterEntry): Vector3
	local release = entry.model:FindFirstChild("DodgeballReleaseSocket", true)
	if release and release:IsA("Attachment") then
		return release.WorldPosition
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

local worldSnapshot: SimTypes.WorldSnapshot = {
	characters = {},
	collision = collisionWorld,
	ballSpawns = {},
}

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
		}
	end

	-- World ball spawning happens outside the sim (BallSpawner); the sim never
	-- sees spawn points under this backend.
	worldSnapshot.characters = characters
	return worldSnapshot
end

local STEP_SECONDS = 1 / 60
local MAX_QUEUED_INTENTS = 16

type Intent = { playerId: string, kind: SimTypes.CommandKind, aimDir: Vector3 }

local pendingIntents: { Intent } = {}

local function queueIntent(player: Player, kind: SimTypes.CommandKind, aimDir: Vector3)
	if #pendingIntents >= MAX_QUEUED_INTENTS then
		return
	end
	table.insert(pendingIntents, { playerId = PlayerIds.toId(player), kind = kind, aimDir = aimDir })
end

-- Intents become commands only against a live character the server can see, and
-- the origin is derived from that character rather than sent by the client.
local function buildCommands(entries: { [string]: CharacterEntry }): { InputCommand }
	local commands: { InputCommand } = {}
	if matchState == nil or matchState:GetAttribute("phase") ~= "Active" then
		table.clear(pendingIntents)
		return commands
	end

	for _, intent in pendingIntents do
		local entry = entries[intent.playerId]
		if entry == nil or entry.model:GetAttribute("CombatAlive") == false then
			continue
		end
		local aimDir = vector.normalize(intent.aimDir)
		table.insert(commands, {
			playerId = intent.playerId,
			kind = intent.kind,
			aimOrigin = entry.root.CFrame.Position + aimDir * 2,
			aimDir = aimDir,
			targetId = nil,
			deviceClass = (entry.player:GetAttribute("DeviceClass") :: string?) or "Mouse",
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

	Network.handleProtected("SubmitCombatInput", {
		rateLimit = 20,
		validate = function(_player, kind, aimDir)
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
			return true
		end,
	}, queueIntent)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		accumulator = math.min(accumulator + deltaTime, STEP_SECONDS * 8)
		while accumulator >= STEP_SECONDS do
			accumulator -= STEP_SECONDS
			step(STEP_SECONDS)
		end
	end)
end

return ServerAuthAdapter
