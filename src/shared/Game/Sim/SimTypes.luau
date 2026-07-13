--!strict

-- All sim state uses Luau's native `vector` (f32 in both Roblox and Lune),
-- which keeps trajectories bit-identical between the game and headless tests.

export type Vec = vector

export type CharacterSnapshot = {
	position: Vec, -- capsule center
	handPosition: Vec,
	velocity: Vec,
	height: number,
	radius: number,
	alive: boolean,
}

export type SweepHit = {
	distance: number,
	position: Vec,
	normal: Vec,
}

-- Implemented against Roblox spherecasts by the adapter, mock geometry in tests.
export type CollisionWorld = {
	sweepSphere: (origin: Vec, displacement: Vec, radius: number) -> SweepHit?,
}

export type WorldSnapshot = {
	characters: { [string]: CharacterSnapshot },
	collision: CollisionWorld,
	ballSpawns: { Vec },
}

export type ProjectilePhase = "Held" | "Windup" | "InFlight" | "Bouncing" | "Recalling" | "Free"

export type ProjectileState = {
	id: string,
	archetype: string,
	ownerId: string?, -- last thrower/possessor; nil for world-spawned Free balls
	heldBy: string?, -- set only while phase == "Held"
	phase: ProjectilePhase,
	position: Vec,
	velocity: Vec,
	targetId: string?, -- homing target while InFlight
	effectiveRadius: number, -- hit radius incl. forgiveness + device magnetism
	flightTime: number,
	windupRemaining: number,
	bounceCount: number,
	spinAngle: number,
	spinRate: number,
	releaseAim: Vec?,
	releaseTargetId: string?,
	releaseDeviceClass: string?,
}

export type PlayerCombatState = {
	id: string,
	weapons: { [string]: any }, -- kit kind -> kit-owned state (cooldowns etc.)
}

export type SimState = {
	tick: number,
	players: { [string]: PlayerCombatState },
	projectiles: { [string]: ProjectileState },
	nextProjectileSeq: number,
	spawnTimers: { number }, -- one per WorldSnapshot.ballSpawns index
}

export type CommandKind = "Throw" | "Recall"

export type InputCommand = {
	playerId: string,
	kind: CommandKind,
	aimOrigin: Vec?,
	aimDir: Vec?,
	targetId: string?,
	deviceClass: string?,
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
