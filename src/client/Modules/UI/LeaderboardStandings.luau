--!strict

-- Pure ordering for the replicated post-match player breakdown.

export type Entry = {
	userId: number,
	displayName: string,
	score: number,
	elims: number,
}

local LeaderboardStandings = {}

function LeaderboardStandings.sorted(entries: { Entry }): { Entry }
	local result = table.clone(entries)
	table.sort(result, function(left, right)
		if left.score ~= right.score then
			return left.score > right.score
		end
		if left.elims ~= right.elims then
			return left.elims > right.elims
		end
		return left.userId < right.userId
	end)
	return result
end

return LeaderboardStandings
