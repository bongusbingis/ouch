-- Description: Pure rule for how many players a match needs, relaxing the requirement as the oldest queued ticket waits and clamping to a viable range.

--!strict

local PopulationPolicy = {}

export type Expansion = {
	AfterSeconds: number,
	MinimumPlayers: number,
}

function PopulationPolicy.requiredPlayers(
	expansions: { Expansion },
	waitSeconds: number,
	targetPlayers: number,
	minimumPlayers: number,
	maxWaitSeconds: number
): number
	local minimum = math.clamp(minimumPlayers, 1, targetPlayers)
	-- The ladder expresses preferred match sizes. It must never strand a
	-- viable roster forever, even if its final step stays above the minimum.
	if waitSeconds >= maxWaitSeconds then
		return minimum
	end
	local required = targetPlayers

	for _, expansion in expansions do
		if waitSeconds < expansion.AfterSeconds then
			break
		end
		required = math.clamp(expansion.MinimumPlayers, minimum, targetPlayers)
	end

	return required
end

return PopulationPolicy
