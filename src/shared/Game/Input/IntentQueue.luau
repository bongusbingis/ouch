-- Bounded per-player FIFO mailboxes preserve admitted input order without sharing capacity.
--!strict

local Queue = {}

function Queue.new(limit: number)
	local pending: { [string]: { any } } = {}
	local sequence: { [string]: number } = {}
	local rejected = 0
	return {
		push = function(id: string, intent: any): boolean
			local entries = pending[id] or {}
			if #entries >= limit then
				rejected += 1
				return false
			end
			sequence[id] = (sequence[id] or 0) + 1
			intent.sequence = sequence[id]
			pending[id] = entries
			table.insert(entries, intent)
			return true
		end,
		drain = function(): { any }
			local ids = {}
			for id in pending do
				table.insert(ids, id)
			end
			table.sort(ids)
			local result = {}
			for _, id in ids do
				for _, intent in pending[id] do
					table.insert(result, intent)
				end
			end
			table.clear(pending)
			return result
		end,
		forget = function(id: string)
			pending[id] = nil
			sequence[id] = nil
		end,
		takeRejected = function(): number
			local count = rejected
			rejected = 0
			return count
		end,
	}
end

return Queue
