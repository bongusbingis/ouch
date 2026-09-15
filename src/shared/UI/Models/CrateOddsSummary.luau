--!strict
-- Summaries only claim a shared probability/refund when every outcome agrees.
local Summary = {}
function Summary.shared(outcomes)
	local first = outcomes[1]
	if not first then
		return nil, nil, nil
	end
	local chance, base, refund = first.percent, first.basePercent, first.bonksRefund or 0
	for _, entry in outcomes do
		if entry.percent ~= chance then
			chance = nil
		end
		if entry.basePercent ~= base then
			base = nil
		end
		if (entry.bonksRefund or 0) ~= refund then
			refund = nil
		end
	end
	return chance, base, refund
end
return table.freeze(Summary)
