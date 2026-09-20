-- Description: Pure team assignment that keeps lobby parties together while minimizing team imbalance, deterministically for the same entrants.

--!strict

local PartyTeamAllocator = {}

export type Entrant = {
	id: string,
	partyId: string?,
}

type Group = {
	key: string,
	members: { string },
}

local function groupsFor(entrants: { Entrant }): { Group }
	local byKey: { [string]: Group } = {}
	for _, entrant in entrants do
		local key = if entrant.partyId then `party:{entrant.partyId}` else `player:{entrant.id}`
		local group = byKey[key]
		if group == nil then
			group = { key = key, members = {} }
			byKey[key] = group
		end
		table.insert(group.members, entrant.id)
	end

	local groups = {}
	for _, group in byKey do
		table.sort(group.members)
		table.insert(groups, group)
	end
	table.sort(groups, function(first, second)
		return first.key < second.key
	end)
	return groups
end

local function assignManyTeams(groups: { Group }, teams: { string }): { [string]: string }
	table.sort(groups, function(first, second)
		if #first.members ~= #second.members then
			return #first.members > #second.members
		end
		return first.key < second.key
	end)

	local counts = {}
	for _, teamId in teams do
		counts[teamId] = 0
	end
	local assignments = {}
	for _, group in groups do
		local selectedTeam = teams[1]
		for _, teamId in teams do
			if counts[teamId] < counts[selectedTeam] then
				selectedTeam = teamId
			end
		end
		for _, entrantId in group.members do
			assignments[entrantId] = selectedTeam
		end
		counts[selectedTeam] += #group.members
	end
	return assignments
end

function PartyTeamAllocator.assign(entrants: { Entrant }, teams: { string }): { [string]: string }
	assert(#teams > 0, "[PartyTeamAllocator] at least one team is required")
	local groups = groupsFor(entrants)
	return assignManyTeams(groups, teams)
end

return table.freeze(PartyTeamAllocator)
