--!strict

-- Pure booster stacking. Max-wins per multiplier type rather than multiplicative
-- so owning several overlapping passes cannot compound into a runaway rate, and
-- so a bundle that advertises a bigger number is always the one that applies.

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

-- Awarded amounts floor so a multiplier can never mint a fractional Bonks unit,
-- and never fall below the unboosted amount.
function Boosts.apply(amount: number, multiplier: number): number
	return math.max(amount, math.floor(amount * multiplier))
end

return Boosts
