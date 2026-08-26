-- Name: WeaponKit.luau
-- Author: Jack C.
-- Description: The interface every weapon implements, declaring the commands it claims and the initialization, input, and tick hooks the simulation calls.
-- Created: 2026-07-12

--!strict

local SimTypes = require(script.Parent.SimTypes)

export type WeaponKit = {
	kind: string,
	commands: { [SimTypes.CommandKind]: boolean },
	equipOnHandBall: boolean?,
	init: () -> any,
	handleInput: (
		kitState: any,
		state: SimTypes.SimState,
		command: SimTypes.InputCommand,
		world: SimTypes.WorldSnapshot,
		events: { SimTypes.SimEvent }
	) -> boolean,
	tickPlayer: (
		kitState: any,
		playerId: string,
		state: SimTypes.SimState,
		world: SimTypes.WorldSnapshot,
		dt: number,
		events: { SimTypes.SimEvent }
	) -> (),
	tickWorld: ((
		state: SimTypes.SimState,
		world: SimTypes.WorldSnapshot,
		dt: number,
		events: { SimTypes.SimEvent }
	) -> ())?,
}

return {}
