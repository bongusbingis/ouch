-- Name: PopulationPolicy.luau
-- Author: Jack C.
-- Description: Pure rule for how many players a match needs, relaxing the requirement as the oldest queued ticket waits and clamping to a viable range.
-- Created: 2026-08-17

--!strict

local PopulationPolicy = {}

export type Expansion = {
	AfterSeconds: number,
	MinimumPlayers: number,
}

function PopulationPolicy.requiredPlayers(expansions: { Expansion }, waitSeconds: number, targetPlayers: number): number
	local required = targetPlayers

	for _, expansion in expansions do
		if waitSeconds < expansion.AfterSeconds then
			break
		end
		required = math.clamp(expansion.MinimumPlayers, 1, targetPlayers)
	end

	return required
end

return PopulationPolicy
