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

local function assignTwoTeams(groups: { Group }, teams: { string }): { [string]: string }
	local reachable: { [number]: { [number]: boolean } } = { [0] = {} }
	local total = 0
	for groupIndex, group in groups do
		local size = #group.members
		total += size
		local additions = {}
		for sum = 0, total - size do
			local selected = reachable[sum]
			if selected == nil then
				continue
			end
			local nextSum = sum + size
			if reachable[nextSum] == nil and additions[nextSum] == nil then
				local nextSelected = table.clone(selected)
				nextSelected[groupIndex] = true
				additions[nextSum] = nextSelected
			end
		end
		for sum, selected in additions do
			reachable[sum] = selected
		end
	end

	local bestSum = 0
	for sum in reachable do
		local difference = math.abs(total - 2 * sum)
		local bestDifference = math.abs(total - 2 * bestSum)
		if difference < bestDifference or (difference == bestDifference and sum > bestSum) then
			bestSum = sum
		end
	end

	local firstTeamGroups = assert(reachable[bestSum], "[PartyTeamAllocator] selected partition must exist")
	local assignments = {}
	for groupIndex, group in groups do
		local teamId = if firstTeamGroups[groupIndex] then teams[1] else teams[2]
		for _, entrantId in group.members do
			assignments[entrantId] = teamId
		end
	end
	return assignments
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
	if #teams == 2 then
		return assignTwoTeams(groups, teams)
	end
	return assignManyTeams(groups, teams)
end

return table.freeze(PartyTeamAllocator)
