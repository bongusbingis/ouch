-- Name: AdapterInterface.luau
-- Author: Jack C.
-- Description: The contract between the pure simulation and any netcode backend, declaring the start and event-subscription surface gameplay and presentation depend on.
-- Created: 2026-07-12

--!strict

local SimTypes = require(script.Parent.Parent.Sim.SimTypes)

export type Adapter = {
	start: () -> (),
	onEvent: (listener: (event: SimTypes.SimEvent) -> ()) -> (),
}

return {}
