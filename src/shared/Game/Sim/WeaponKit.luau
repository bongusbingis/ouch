--!strict

local SimTypes = require(script.Parent.SimTypes)

-- The interface every combat tool implements as pure functions. Adding a new
-- weapon (e.g. the hammer) means one module satisfying this type plus a
-- WeaponRegistry entry — no sim-core, adapter, or netcode changes.

export type WeaponKit = {
	kind: string,
	-- Command kinds this kit consumes; SimCore routes on these.
	commands: { [SimTypes.CommandKind]: boolean },
	-- Set by the kit that a ball in hand belongs to. Gaining a held ball equips
	-- that kit automatically, so picking one up still means you can throw it
	-- without a second button. Declared here rather than named in SimCore so the
	-- core stays free of specific weapons.
	equipOnHandBall: boolean?,
	-- Fresh per-player kit state (cooldowns, phase machines).
	init: () -> any,
	-- Consume one routed command. Mutates kit state / sim state, appends events.
	handleInput: (
		kitState: any,
		state: SimTypes.SimState,
		command: SimTypes.InputCommand,
		world: SimTypes.WorldSnapshot,
		events: { SimTypes.SimEvent }
	) -> boolean,
	-- Per-tick per-player update (cooldowns etc.).
	tickPlayer: (
		kitState: any,
		playerId: string,
		state: SimTypes.SimState,
		world: SimTypes.WorldSnapshot,
		dt: number,
		events: { SimTypes.SimEvent }
	) -> (),
	-- Per-tick kit-global update (world spawns, pickups). Optional.
	tickWorld: ((
		state: SimTypes.SimState,
		world: SimTypes.WorldSnapshot,
		dt: number,
		events: { SimTypes.SimEvent }
	) -> ())?,
}

return {}
