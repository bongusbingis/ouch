-- Description: Pure booster stacking that takes the best owned multiplier per type rather than compounding, so overlapping passes cannot run away.

--!strict

local Boosts = {}

export type Multipliers = {
	Xp: number,
	Bonks: number,
}

type BoostDef = { XpMultiplier: number?, BonksMultiplier: number? }
type PassDef = { Boosts: BoostDef?, [string]: any }

function Boosts.multipliers(catalog: { [string]: PassDef }, owned: { [string]: boolean }): Multipliers
	local xp = 1
	local bonks = 1
	for key, definition in catalog do
		if owned[key] == true and definition.Boosts ~= nil then
			xp = math.max(xp, definition.Boosts.XpMultiplier or 1)
			bonks = math.max(bonks, definition.Boosts.BonksMultiplier or 1)
		end
	end
	return { Xp = xp, Bonks = bonks }
end

function Boosts.apply(amount: number, multiplier: number): number
	return math.max(amount, math.floor(amount * multiplier))
end

return Boosts
