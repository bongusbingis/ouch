-- Name: GameModeVoteViewModel.luau
-- Author: Jack C.
-- Description: Pure formatting for the mode ballot: vote count text and the clamped countdown fraction derived from server time.
-- Created: 2026-08-17

--!strict

local GameModeVoteViewModel = {}

function GameModeVoteViewModel.description(rules: any, teamMode: boolean): string
	local target = rules.ScoreTarget
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
