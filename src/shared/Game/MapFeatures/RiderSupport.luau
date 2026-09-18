--!strict
-- Airborne support may retain a ride, never acquire one.

local RiderSupport = {}

function RiderSupport.canRetain(
	state: {
		previous: boolean,
		sameSupport: boolean,
		airborne: boolean,
		otherContact: boolean,
		airborneSeconds: number,
	},
	maxAirborneSeconds: number
): boolean
	return state.previous
		and state.sameSupport
		and state.airborne
		and not state.otherContact
		and state.airborneSeconds <= maxAirborneSeconds
end

-- HANDOFF 13: a ServerCarries ride has exactly one carry solver, and it is the
-- side that simulates the character. The server's copy of a client-owned root is
-- one round trip stale, so writing that root every frame replays a stale pose
-- over the player's own motion instead of carrying them.
function RiderSupport.serverMayCarry(state: {
	serverOwnsRoot: boolean,
	seated: boolean,
	airborne: boolean,
}): boolean
	return state.serverOwnsRoot and (state.seated or not state.airborne)
end

return RiderSupport
