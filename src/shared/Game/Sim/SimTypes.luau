-- Name: SimTypes.luau
-- Author: Jack C.
-- Description: Type declarations and state constructors for the simulation, using the native vector type so trajectories stay bit-identical between the game and headless tests.
-- Created: 2026-07-12

--!strict

export type Vec = vector

export type CharacterSnapshot = {
	position: Vec,
	handPosition: Vec,
	throwPosition: Vec,
	velocity: Vec,
	height: number,
	radius: number,
	alive: boolean,
	teamId: string?,
	invulnerable: boolean,
	velocityConsistency: number?,
}

export type SweepHit = {
	distance: number,
	position: Vec,
	normal: Vec,
}

export type CollisionWorld = {
	sweepSphere: (origin: Vec, displacement: Vec, radius: number) -> SweepHit?,
}

export type SimRules = {
	preserveDodgeballs: boolean,
}

export type WorldSnapshot = {
	characters: { [string]: CharacterSnapshot },
	collision: CollisionWorld,
	ballSpawns: { Vec },
	rules: SimRules?,
}

export type ProjectilePhase = "Held" | "Windup" | "InFlight" | "Bouncing" | "Rolling" | "Free"

export type ProjectileState = {
	id: string,
	archetype: string,
	ownerId: string?,
	heldBy: string?,
	phase: ProjectilePhase,
	position: Vec,
	velocity: Vec,
	targetId: string?,
	effectiveRadius: number,
	flightTime: number,
	windupRemaining: number,
	bounceCount: number,
	releaseAim: Vec?,
	releaseTargetId: string?,
	releaseDeviceClass: string?,
	releaseCharge: number?,
}

export type PlayerCombatState = {
	id: string,
	weapons: { [string]: any },
	equipped: string,
	heldBallLastTick: boolean,
}

export type SimState = {
	tick: number,
	players: { [string]: PlayerCombatState },
	projectiles: { [string]: ProjectileState },
	nextProjectileSeq: number,
	spawnTimers: { number },
}

export type CommandKind = "Throw" | "Catch" | "Equip" | "BeginCharge" | "CancelCharge"

export type InputCommand = {
	playerId: string,
	kind: CommandKind,
	weapon: string?,
	aimOrigin: Vec?,
	aimDir: Vec?,
	targetId: string?,
	deviceClass: string?,
	charge: number?,
	assist: { [string]: number }?,
}

export type SimEvent = {
	kind: string,
	tick: number,
	projectileId: string?,
	playerId: string?,
	sourceId: string?,
	targetId: string?,
	position: Vec?,
	normal: Vec?,
	direction: Vec?,
	magnitude: number?,
}

local SimTypes = {}

function SimTypes.newState(): SimState
	return {
		tick = 0,
		players = {},
		projectiles = {},
		nextProjectileSeq = 1,
		spawnTimers = {},
	}
end

return SimTypes
