--!strict

local Players = game:GetService("Players")
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

type SimEvent = SimTypes.SimEvent
type InputCommand = SimTypes.InputCommand

-- Server-authority backend: one BindToSimulation callback, initialized on both
-- client and server, that decodes SimState from predicted instances, reads
-- InputActions, runs the pure SimCore step, and encodes the result back.
-- The engine owns prediction, rollback, and resimulation.

local ServerAuthAdapter = {}

local BALLS_FOLDER_NAME = "Balls"

local listeners: { (SimEvent) -> () } = {}
local pendingWeaponResets: { [string]: boolean } = {}
local started = false

local function sideTag(): string
	return if RunService:IsServer() then "S" else "C"
end

local function trace(message: string)
	if Debug.CombatTrace then
		print(`[Combat/{sideTag()}] {message}`)
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

local function buildSnapshot(entries: { [string]: CharacterEntry }, excluded: { Instance }): SimTypes.WorldSnapshot
	local capsule = Combat.CharacterCapsule
	local characters: { [string]: SimTypes.CharacterSnapshot } = {}
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

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	-- Gameplay traces ignore non-collidable geometry (invisible markers,
	-- decorative no-clip parts); raycasts hit them by default otherwise.
	params.RespectCanCollide = true

	local collision: SimTypes.CollisionWorld = {
		sweepSphere = function(origin, displacement, radius)
			local distance = vector.magnitude(displacement)
			if distance <= 1e-6 then
				return nil
			end
			local result = Workspace:Spherecast(origin, radius, displacement, params)
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

	-- World ball spawning happens outside the sim (BallSpawner); the sim never
	-- sees spawn points under this backend.
	return { characters = characters, collision = collision, ballSpawns = {} }
end

-- Bool action edges are detected against the previous tick's state, stored as
-- attributes on the character so rollback restores them correctly.
local function readEdge(action: InputAction, model: Model, attrName: string): boolean
	local now = action:GetState() == true
	local previous = model:GetAttribute(attrName) == true
	if model:GetAttribute(attrName) ~= now then
		model:SetAttribute(attrName, now)
	end
	return now and not previous
end

local function collectCommands(entries: { [string]: CharacterEntry }): { InputCommand }
	local commands: { InputCommand } = {}
	for id, entry in entries do
		if entry.model:GetAttribute("CombatAlive") == false then
			continue
		end
		local context = entry.player:FindFirstChild(InputConfig.ContextName)
		if context == nil then
			continue
		end
		local throwAction = context:FindFirstChild("Throw")
		local aimAction = context:FindFirstChild("Aim")
		if throwAction == nil or aimAction == nil then
			continue
		end

		local throwEdge = readEdge(throwAction :: InputAction, entry.model, "prevThrow")

		if throwEdge then
			local aimDir = (aimAction :: InputAction):GetState()
			if typeof(aimDir) == "Vector3" and vector.magnitude(aimDir) > 1e-6 then
				aimDir = vector.normalize(aimDir)
				-- Throw origin is derived, not client-supplied: nothing to spoof.
				local aimOrigin = entry.root.CFrame.Position + aimDir * 2
				table.insert(commands, {
					playerId = id,
					kind = "Throw" :: SimTypes.CommandKind,
					aimOrigin = aimOrigin,
					aimDir = aimDir,
					targetId = nil,
					deviceClass = (entry.player:GetAttribute("DeviceClass") :: string?) or "Mouse",
				})
			end
		end
	end
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
	if RunService:IsServer() then
		for playerId in pendingWeaponResets do
			local playerState = state.players[playerId]
			if playerState then
				for _, kit in WeaponRegistry.all() do
					playerState.weapons[kit.kind] = kit.init()
				end
				pendingWeaponResets[playerId] = nil
			end
		end
	end
	local commands = collectCommands(entries)

	local events = SimCore.step(state, commands, snapshot, dt)

	MovementSpeedService.step(state, characterModels, events)
	SimStateCodec.encode(state, ballsFolder, characterModels)
	dispatch(events)
end

function ServerAuthAdapter.resetWeaponsForTesting(player: Player): boolean
	if not RunService:IsServer() or player.Parent ~= Players then
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
	if RunService:IsServer() then
		Players.PlayerRemoving:Connect(function(player)
			pendingWeaponResets[PlayerIds.toId(player)] = nil
		end)
	end

	local runService: any = RunService
	if typeof(runService.BindToSimulation) ~= "function" then
		warn("[ServerAuthAdapter] BindToSimulation unavailable — enable the Server Authority settings in Studio")
		return
	end
	runService:BindToSimulation(step)
	print(`[ServerAuthAdapter] simulation bound ({if RunService:IsServer() then "server" else "client"})`)
end

return ServerAuthAdapter
