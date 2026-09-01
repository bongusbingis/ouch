-- Name: GameModeVoteViewModel.luau
-- Author: Jack C.
-- Description: Pure formatting for the mode ballot: vote count text and the clamped countdown fraction derived from server time.
-- Created: 2026-08-17

--!strict

local GameModeVoteViewModel = {}

function GameModeVoteViewModel.formatVoteCount(count: number): string
	return string.format("%03d", math.max(0, math.floor(count)))
end

function GameModeVoteViewModel.progress(now: number, endsAt: number, durationSeconds: number): number
	if durationSeconds <= 0 then
		return 0
	end
	return math.clamp((endsAt - now) / durationSeconds, 0, 1)
end

return table.freeze(GameModeVoteViewModel)
