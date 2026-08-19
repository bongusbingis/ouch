--!strict

local SimTypes = require(script.Parent.Parent.Sim.SimTypes)

-- The contract between the pure sim and any netcode backend. Gameplay and
-- presentation code depend only on this shape.
--
-- Input submission is not part of this interface: clients send throw/catch
-- intent over a remote, and the adapter turns it into sim commands.

export type Adapter = {
	-- Binds the sim loop. Idempotent per process.
	start: () -> (),
	-- Registers a listener for sim events produced this frame. Broadcast events
	-- can arrive more than once, so listeners needing exactly-once semantics
	-- must deduplicate (the presentation layer's job).
	onEvent: (listener: (event: SimTypes.SimEvent) -> ()) -> (),
}

return {}
