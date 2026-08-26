-- Name: ModeVote.luau
-- Author: Jack C.
-- Description: Pure ballot state: one vote per player, tallying, finalist selection, random resolution of ties and empty ballots, and the capped extension for late-ready players.
-- Created: 2026-08-17

--!strict

local ModeVote = {}

export type State = {
	options: { string },
	optionSet: { [string]: boolean },
	votesByUserId: { [number]: string },
}

function ModeVote.new(options: { string }): State
	local optionSet = {}
	for _, modeId in options do
		assert(not optionSet[modeId], `[ModeVote] duplicate option "{modeId}"`)
		optionSet[modeId] = true
	end
	assert(#options > 0, "[ModeVote] at least one option is required")
	return {
		options = table.clone(options),
		optionSet = optionSet,
		votesByUserId = {},
	}
end

function ModeVote.cast(state: State, userId: number, modeId: string): boolean
	if not state.optionSet[modeId] or state.votesByUserId[userId] == modeId then
		return false
	end
	state.votesByUserId[userId] = modeId
	return true
end

function ModeVote.remove(state: State, userId: number): boolean
	if state.votesByUserId[userId] == nil then
		return false
	end
	state.votesByUserId[userId] = nil
	return true
end

function ModeVote.allVoted(state: State, userIds: { number }): boolean
	if #userIds == 0 then
		return false
	end
	for _, userId in userIds do
		if state.votesByUserId[userId] == nil then
			return false
		end
	end
	return true
end

function ModeVote.counts(state: State): { [string]: number }
	local result = {}
	for _, modeId in state.options do
		result[modeId] = 0
	end
	for _, modeId in state.votesByUserId do
		result[modeId] = (result[modeId] or 0) + 1
	end
	return result
end

function ModeVote.finalists(state: State): { string }
	local counts = ModeVote.counts(state)
	local highest = 0
	for _, modeId in state.options do
		highest = math.max(highest, counts[modeId] or 0)
	end

	local result = {}
	for _, modeId in state.options do
		if (counts[modeId] or 0) == highest then
			table.insert(result, modeId)
		end
	end
	return result
end

function ModeVote.choose(state: State, chooseIndex: (number) -> number): string
	local finalists = ModeVote.finalists(state)
	local index = chooseIndex(#finalists)
	assert(index % 1 == 0 and index >= 1 and index <= #finalists, "[ModeVote] chooser returned an invalid index")
	return finalists[index]
end

function ModeVote.extendForLateReady(
	currentEndsAt: number,
	maximumEndsAt: number,
	now: number,
	minimumVisibleSeconds: number
): number
	if now >= currentEndsAt or currentEndsAt - now >= minimumVisibleSeconds then
		return currentEndsAt
	end
	return math.max(currentEndsAt, math.min(now + minimumVisibleSeconds, maximumEndsAt))
end

return table.freeze(ModeVote)
