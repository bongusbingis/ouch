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
