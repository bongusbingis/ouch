--!strict

-- All sim state uses Luau's native `vector` (f32 in both Roblox and Lune),
-- which keeps trajectories bit-identical between the game and headless tests.

export type Vec = vector

export type CharacterSnapshot = {
	position: Vec, -- capsule center
	handPosition: Vec, -- fake held-ball visual socket
	throwPosition: Vec, -- authoritative overhand release socket
	velocity: Vec,
	height: number,
	radius: number,
	alive: boolean,
	teamId: string?,
	-- Spawn protection: still moves/throws/holds, but cannot be hit or targeted.
	invulnerable: boolean,
	-- 0-1 measure of how steadily this character has been moving, measured by
	-- the adapter over a rolling window. Assists that predict where it is going
	-- fade out as this drops. Absent means unmeasured, treated as no confidence.
	velocityConsistency: number?,
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

-- Match rules the sim itself needs. Supplied per tick by the adapter from the
-- active mode, so the sim reads rules as data and never names a mode.
export type SimRules = {
	-- A ball that stops moving goes back to whoever last owned it instead of
	-- lying where it fell. Absent is treated as false, which is the behaviour
	-- balls had before modes could ask for anything else -- so a mode the adapter
	-- cannot resolve degrades to world pickups rather than to something new.
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
	releaseAim: Vec?,
	releaseTargetId: string?,
	releaseDeviceClass: string?,
	-- Throw style locked in at windup and consumed at release, so a player who
	-- changes their mind mid-windup cannot rewrite a throw already committed.
	releaseCharge: number?,
	releaseLob: boolean?,
}

export type PlayerCombatState = {
	id: string,
	weapons: { [string]: any }, -- kit kind -> kit-owned state (cooldowns etc.)
	-- Which kit a command claimed by more than one weapon routes to. The single
	-- source of truth for the active weapon: the client's HUD and animation layer
	-- read a projection of this, never their own guess.
	equipped: string,
	-- Previous tick's answer to "does this player hold a ball", used only to spot
	-- the moment they gain one so it can be auto-equipped. Possession itself still
	-- lives only in ProjectileState -- this is an edge detector, not a copy.
	heldBallLastTick: boolean,
}

export type SimState = {
	tick: number,
	players: { [string]: PlayerCombatState },
	projectiles: { [string]: ProjectileState },
	nextProjectileSeq: number,
	spawnTimers: { number }, -- one per WorldSnapshot.ballSpawns index
}

export type CommandKind = "Throw" | "Catch" | "Equip"

export type InputCommand = {
	playerId: string,
	kind: CommandKind,
	-- Equip only: the kit kind to make active.
	weapon: string?,
	aimOrigin: Vec?,
	aimDir: Vec?,
	targetId: string?,
	deviceClass: string?,
	-- 0-1 hold duration behind a charged throw. Absent or 0 is a normal throw.
	charge: number?,
	-- Throw as a lob: slower, pitched up. Mutually exclusive with charge, and
	-- the sim resolves the conflict rather than trusting the sender.
	lob: boolean?,
	-- Resolved 0-1 assist strengths for this player, attached by the adapter.
	-- Absent means no assist, which is what an unconfigured player gets.
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
