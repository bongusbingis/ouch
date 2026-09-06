--!strict
-- Derives claimable rewards from the server's season projection.

local SeasonClaims = {}

function SeasonClaims.count(state: any): number
	if state == nil or state.active ~= true then
		return 0
	end
	local count = 0
	for _, tier in state.tiers or {} do
		if tier.unlocked then
			if tier.freeReward and not tier.freeClaimed then
				count += 1
			end
			if state.hasPremium and tier.premiumReward and not tier.premiumClaimed then
				count += 1
			end
		end
	end
	return count
end

return SeasonClaims
