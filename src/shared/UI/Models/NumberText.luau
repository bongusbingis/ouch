-- Whole-number grouping shared by prices, refunds, balances, and reward summaries.
--!strict

return function(value: number): string
	local out = tostring(math.floor(value))
	while true do
		local replaced, count = string.gsub(out, "^(%-?%d+)(%d%d%d)", "%1,%2")
		out = replaced
		if count == 0 then
			return out
		end
	end
end
