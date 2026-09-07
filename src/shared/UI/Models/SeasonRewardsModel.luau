-- Derives reward identity, access and selection from the server's season projection.
--!strict

local Model = {}

function Model.entries(state: any): { any }
	local entries = {}
	if state == nil then
		return entries
	end
	for _, tier in state.tiers or {} do
		for _, track in { "Free", "Premium" } do
			local premium = track == "Premium"
			local reward = if premium then tier.premiumReward else tier.freeReward
			local claimed = if premium then tier.premiumClaimed else tier.freeClaimed
			local additions = if premium then tier.premiumCosmetics else tier.freeCosmetics
			local function append(kind, amount, itemId, collected, suffix)
				local needsPremium = premium and not state.hasPremium
				table.insert(entries, {
					key = `{tier.tier}:{track}:{suffix}`,
					tier = tier.tier,
					track = track,
					kind = kind,
					amount = amount,
					itemId = itemId,
					claimed = collected == true,
					unlocked = tier.unlocked == true,
					needsPremium = needsPremium,
					claimable = state.active == true
						and tier.unlocked == true
						and not needsPremium
						and collected ~= true,
				})
			end
			if reward then
				append(reward.kind, reward.amount, reward.itemId, claimed, "Base")
			end
			for _, item in additions or {} do
				append("Cosmetic", nil, item.itemId, item.claimed, item.itemId)
			end
		end
	end
	return entries
end

function Model.selected(entries: { any }, key: string?): any?
	for _, entry in entries do
		if entry.key == key then
			return entry
		end
	end
	for _, entry in entries do
		if entry.claimable then
			return entry
		end
	end
	for _, entry in entries do
		if not entry.unlocked and not entry.needsPremium then
			for _, reward in entries do
				if reward.tier == entry.tier and reward.kind == "Cosmetic" and not reward.needsPremium then
					return reward
				end
			end
			return entry
		end
	end
	return entries[1]
end

function Model.requirement(entry: any): string
	if entry.claimed then
		return if entry.kind == "Bonks" then "CLAIMED" else "IN YOUR BACKPACK"
	elseif entry.needsPremium then
		return if entry.unlocked then "GET THE PREMIUM PASS TO UNLOCK" else `PREMIUM PASS + TIER {entry.tier}`
	elseif not entry.unlocked then
		return `REACH TIER {entry.tier} TO UNLOCK`
	end
	return "READY TO CLAIM"
end

return table.freeze(Model)
