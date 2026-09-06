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

return RiderSupport
