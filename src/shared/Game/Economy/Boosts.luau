--!strict

-- Pure booster stacking. Max-wins per multiplier type rather than multiplicative
-- so owning several overlapping passes cannot compound into a runaway rate, and
-- so a bundle that advertises a bigger number is always the one that applies.

local Boosts = {}

export type Multipliers = {
	Xp: number,
	Cash: number,
}

type BoostDef = { XpMultiplier: number?, CashMultiplier: number? }
type PassDef = { Boosts: BoostDef?, [string]: any }

function Boosts.multipliers(catalog: { [string]: PassDef }, owned: { [string]: boolean }): Multipliers
	local xp = 1
	local cash = 1
	for key, definition in catalog do
		if owned[key] == true and definition.Boosts ~= nil then
			xp = math.max(xp, definition.Boosts.XpMultiplier or 1)
			cash = math.max(cash, definition.Boosts.CashMultiplier or 1)
		end
	end
	return { Xp = xp, Cash = cash }
end

-- Awarded amounts floor so a multiplier can never mint a fractional Cash unit,
-- and never fall below the unboosted amount.
function Boosts.apply(amount: number, multiplier: number): number
	return math.max(amount, math.floor(amount * multiplier))
end

return Boosts
