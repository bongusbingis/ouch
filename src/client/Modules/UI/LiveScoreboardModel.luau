--!strict

-- Projects replicated per-match scores into compact FFA or team HUD rows.

export type Entry = {
	userId: number,
	displayName: string,
	score: number,
	teamId: string?,
	isLocal: boolean,
}

export type RankedEntry = Entry & {
	rank: number,
}

export type FfaModel = {
	kind: "FFA",
	rows: { RankedEntry },
	localRow: RankedEntry?,
}

export type TeamStanding = {
	id: string,
	score: number,
	rows: { RankedEntry },
}

export type TeamModel = {
	kind: "Team",
	teams: { TeamStanding },
}

export type Model = FfaModel | TeamModel

local LiveScoreboardModel = {}

local function sorted(entries: { Entry }): { Entry }
	local result = table.clone(entries)
	table.sort(result, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.userId < b.userId
	end)
	return result
end

local function ranked(entries: { Entry }, limit: number): { RankedEntry }
	local result = {}
	for rank = 1, math.min(#entries, limit) do
		local entry = entries[rank]
		table.insert(result, {
			userId = entry.userId,
			displayName = entry.displayName,
			score = entry.score,
			teamId = entry.teamId,
			isLocal = entry.isLocal,
			rank = rank,
		})
	end
	return result
end

function LiveScoreboardModel.ffa(entries: { Entry }, rowLimit: number): FfaModel
	local ordered = sorted(entries)
	local rows = ranked(ordered, rowLimit)
	local localRow = nil
	for rank, entry in ordered do
		if entry.isLocal and rank > rowLimit then
			localRow = {
				userId = entry.userId,
				displayName = entry.displayName,
				score = entry.score,
				teamId = entry.teamId,
				isLocal = true,
				rank = rank,
			}
			break
		end
	end
	return {
		kind = "FFA",
		rows = rows,
		localRow = localRow,
	}
end

function LiveScoreboardModel.teams(
	entries: { Entry },
	teamIds: { string },
	teamScores: { [string]: number },
	rowLimit: number
): TeamModel
	local teams = {}
	for _, teamId in teamIds do
		local members = {}
		for _, entry in entries do
			if entry.teamId == teamId then
				table.insert(members, entry)
			end
		end
		table.insert(teams, {
			id = teamId,
			score = teamScores[teamId] or 0,
			rows = ranked(sorted(members), rowLimit),
		})
	end
	return {
		kind = "Team",
		teams = teams,
	}
end

return LiveScoreboardModel
