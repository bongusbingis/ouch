-- Name: Hammer.luau
-- Author: Jack C.
-- Description: The inflatable hammer weapon kit: a cooldown, active dash, and recovery phase machine plus the closest-target-in-front hit resolution and assisted swing turning.
-- Created: 2026-07-13

--!strict

local Sim = script.Parent.Parent
local SimTypes = require(Sim.SimTypes)
local SimUtil = require(Sim.SimUtil)
local WeaponKit = require(Sim.WeaponKit)
local Combat = require(Sim.Parent.Parent.Parent.Config.Combat)
local MobileInput = require(Sim.Parent.Parent.Parent.Config.MobileInput)
local TargetSelect = require(Sim.TargetSelect)

type Vec = SimTypes.Vec
type SimState = SimTypes.SimState
type WorldSnapshot = SimTypes.WorldSnapshot
type InputCommand = SimTypes.InputCommand
type SimEvent = SimTypes.SimEvent

type KitState = {
	cooldown: number,
	activeRemaining: number,
	recoveryRemaining: number,
	stunRemaining: number,
	direction: Vec?,
	hitTargetId: string?,
}

local Hammer = {}
Hammer.kind = "Hammer"
Hammer.commands = { Throw = true } :: { [SimTypes.CommandKind]: boolean }

local function config()
	return Combat.Hammer
end

local function horizontal(direction: Vec): Vec?
	local flat = vector.create(direction.x, 0, direction.z)
	local magnitude = vector.magnitude(flat)
	if magnitude <= 1e-4 then
		return nil
	end
	return flat / magnitude
end

local function assistSwing(command: InputCommand, world: WorldSnapshot, origin: Vec, direction: Vec): (Vec, number)
	local cfg = config()
	local assist = MobileInput.Assist
	local autoFace = SimUtil.assistStrength(command, "AutoFace")
	local lunge = SimUtil.assistStrength(command, "Lunge")
	local dashSpeed = cfg.DashSpeed
	if autoFace <= 0 and lunge <= 0 then
		return direction, dashSpeed
	end

	local targetId, confidence = TargetSelect.pick(world, command.playerId, origin, direction, {
		rangeStuds = cfg.Range * assist.MeleeAcquireRangeScale,
		coneDeg = assist.MeleeConeDeg,
		fadeStartFraction = assist.ConeFadeStartFraction,
		lineOfSightRadius = nil,
	})
	if targetId == nil or confidence <= 0 then
		return direction, dashSpeed
	end

	local target = world.characters[targetId]
	local assisted = direction
	if autoFace > 0 then
		local flatTarget = vector.create(target.position.x, origin.y, target.position.z)
		local steered = horizontal(
			TargetSelect.steer(
				direction,
				origin,
				flatTarget,
				autoFace * confidence,
				math.rad(assist.AutoFaceMaxAngleDeg)
			)
		)
		if steered ~= nil then
			assisted = steered
		end
	end

	if lunge > 0 then
		local distance = vector.magnitude(target.position - origin)
		if distance > cfg.Range then
			dashSpeed += assist.LungeMaxExtraSpeed * lunge * confidence
		end
	end
	return assisted, dashSpeed
end

local function findHitTarget(playerId: string, origin: Vec, direction: Vec, world: WorldSnapshot): string?
	local cfg = config()
	local bestId: string? = nil
	local bestForward = math.huge

	for _, targetId in SimUtil.sortedKeys(world.characters) do
		if targetId == playerId or SimUtil.sameTeam(world, playerId, targetId) then
			continue
		end
		local target = world.characters[targetId]
		if not target.alive or target.invulnerable then
			continue
		end

		local offset = target.position - origin
		local forward = vector.dot(offset, direction)
		if forward < 0 or forward > cfg.Range + target.radius then
			continue
		end

		local flatOffset = vector.create(offset.x, 0, offset.z)
		local lateral = vector.magnitude(flatOffset - direction * forward)
		if lateral > cfg.Width * 0.5 + target.radius then
			continue
		end
		if math.abs(offset.y) > cfg.Height * 0.5 then
			continue
		end
		if not SimUtil.hasLineOfSight(world, origin, target, cfg.LineOfSightRadius) then
			continue
		end
		if forward < bestForward then
			bestForward = forward
			bestId = targetId
		end
	end

	return bestId
