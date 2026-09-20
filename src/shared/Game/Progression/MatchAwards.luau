-- Bounded profile journal for match awards; unfinished entries are never evicted.
--!strict

local MatchAwards = {}

local OPTIONAL_COUNTERS = { "Elims", "Deaths", "Catches", "Wins", "Losses", "MatchesPlayed" }

local function validAmount(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge and value >= 0 and value % 1 == 0
end

function MatchAwards.validateDelta(delta: any, path: string): (boolean, string?)
	if type(delta) ~= "table" then
		return false, `{path}: expected V1 award table, received {typeof(delta)}; repair the persisted V1 award before replay`
	end
	for _, field in { "XP", "Bonks" } do
		local value = delta[field]
		if not validAmount(value) then
			return false, `{path}.{field}: expected finite nonnegative integer, received {tostring(value)}; repair the persisted V1 award before replay`
		end
	end
	for _, field in OPTIONAL_COUNTERS do
		local value = delta[field]
		if value ~= nil and not validAmount(value) then
			return false, `{path}.{field}: expected finite nonnegative integer when present, received {tostring(value)}; repair the persisted V1 award before replay`
		end
	end
	return true, nil
end

function MatchAwards.validateMarkers(record: any, id: string): (boolean, string?)
	local path = `MatchAwards.Pending.{id}`
	if type(record) ~= "table" then
		return false, `{path}: expected V1 award table, received {typeof(record)}; repair the persisted V1 award before replay`
	end
	for _, field in { "Ready", "ProgressionApplied", "SeasonApplied" } do
		if type(record[field]) ~= "boolean" then
			return false, `{path}.{field}: expected boolean, received {tostring(record[field])}; repair the persisted V1 award before replay`
		end
	end
	if record.SeasonApplied and not record.ProgressionApplied then
		return false, `{path}.SeasonApplied: true requires ProgressionApplied=true; inspect the persisted credit before repair`
	end
	if not record.Ready then
		if record.ProgressionApplied then
			return false, `{path}.ProgressionApplied: true requires Ready=true; inspect the persisted payout before repair`
		end
		if record.Awarded ~= nil then
			return false, `{path}.Awarded: must be absent while Ready=false; inspect the persisted payout before repair`
		end
	end
	return true, nil
end

function MatchAwards.validatePending(record: any, id: string): (boolean, string?)
	local path = `MatchAwards.Pending.{id}`
	local markersValid, markerReason = MatchAwards.validateMarkers(record, id)
	if not markersValid then
		return false, markerReason
	end
	if type(record.SeasonId) ~= "string" then
		return false, `{path}.SeasonId: expected string, received {tostring(record.SeasonId)}; repair the persisted V1 award before replay`
	end
	local valid, reason = MatchAwards.validateDelta(record.Progress, `{path}.Progress`)
	if not valid then
		return false, reason
	end
	if record.Awarded ~= nil then
		return MatchAwards.validateDelta(record.Awarded, `{path}.Awarded`)
	end
	if record.ProgressionApplied then
		return false, `{path}.Awarded: required after progression was applied; repair the persisted V1 award before replay`
	end
	return true, nil
end

function MatchAwards.ensure(data: any): any
	if data.MatchAwards == nil then
		data.MatchAwards = { Version = 1, Pending = {}, Completed = {} }
	end
	local journal = data.MatchAwards
	if journal.Version == nil then
		journal.Version = 1
	end
	if journal.Pending == nil then
		journal.Pending = {}
	end
	if journal.Completed == nil then
		journal.Completed = {}
	end
	return journal
end

function MatchAwards.hasCapacity(journal: any, limit: number): boolean
	local count = 0
	for _ in journal.Pending do
		count += 1
	end
	return count < limit
end

function MatchAwards.enqueue(journal: any, id: string, record: any, limit: number): any
	if journal.Completed[id] ~= nil then
		return nil
	end
	if journal.Pending[id] ~= nil then
		return journal.Pending[id]
	end
	if not MatchAwards.hasCapacity(journal, limit) then
		return nil
	end
	journal.Pending[id] = record
	return journal.Pending[id]
end

function MatchAwards.complete(journal: any, id: string, now: number, limit: number)
	journal.Completed[id] = now
	journal.Pending[id] = nil
	local keys = {}
	for key in journal.Completed do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return if journal.Completed[a] == journal.Completed[b]
			then a < b
			else journal.Completed[a] < journal.Completed[b]
	end)
	for index = 1, #keys - limit do
		journal.Completed[keys[index]] = nil
	end
end

return MatchAwards
