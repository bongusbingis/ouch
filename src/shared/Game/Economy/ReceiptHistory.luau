-- Receipt tombstones remain permanent; only recent presentation details are retained.
--!strict

local History = {}

function History.recent(receipts: { [string]: any }, limit: number): { any }
	local result = {}
	for id, entry in receipts do
		if type(entry) == "table" and type(entry.at) == "number" and type(entry.productId) == "number" then
			table.insert(result, { id = id, at = entry.at, productId = entry.productId, payload = entry.payload })
		end
	end
	table.sort(result, function(a, b)
		return if a.at == b.at then a.id > b.id else a.at > b.at
	end)
	while #result > limit do
		table.remove(result)
	end
	return result
end

function History.prune(receipts: { [string]: any }, limit: number, preserveId: string)
	local entries = History.recent(receipts, math.huge)
	local kept = 1
	for _, entry in entries do
		if entry.id == preserveId then
			continue
		end
		if kept < limit then
			kept += 1
		else
			receipts[entry.id] = entry.at
		end
	end
end

return History
