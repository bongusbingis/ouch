-- Description: Pure formatting for the mode ballot: vote count text and the clamped countdown fraction derived from server time.

--!strict

local GameModeVoteViewModel = {}

-- projectedTarget is the target this roster would actually play to, published on
-- the ballot by the server. The authored rules value is only the number at the
-- mode's reference roster, so selling that one would promise a match length
-- nobody is about to play.
function GameModeVoteViewModel.description(rules: any, teamMode: boolean, projectedTarget: number?): string
	local target = projectedTarget or rules.ScoreTarget
	if target == math.huge then
		return "Survive until time runs out. Eliminated survivors join the infected."
	end
	local goal = if teamMode
		then `First team to {target} eliminations wins.`
		else `First to {target} eliminations wins.`
	return goal .. (if teamMode then " Parties stay together." else " Everyone is a target.")
end

function GameModeVoteViewModel.formatVoteCount(count: number): string
	local total = math.max(0, math.floor(count))
	return `{total} {if total == 1 then "VOTE" else "VOTES"}`
end

function GameModeVoteViewModel.progress(now: number, endsAt: number, durationSeconds: number): number
	if durationSeconds <= 0 then
		return 0
	end
	return math.clamp((endsAt - now) / durationSeconds, 0, 1)
end

return table.freeze(GameModeVoteViewModel)