end

function Hammer.init(): KitState
	return {
		cooldown = 0,
		activeRemaining = 0,
		recoveryRemaining = 0,
		stunRemaining = 0,
		direction = nil,
		hitTargetId = nil,
	}
end

function Hammer.handleInput(
	kitState: KitState,
	state: SimState,
	command: InputCommand,
	world: WorldSnapshot,
	events: { SimEvent }
): boolean
	if command.kind ~= "Throw" then
		return false
	end
	if kitState.cooldown > 0 or kitState.activeRemaining > 0 or kitState.recoveryRemaining > 0 then
		return true
	end
	local character = world.characters[command.playerId]
	local aimDir = command.aimDir
	if character == nil or not character.alive or aimDir == nil then
		return false
	end

	local direction = horizontal(aimDir)
	if direction == nil then
		return false
	end

	local dashSpeed: number
	direction, dashSpeed = assistSwing(command, world, character.position, direction)

	local cfg = config()
	kitState.cooldown = cfg.Cooldown
	kitState.activeRemaining = cfg.ActiveDuration
	kitState.recoveryRemaining = 0
	kitState.stunRemaining = 0
	kitState.direction = direction
	kitState.hitTargetId = nil

	SimUtil.pushEvent(events, state, {
		kind = "HammerSwing",
		tick = 0,
		projectileId = nil,
		playerId = command.playerId,
		sourceId = command.playerId,
		targetId = nil,
		position = character.position,
		normal = nil,
		direction = direction,
		magnitude = dashSpeed,
	})

	return true
end

local function resolveHit(
	kitState: KitState,
	playerId: string,
	state: SimState,
	world: WorldSnapshot,
	events: { SimEvent }
)
	local direction = kitState.direction
	local character = world.characters[playerId]
	if direction == nil or character == nil or not character.alive then
		return
	end

	local targetId = findHitTarget(playerId, character.position, direction, world)
	if targetId == nil then
		return
	end

	kitState.hitTargetId = targetId
	kitState.activeRemaining = 0
	kitState.recoveryRemaining = config().HitRecovery

	SimUtil.pushEvent(events, state, {
		kind = "HammerHit",
		tick = 0,
		projectileId = nil,
		playerId = playerId,
		sourceId = playerId,
		targetId = targetId,
		position = world.characters[targetId].position,
		normal = nil,
		direction = direction,
	})
	SimUtil.pushEvent(events, state, {
		kind = "Elim",
		tick = 0,
		projectileId = nil,
		playerId = playerId,
		sourceId = playerId,
		targetId = targetId,
		position = world.characters[targetId].position,
		normal = nil,
		direction = direction,
	})
end

function Hammer.tickPlayer(
	kitState: KitState,
	playerId: string,
	state: SimState,
	world: WorldSnapshot,
	dt: number,
	events: { SimEvent }
)
	kitState.cooldown = math.max(kitState.cooldown - dt, 0)
	kitState.recoveryRemaining = math.max(kitState.recoveryRemaining - dt, 0)
	kitState.stunRemaining = math.max(kitState.stunRemaining - dt, 0)

	if kitState.activeRemaining <= 0 then
		return
	end

	resolveHit(kitState, playerId, state, world, events)
	if kitState.hitTargetId ~= nil then
		return
	end

	kitState.activeRemaining = math.max(kitState.activeRemaining - dt, 0)
	if kitState.activeRemaining <= 0 then
		kitState.recoveryRemaining = config().MissRecovery
		kitState.stunRemaining = config().MissStunDuration
		SimUtil.pushEvent(events, state, {
			kind = "HammerMiss",
			tick = 0,
			projectileId = nil,
			playerId = playerId,
			sourceId = playerId,
			targetId = nil,
			position = world.characters[playerId] and world.characters[playerId].position or nil,
			normal = nil,
			direction = kitState.direction,
		})
	end
end

return (Hammer :: any) :: WeaponKit.WeaponKit
