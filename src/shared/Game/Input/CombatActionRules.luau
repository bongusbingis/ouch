-- Client input eligibility derives from authoritative combat projections; only cooldowns are bufferable.
--!strict

local CombatActionRules = {}

export type Snapshot = {
	enabled: boolean,
	active: boolean,
	alive: boolean,
	eligible: boolean,
	weapon: string,
	holdsBall: boolean,
	throwCooldown: number,
	hammerCooldown: number,
	catchCooldown: number,
}

function CombatActionRules.status(kind: string, state: Snapshot): "Ready" | "Cooldown" | "Unavailable"
	if not state.enabled or not state.active or not state.alive or not state.eligible then
		return "Unavailable"
	end
	local cooldown
	if kind == "Catch" then
		if state.holdsBall then
			return "Unavailable"
		end
		cooldown = state.catchCooldown
	elseif kind == "Throw" and state.weapon == "Hammer" then
		cooldown = state.hammerCooldown
	elseif kind == "Throw" and state.weapon == "Dodgeball" and state.holdsBall then
		cooldown = state.throwCooldown
	else
		return "Unavailable"
	end
	return if cooldown > 0 then "Cooldown" else "Ready"
end

return table.freeze(CombatActionRules)
