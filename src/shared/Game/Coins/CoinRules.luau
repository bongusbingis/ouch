-- Pure coin rules: per-player match tally with cap, spawn-point choice, and who collects a coin.
--!strict

local CoinRules = {}

export type Tally = { [string]: number }
export type Candidate = { id: string, distance: number }

-- Bonks granted for one pickup: a full coin, a partial coin at the cap, or 0 when capped.
function CoinRules.grant(tally: Tally, playerId: string, perCoin: number, cap: number): number
	local earned = tally[playerId] or 0
	local granted = math.max(0, math.min(perCoin, cap - earned))
	tally[playerId] = earned + granted
	return granted
end

function CoinRules.atCap(tally: Tally, playerId: string, cap: number): boolean
	return (tally[playerId] or 0) >= cap
end

-- Index of a random free spawn (never one already holding a coin), or nil when none is free.
function CoinRules.pickSpawn(count: number, occupied: { [number]: boolean }, roll: (number) -> number): number?
	local free = {}
	for index = 1, count do
		if not occupied[index] then
			table.insert(free, index)
		end
	end
	if #free == 0 then
		return nil
	end
	return free[roll(#free)]
end

-- The nearest candidate within radius, ties broken by id so the result is deterministic.
function CoinRules.collector(candidates: { Candidate }, radius: number): string?
	local best: Candidate? = nil
	for _, candidate in candidates do
		if candidate.distance > radius then
			continue
		end
		-- Nearest wins; an exact distance tie goes to the lower id so the result is deterministic.
		if
			best == nil
			or candidate.distance < best.distance
			or (candidate.distance == best.distance and candidate.id < best.id)
		then
			best = candidate
		end
	end
	return if best then best.id else nil
end

return CoinRules
