-- Description: Pure season pass rules: which season is live, what tier an XP total buys, what is still owed, and whether a claim is legal, with time always passed in.

--!strict

local BattlePassLogic = {}
local SeasonCosmetics = require(script.Parent.SeasonCosmetics)

export type TierReward = {
	kind: string,
	amount: number?,
	itemId: string?,
}

export type SeasonDef = {
	Id: string,
	DisplayName: string,
	StartsAt: number,
	EndsAt: number,
	Archived: boolean?,
	TierCount: number,
	XpThresholds: { number },
	FreeRewards: { [number]: TierReward },
	PremiumRewards: { [number]: TierReward },
	CosmeticRewards: any?,
}

export type SeasonState = {
	Id: string,
	XP: number,
	ClaimedFree: { [string]: boolean },
	ClaimedPremium: { [string]: boolean },
	CosmeticClaims: { [string]: boolean },
}

export type Track = "Free" | "Premium"

export type OwedTier = {
	tier: number,
	track: Track,
	reward: TierReward,
}

export type ClaimReason =
	"no_active_season"
	| "unknown_tier"
	| "tier_locked"
	| "already_claimed"
	| "premium_required"
	| "no_reward"

function BattlePassLogic.blankState(seasonId: string): SeasonState
	return {
		Id = seasonId,
		XP = 0,
		ClaimedFree = {},
		ClaimedPremium = {},
		CosmeticClaims = {},
	}
end

function BattlePassLogic.validateStoredState(raw: any, path: string, expectedId: string?): (boolean, string?)
	if type(raw) ~= "table" then
		return false, `{path}: expected table`
	end
	if type(raw.Id) ~= "string" or (expectedId ~= nil and raw.Id ~= expectedId) then
		return false, `{path}.Id: expected {if expectedId ~= nil then expectedId else "string"}, got {tostring(raw.Id)}`
	end
	local xp = raw.XP
	if type(xp) ~= "number" or xp < 0 or xp % 1 ~= 0 or xp == math.huge then
		return false, `{path}.XP: expected finite nonnegative integer, got {tostring(xp)}`
	end
	for _, field in { "ClaimedFree", "ClaimedPremium" } do
		local claims = raw[field]
		if type(claims) ~= "table" then
			return false, `{path}.{field}: expected table`
		end
		for key, claimed in claims do
			local numeric = if type(key) == "number" then key else if type(key) == "string" then tonumber(key) else nil
			if numeric == nil or numeric < 1 or numeric % 1 ~= 0 or (type(key) == "string" and tostring(numeric) ~= key) then
				return false, `{path}.{field}.{tostring(key)}: expected positive integer tier key`
			end
			if type(claimed) ~= "boolean" then
				return false, `{path}.{field}.{tostring(key)}: expected boolean marker`
			end
		end
	end
	local cosmetics = raw.CosmeticClaims
	if cosmetics ~= nil then
		if type(cosmetics) ~= "table" then
			return false, `{path}.CosmeticClaims: expected table`
		end
		for key, claimed in cosmetics do
			if type(key) ~= "string" then
				return false, `{path}.CosmeticClaims.{tostring(key)}: expected string key`
			end
			if type(claimed) ~= "boolean" then
				return false, `{path}.CosmeticClaims.{key}: expected boolean marker`
			end
		end
	end
	return true, nil
end

function BattlePassLogic.readState(raw: any): SeasonState
	if raw == nil then
		return BattlePassLogic.blankState("")
	end
	local valid, reason = BattlePassLogic.validateStoredState(raw, "Season")
	assert(valid, reason)
	local state = BattlePassLogic.blankState(raw.Id)
	state.XP = raw.XP
	for _, field in { "ClaimedFree", "ClaimedPremium", "CosmeticClaims" } do
		local source = raw[field]
		if source ~= nil then
			for tier, claimed in source do
				if claimed == true then
					(state :: any)[field][tostring(tier)] = true
				end
			end
		end
	end
	return state
end

function BattlePassLogic.activeSeason(definitions: { [string]: SeasonDef }, now: number): SeasonDef?
	local best: SeasonDef? = nil
	for _, definition in definitions do
		if not definition.Archived and now >= definition.StartsAt and now < definition.EndsAt then
			if best == nil or definition.StartsAt < best.StartsAt then
				best = definition
			end
		end
	end
	return best
