-- Name: ScoreTarget.luau
-- Author: Jack C.
-- Description: Pure roster scaling for a mode's elimination target, reading the mode's reference roster and clamps so a duel and a full lobby finish in comparable time.
-- Created: 2026-09-12

--!strict

local ScoreTarget = {}

export type ScalableRules = {
	ScoreTarget: number,
	ReferencePlayers: number?,
	MinScoreTarget: number?,
	MaxScoreTarget: number?,
}

-- A mode without ReferencePlayers, or one whose target is infinite (there is no
-- target to reach), keeps its authored value. Everything else scales linearly
-- off the reference roster and is clamped, so the authored number stays exactly
-- correct at the roster it was tuned for.
function ScoreTarget.resolve(rules: ScalableRules, playerCount: number): number
	local reference = rules.ReferencePlayers
	local target = rules.ScoreTarget
	if reference == nil or target ~= target or target == math.huge then
		return target
	end
	assert(reference > 0, "[ScoreTarget] ReferencePlayers must be positive")

	local scaled = math.round(target * math.max(playerCount, 1) / reference)
	local minimum = rules.MinScoreTarget or 1
	local maximum = rules.MaxScoreTarget or math.huge
	assert(minimum <= maximum, "[ScoreTarget] MinScoreTarget must not exceed MaxScoreTarget")
	return math.clamp(scaled, minimum, maximum)
end

return table.freeze(ScoreTarget)
