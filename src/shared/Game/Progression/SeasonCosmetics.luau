--!strict

-- Supplemental season cosmetics are keyed grants; changing content never reissues a tier's currency.

local SeasonCosmetics = {}

function SeasonCosmetics.at(season: any, tier: number, track: string): { any }
	local tracks = season.CosmeticRewards
	return if tracks and tracks[track] then tracks[track][tier] or {} else {}
end

function SeasonCosmetics.key(tier: number, track: string, reward: any): string
	return `{track}:{tier}:{reward.Key}:{reward.ItemId}`
end

function SeasonCosmetics.pending(season: any, state: any, premium: boolean): { any }
	local pending = {}
	local completed = if state.CosmeticClaims == nil then {} else state.CosmeticClaims
	for tier = 1, season.TierCount do
		for _, track in { "Free", "Premium" } do
			local claimed = if track == "Free" then state.ClaimedFree else state.ClaimedPremium
			if (track == "Free" or premium) and claimed[tostring(tier)] == true then
				for _, reward in SeasonCosmetics.at(season, tier, track) do
					local key = SeasonCosmetics.key(tier, track, reward)
					if completed[key] ~= true then
						table.insert(pending, { key = key, itemId = reward.ItemId })
					end
				end
			end
		end
	end
	return pending
end

function SeasonCosmetics.public(season: any, state: any, tier: number, track: string): { any }
	local rewards = {}
	local completed = if state.CosmeticClaims == nil then {} else state.CosmeticClaims
	for _, reward in SeasonCosmetics.at(season, tier, track) do
		table.insert(rewards, {
			kind = "Cosmetic",
			itemId = reward.ItemId,
			claimed = completed[SeasonCosmetics.key(tier, track, reward)] == true,
		})
	end
	return rewards
end

return SeasonCosmetics
