--!strict

local SimTypes = require(script.Parent.Parent.Sim.SimTypes)

-- The contract between the pure sim and any netcode backend. Gameplay and
-- presentation code depend only on this shape, which keeps the traditional
-- (remote-based) fallback a bounded rewrite of one adapter module.
--
-- Under server authority, input submission is not part of this interface:
-- inputs flow through the Input Action System and are read inside the
-- simulation itself.

export type Adapter = {
	-- Binds the sim loop. Idempotent per process.
	start: () -> (),
	-- Registers a listener for sim events produced this frame. On the client,
	-- events may replay during resimulation; listeners needing exactly-once
	-- semantics must deduplicate (the presentation layer's job).
	onEvent: (listener: (event: SimTypes.SimEvent) -> ()) -> (),
}

return {}
