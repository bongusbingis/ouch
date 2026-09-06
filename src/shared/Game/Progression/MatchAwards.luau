-- Bounded profile journal for match awards; unfinished entries are never evicted.
--!strict

local MatchAwards = {}

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
