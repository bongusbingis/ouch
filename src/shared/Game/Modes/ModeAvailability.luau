--!strict

-- Pure roster eligibility shared by voting, match starts and replay routing.

local ModeAvailability = {}

function ModeAvailability.canStart(
	rules: any,
	entrants: { { id: string, partyId: string? } },
	practice: boolean
): boolean
	if practice and #entrants == 1 then
		return true
	end
	if #entrants < rules.MinPlayers then
		return false
	end
	local groups = {}
	local count = 0
	for _, entrant in entrants do
		local key = if entrant.partyId then "party:" .. entrant.partyId else "player:" .. entrant.id
		if not groups[key] then
			groups[key] = true
			count += 1
		end
	end
	return count >= (rules.MinParties or 1)
end

function ModeAvailability.canContinue(rules: any, entrants: { any }): boolean
	if #entrants < rules.MinPlayers then
		return false
	end
	if (rules.MinParties or 1) <= 1 then
		return true
	end
	local teams = {}
	local count = 0
	for _, entrant in entrants do
		if entrant.teamId and not teams[entrant.teamId] then
			teams[entrant.teamId] = true
			count += 1
		end
	end
	return count >= 2
end

return table.freeze(ModeAvailability)
