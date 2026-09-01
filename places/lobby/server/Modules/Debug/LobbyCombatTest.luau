-- Name: LobbyCombatTest.luau
-- Author: Jack C.
-- Description: Studio-only lobby combat/cosmetics test session. Brings a developer into the real combat stack on the Workspace baseplate with stationary respawning dummies and both weapons, judging hits against the real weapon geometry (dummies are not simulation entities) and broadcasting the same Elim/HammerHit sim events the arena emits so equipped cosmetics render through the identical presentation path. Gated to Studio and never runs live.
-- Created: 2026-08-31

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Debug = require(Config:WaitForChild("Debug"))
local CombatConfig = require(Config:WaitForChild("Combat"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local SharedGame = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local OnboardingHit = require(SharedGame:WaitForChild("Onboarding"):WaitForChild("OnboardingHit"))
local PlayerIds = require(SharedGame:WaitForChild("Adapters"):WaitForChild("PlayerIds"))
local ServerAuthAdapter = require(SharedGame:WaitForChild("Adapters"):WaitForChild("ServerAuthAdapter"))

local Onboarding = script.Parent.Parent:WaitForChild("Onboarding")
local OnboardingCombat = require(Onboarding:WaitForChild("OnboardingCombat"))
local OnboardingDummies = require(Onboarding:WaitForChild("OnboardingDummies"))
local OnboardingService = require(Onboarding:WaitForChild("OnboardingService"))

type Dummy = OnboardingDummies.Dummy
type BallSample = {
	ball: BasePart,
	previous: Vector3,
	current: Vector3,
	velocity: Vector3,
	ownerId: string?,
}
type Session = {
	player: Player,
	slots: { CFrame },
	dummies: { [number]: Dummy },
	active: boolean,
	generation: number,
}

local LobbyCombatTest = {}

local PHASE_IN_FLIGHT = 2
local PHASE_BOUNCING = 3

local DUMMY_COUNT = 5
local ARC_RADIUS_STUDS = 24
local ARC_SPREAD_DEG = 90
local SPAWN_CLEARANCE_STUDS = 5
local TARGET_LENIENCY_STUDS = 2
local RESPAWN_SECONDS = 1.2
local CONTAINER_NAME = "LobbyCombatTestDummies"

local started = false
local sessions: { [Player]: Session } = {}
local ballPositions: { [BasePart]: Vector3 } = {}

local function enabled(): boolean
	return Debug.LobbyCombatTest == true and RunService:IsStudio()
end

local function container(): Folder
	local existing = Workspace:FindFirstChild(CONTAINER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	folder.Parent = Workspace
	return folder
end

local function baseplate(): BasePart
	local part = Workspace:WaitForChild("Baseplate")
	assert(part:IsA("BasePart"), "[LobbyCombatTest] Workspace.Baseplate must be a BasePart")
	return part
end

local function standingDummies(session: Session): { Dummy }
	local standing: { Dummy } = {}
	for _, dummy in session.dummies do
		if OnboardingDummies.isStanding(dummy) then
			table.insert(standing, dummy)
		end
	end
	return standing
end

local function ballsFolder(): Folder?
	local folder = Workspace:FindFirstChild("Balls")
	return if folder and folder:IsA("Folder") then folder else nil
end

-- Balls are shared world state, so they are sampled once per frame across every
-- session. Sampling per session would compare a ball against itself and collapse
-- the swept segment the contact test depends on.
local function sampleBalls(): { BallSample }
	local folder = ballsFolder()
	if folder == nil then
		table.clear(ballPositions)
		return {}
	end
	local samples: { BallSample } = {}
	local live: { [BasePart]: boolean } = {}
	for _, ball in folder:GetChildren() do
		if not ball:IsA("BasePart") then
			continue
		end
		live[ball] = true
		local current = ball.CFrame.Position
		local previous = ballPositions[ball] or current
		ballPositions[ball] = current
		local phase = ball:GetAttribute("ph")
		if phase ~= PHASE_IN_FLIGHT and phase ~= PHASE_BOUNCING then
			continue
		end
		local velocity = ball:GetAttribute("vel")
		table.insert(samples, {
			ball = ball,
			previous = previous,
			current = current,
			velocity = if typeof(velocity) == "Vector3" then velocity else Vector3.zero,
			ownerId = ball:GetAttribute("ow") :: string?,
		})
	end
	for ball in ballPositions do
		if not live[ball] then
			ballPositions[ball] = nil
		end
	end
	return samples
end

-- The dummies are not simulation entities, so a hit on one is broadcast as the
-- same event the sim would emit for a real elimination. It reaches only the
-- acting player's client, which renders it through the identical BallVisuals /
-- HammerVisuals / GameAudio / CosmeticEffects path the arena uses. The tick is a
-- unique sequence so the consumers' dedup key never collapses two distinct hits
-- (every dummy shares one model name, and one ball can down several in a row).
local eventSequence = 0
local function broadcastImpact(player: Player, event: { [string]: any })
	eventSequence += 1
	event.tick = eventSequence
	Network.fire("CombatSimEvent", player, { event })
end

local function slotFor(session: Session, dummy: Dummy): number?
	for slot, current in session.dummies do
		if current == dummy then
			return slot
		end
	end
	return nil
end

local function respawnSlot(session: Session, slot: number)
	local generation = session.generation
	task.delay(RESPAWN_SECONDS, function()
		if sessions[session.player] ~= session or not session.active or session.generation ~= generation then
			return
		end
		local existing = session.dummies[slot]
		if existing then
			OnboardingDummies.destroy(existing)
		end
		session.dummies[slot] =
			OnboardingDummies.spawn(session.slots[slot], container(), 0, PlayerIds.toId(session.player))
	end)
end

local function knockDummy(session: Session, dummy: Dummy, fromPosition: Vector3)
	if not OnboardingDummies.isStanding(dummy) then
		return
	end
	local slot = slotFor(session, dummy)
	OnboardingDummies.knock(dummy, fromPosition)
	if slot ~= nil then
		respawnSlot(session, slot)
	end
end

local function targetRadius(dummy: Dummy): number
	return dummy.radius + TARGET_LENIENCY_STUDS
end

local function detectBallHits(session: Session, samples: { BallSample })
	local playerId = PlayerIds.toId(session.player)
	for _, sample in samples do
		if sample.ownerId ~= playerId then
			continue
		end
		local direction = if sample.velocity.Magnitude > 1e-6 then sample.velocity.Unit else nil
		for _, dummy in standingDummies(session) do
			local at = OnboardingDummies.position(dummy)
			if OnboardingHit.ballReachedTarget(sample.previous, sample.current, at, targetRadius(dummy)) then
				knockDummy(session, dummy, sample.current)
				broadcastImpact(session.player, {
					kind = "Elim",
					projectileId = sample.ball.Name,
					sourceId = playerId,
					targetId = dummy.model.Name,
					position = at,
					direction = direction,
				})
			end
		end
	end
end

-- A hammer swing is authoritative and carries its own origin and direction, which
-- is enough to re-run the real weapon cone against each dummy.
local function onSimEvent(event: { [string]: any })
	if event.kind ~= "HammerSwing" then
		return
	end
	local player = PlayerIds.fromEvent(event)
	local session = if player then sessions[player] else nil
	if session == nil or not session.active then
		return
	end
	local origin, direction = event.position, event.direction
	if origin == nil or direction == nil then
		return
	end
	local dirVector = if typeof(direction) == "Vector3"
		then direction
		else Vector3.new(direction.x, direction.y, direction.z)
	for _, dummy in standingDummies(session) do
		local at = OnboardingDummies.position(dummy)
		if OnboardingHit.withinHammerCone(origin, direction, at, targetRadius(dummy), CombatConfig.Hammer) then
			knockDummy(session, dummy, if typeof(origin) == "Vector3" then origin else at)
			local sourceId = PlayerIds.toId(session.player)
			broadcastImpact(session.player, {
				kind = "HammerHit",
				projectileId = nil,
				playerId = sourceId,
				sourceId = sourceId,
				targetId = dummy.model.Name,
				position = at,
				direction = dirVector,
			})
			-- One swing takes one target, matching the sim's own resolution.
			return
		end
	end
end

local function buildSlots(surfaceY: number, spawnPosition: Vector3): { CFrame }
	local slots: { CFrame } = {}
	local spread = math.rad(ARC_SPREAD_DEG)
	local centre = Vector3.new(spawnPosition.X, surfaceY, spawnPosition.Z)
	for index = 1, DUMMY_COUNT do
		local fraction = if DUMMY_COUNT > 1 then (index - 1) / (DUMMY_COUNT - 1) - 0.5 else 0
		local angle = fraction * spread
		local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * ARC_RADIUS_STUDS
		local position = centre + offset
		slots[index] = if (centre - position).Magnitude > 1e-3
			then CFrame.lookAt(position, Vector3.new(centre.X, position.Y, centre.Z))
			else CFrame.new(position)
	end
	return slots
end

local function enter(player: Player)
	if sessions[player] ~= nil then
		return
	end
	if OnboardingService.isActive(player) then
		return
	end
	local character = OnboardingCombat.ensureCharacter(player)
	if character == nil then
		return
	end
	OnboardingCombat.admit(player)

	local plate = baseplate()
	local surfaceY = plate.Position.Y + plate.Size.Y * 0.5
	local spawnPosition = Vector3.new(plate.Position.X, surfaceY + SPAWN_CLEARANCE_STUDS, plate.Position.Z)
	-- The player faces the arc, which is built one radius out along the same axis.
	character:PivotTo(CFrame.lookAt(spawnPosition, spawnPosition + Vector3.new(0, 0, 1)))

	local session: Session = {
		player = player,
		slots = buildSlots(surfaceY, spawnPosition),
		dummies = {},
		active = true,
		generation = 0,
	}
	sessions[player] = session

	local ownerId = PlayerIds.toId(player)
	for index = 1, DUMMY_COUNT do
		session.dummies[index] = OnboardingDummies.spawn(session.slots[index], container(), 0, ownerId)
	end

	OnboardingCombat.grantBall(player)
	Network.fire("LobbyCombatTest", player, { active = true })
end

local function exit(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	session.active = false
	session.generation += 1
	for _, dummy in session.dummies do
		OnboardingDummies.destroy(dummy)
	end
	table.clear(session.dummies)
	sessions[player] = nil
	OnboardingCombat.release(player)
	Network.fire("LobbyCombatTest", player, { active = false })
end

function LobbyCombatTest.start()
	if started then
		return
	end
	if not enabled() then
		return
	end
	started = true

	local folder = Workspace:FindFirstChild(CONTAINER_NAME)
	if folder then
		folder:Destroy()
	end

	ServerAuthAdapter.onEvent(onSimEvent)

	RunService.Heartbeat:Connect(function()
		if next(sessions) == nil then
			return
		end
		local samples = sampleBalls()
		for _, session in sessions do
			if session.active then
				detectBallHits(session, samples)
			end
		end
	end)

	Network.handleProtected("LobbyCombatTest", {
		rateLimit = 4,
		validate = function(_player, action)
			if not enabled() then
				return false, "disabled"
			end
			if typeof(action) ~= "string" then
				return false, "invalid_action"
			end
			return true
		end,
	}, function(player, action)
		if action == "Toggle" then
			if sessions[player] then
				exit(player)
			else
				enter(player)
			end
		elseif action == "Enter" then
			enter(player)
		elseif action == "Exit" then
			exit(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if sessions[player] then
			exit(player)
		end
	end)
end

return LobbyCombatTest
