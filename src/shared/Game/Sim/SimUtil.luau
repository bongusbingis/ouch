--!strict

-- Deterministic iteration helpers: plain pairs() order is unspecified, which
-- would silently break client/server resimulation agreement.

local SimUtil = {}

function SimUtil.sortedKeys<K, V>(map: { [K]: V }): { K }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

return SimUtil