end

function BattlePassLogic.tierForXp(season: SeasonDef, xp: number): number
	local tier = 0
	for index, threshold in season.XpThresholds do
		if xp >= threshold then
			tier = index
		else
			break
		end
	end
	return math.min(tier, season.TierCount)
end

function BattlePassLogic.tierProgress(season: SeasonDef, xp: number): (number, number, number)
	local tier = BattlePassLogic.tierForXp(season, xp)
	if tier >= season.TierCount then
		return tier, 0, 0
	end
	local floorXp = if tier == 0 then 0 else season.XpThresholds[tier]
	local nextXp = season.XpThresholds[tier + 1]
	return tier, xp - floorXp, nextXp - floorXp
end

function BattlePassLogic.rewardAt(season: SeasonDef, tier: number, track: Track): TierReward?
	local rewards = if track == "Premium" then season.PremiumRewards else season.FreeRewards
	return rewards[tier]
end

local function claimedSet(state: SeasonState, track: Track): { [string]: boolean }
	return if track == "Premium" then state.ClaimedPremium else state.ClaimedFree
end

function BattlePassLogic.isClaimed(state: SeasonState, tier: number, track: Track): boolean
	return claimedSet(state, track)[tostring(tier)] == true
end

function BattlePassLogic.canClaim(
	season: SeasonDef,
	state: SeasonState,
	tier: number,
	track: Track,
	hasPremium: boolean
): (boolean, ClaimReason?)
	if tier % 1 ~= 0 or tier < 1 or tier > season.TierCount then
		return false, "unknown_tier"
	end
	if track == "Premium" and not hasPremium then
		return false, "premium_required"
	end
	if BattlePassLogic.rewardAt(season, tier, track) == nil then
		return false, "no_reward"
	end
	if BattlePassLogic.isClaimed(state, tier, track) then
		return false, "already_claimed"
	end
	if BattlePassLogic.tierForXp(season, state.XP) < tier then
		return false, "tier_locked"
	end
	return true, nil
end

function BattlePassLogic.unclaimedTiers(season: SeasonDef, state: SeasonState, hasPremium: boolean): { OwedTier }
	local owed: { OwedTier } = {}
	for tier = 1, season.TierCount do
		for _, track in { "Free", "Premium" } :: { Track } do
			local ok = BattlePassLogic.canClaim(season, state, tier, track, hasPremium)
			if ok then
				table.insert(owed, {
					tier = tier,
					track = track,
					reward = BattlePassLogic.rewardAt(season, tier, track) :: TierReward,
				})
			end
		end
	end
	return owed
end

local function cloneReward(reward: TierReward?): TierReward?
	if reward == nil then
		return nil
	end
	return { kind = reward.kind, amount = reward.amount, itemId = reward.itemId }
end

function BattlePassLogic.publicState(
	season: SeasonDef?,
	state: SeasonState,
	hasPremium: boolean,
	productId: number?
): any
	if season == nil then
		return {
			seasonId = "",
			active = false,
			tiers = {},
		}
	end
	local tier, intoTier, forNextTier = BattlePassLogic.tierProgress(season, state.XP)
	local tiers = {}
	for index = 1, season.TierCount do
		table.insert(tiers, {
			tier = index,
			unlocked = index <= tier,
			freeReward = cloneReward(BattlePassLogic.rewardAt(season, index, "Free")),
			premiumReward = cloneReward(BattlePassLogic.rewardAt(season, index, "Premium")),
			freeClaimed = BattlePassLogic.isClaimed(state, index, "Free"),
			premiumClaimed = BattlePassLogic.isClaimed(state, index, "Premium"),
			freeCosmetics = SeasonCosmetics.public(season, state, index, "Free"),
			premiumCosmetics = SeasonCosmetics.public(season, state, index, "Premium"),
		})
	end
	return {
		seasonId = season.Id,
		active = true,
		displayName = season.DisplayName,
		startsAt = season.StartsAt,
		endsAt = season.EndsAt,
		xp = state.XP,
		tier = tier,
		tierCount = season.TierCount,
		xpIntoTier = intoTier,
		xpForNextTier = forNextTier,
		hasPremium = hasPremium,
		premiumProductId = productId,
		tiers = tiers,
	}
end

return BattlePassLogic
