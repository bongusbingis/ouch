-- Name: ScriptedRandom.luau
-- Author: Jack C.
-- Description: Deterministic stand-in for a random source that returns queued values, so specs can pin probability-driven outcomes exactly.
-- Created: 2026-07-16

--!strict

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
