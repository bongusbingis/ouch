--!strict
-- Deterministic Random stand-in for pinning distributions in specs:
-- NextNumber returns queued fractions [0,1), NextInteger returns queued picks
-- (clamped to the requested range). Queues return their fallback (0 / min)
-- once exhausted.

local ScriptedRandom = {}

function ScriptedRandom.new(numbers: { number }, integers: { number }): Random
	local numberIndex = 0
	local integerIndex = 0
	return {
		NextNumber = function(_self): number
			numberIndex += 1
			return numbers[numberIndex] or 0
		end,
		NextInteger = function(_self, min: number, max: number): number
			integerIndex += 1
			return math.clamp(integers[integerIndex] or min, min, max)
		end,
	} :: any
end

return ScriptedRandom
