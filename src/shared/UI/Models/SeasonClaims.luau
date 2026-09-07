--!strict
-- Derives claimable rewards from the server's season projection.

local SeasonClaims = {}

function SeasonClaims.pendingCosmetics(rewards: { any }?): boolean
	for _, reward in rewards or {} do
		if reward.claimed ~= true then
			return true
		end
	end
	return false
end

function SeasonClaims.count(state: any): number
	if state == nil or state.active ~= true then
		return 0
	end
	local count = 0
	for _, tier in state.tiers or {} do
		if tier.unlocked then
			if tier.freeReward and (not tier.freeClaimed or SeasonClaims.pendingCosmetics(tier.freeCosmetics)) then
				count += 1
			end
			if
				state.hasPremium
				and tier.premiumReward
				and (not tier.premiumClaimed or SeasonClaims.pendingCosmetics(tier.premiumCosmetics))
			then
				count += 1
			end
		end
	end
	return count
end

return SeasonClaims
