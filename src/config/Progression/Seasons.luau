--!strict

-- Season pass definitions.
--
-- HARD INVARIANT: season definitions are never deleted, only marked Archived.
-- A player offline across a whole season still carries that season's id in
-- their profile; if the definition is gone, BattlePassService cannot look up
-- what they were owed and their unclaimed rewards vanish silently. This cannot
-- be enforced statically -- it is a rule.
--
-- Curve: threshold(n) = 600n + 8n^2, ~20k XP for all 25 tiers. At roughly
-- 1,650 XP/hour that is ~12 hours of play across a 6-week season, completable
-- by a casual player with headroom rather than only by grinders.

local Cosmetics = require(script.Parent.Parent.Cosmetics.Cosmetics)

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
	CosmeticRewards: { [string]: { [number]: { { Key: string, ItemId: string } } } }?,
}

local TIER_COUNT = 25

local function thresholds(count: number): { number }
	local list = {}
	for tier = 1, count do
		table.insert(list, 600 * tier + 8 * tier * tier)
	end
	return list
end

-- 1788307200 is 2026-09-02T00:00:00Z, so the six-week window ends
-- 2026-10-14T00:00:00Z. The comment here previously said September 1, which the
-- value never matched; dates are the release owner's to set, so the description
-- was corrected to the value rather than the value to the description. Confirm
-- both against the intended commercial window before advertising it.
local S1_START = 1788307200
local SIX_WEEKS = 42 * 24 * 60 * 60

local Definitions: { [string]: SeasonDef } = {
	S1 = {
		Id = "S1",
		DisplayName = "Season 1: First Splat",
		StartsAt = S1_START,
		EndsAt = S1_START + SIX_WEEKS,
		TierCount = TIER_COUNT,
		XpThresholds = thresholds(TIER_COUNT),
		-- Existing currency rewards remain payable; cosmetic additions have independent grant identities.
		FreeRewards = {
			[2] = { kind = "Bonks", amount = 250 },
			[4] = { kind = "Bonks", amount = 300 },
			[6] = { kind = "Bonks", amount = 350 },
			[9] = { kind = "Bonks", amount = 300 },
			[12] = { kind = "Bonks", amount = 500 },
			[15] = { kind = "Bonks", amount = 300 },
			[18] = { kind = "Bonks", amount = 700 },
			[21] = { kind = "Bonks", amount = 300 },
			[25] = { kind = "Bonks", amount = 300 },
		},
		PremiumRewards = {
			[1] = { kind = "Bonks", amount = 300 },
			[3] = { kind = "Bonks", amount = 500 },
			[5] = { kind = "Bonks", amount = 600 },
			[7] = { kind = "Bonks", amount = 300 },
			[8] = { kind = "Bonks", amount = 500 },
			[10] = { kind = "Bonks", amount = 600 },
			[11] = { kind = "Bonks", amount = 300 },
			[13] = { kind = "Bonks", amount = 750 },
			[14] = { kind = "Bonks", amount = 600 },
			[16] = { kind = "Bonks", amount = 300 },
			[17] = { kind = "Bonks", amount = 750 },
			[19] = { kind = "Bonks", amount = 600 },
			[20] = { kind = "Bonks", amount = 300 },
			[22] = { kind = "Bonks", amount = 1000 },
			[23] = { kind = "Bonks", amount = 600 },
			[24] = { kind = "Bonks", amount = 600 },
			[25] = { kind = "Bonks", amount = 1500 },
		},
		CosmeticRewards = {
			Free = {
				[4] = { { Key = "launch", ItemId = "DodgeBall3" } },
				[9] = { { Key = "launch", ItemId = "StarPop" } },
				[15] = { { Key = "launch", ItemId = "Hammer1" } },
				[21] = { { Key = "launch", ItemId = "ConfettiImpact" } },
				[25] = { { Key = "launch", ItemId = "SundaeSprinter" } },
			},
			Premium = {
				[1] = { { Key = "launch", ItemId = "DodgeBall1" } },
				[5] = { { Key = "launch", ItemId = "Hammer10" } },
				[7] = { { Key = "launch", ItemId = "FoamLeague" } },
				[8] = { { Key = "launch", ItemId = "CandyCrash" } },
				[10] = { { Key = "launch", ItemId = "JellySplash" } },
				[14] = { { Key = "launch", ItemId = "Hammer20" } },
				[16] = { { Key = "launch", ItemId = "RainHopper" } },
				[17] = { { Key = "launch", ItemId = "BubbleBurst" } },
				[20] = { { Key = "launch", ItemId = "OrbitRookie" } },
				[23] = { { Key = "launch", ItemId = "RoyalParty" } },
				[25] = { { Key = "launch", ItemId = "PartyRoyal" } },
			},
		},
	},
}

local seen: { [string]: boolean } = {}
local windows: { SeasonDef } = {}

for key, definition in Definitions do
	assert(definition.Id == key, `season "{key}" must match its Id`)
	assert(not seen[definition.Id], `duplicate season id "{definition.Id}"`)
	seen[definition.Id] = true
	assert(definition.StartsAt < definition.EndsAt, `season "{key}" must start before it ends`)
	assert(definition.TierCount > 0, `season "{key}" must define tiers`)
	assert(#definition.XpThresholds == definition.TierCount, `season "{key}" needs one XP threshold per tier`)
	for tier = 2, definition.TierCount do
		assert(
			definition.XpThresholds[tier] > definition.XpThresholds[tier - 1],
			`season "{key}" XP thresholds must strictly increase`
		)
	end
	for _, track in { definition.FreeRewards, definition.PremiumRewards } do
		for tier, reward in track do
			assert(
				tier % 1 == 0 and tier >= 1 and tier <= definition.TierCount,
				`season "{key}" rewards a tier outside 1..{definition.TierCount}`
			)
			-- XP rewards would feed back into season XP and advance the very
			-- track that granted them.
			assert(reward.kind ~= "XP", `season "{key}" must not reward XP`)
			if reward.kind == "Cosmetic" then
				assert(
					reward.itemId ~= nil and Cosmetics.Items[reward.itemId] ~= nil,
					`season "{key}" rewards unknown cosmetic "{tostring(reward.itemId)}"`
				)
			elseif reward.kind == "Bonks" then
				assert((reward.amount or 0) > 0, `season "{key}" Bonks reward must be positive`)
			end
		end
	end
	for track, tiers in definition.CosmeticRewards or {} do
		assert(track == "Free" or track == "Premium", `season "{key}" has an invalid cosmetic track`)
		local baseRewards = if track == "Free" then definition.FreeRewards else definition.PremiumRewards
		for tier, rewards in tiers do
			assert(baseRewards[tier] ~= nil, `season "{key}" cosmetic tier must have a claimable base reward`)
			local keys = {}
			for _, reward in rewards do
				assert(type(reward.Key) == "string" and reward.Key ~= "", `season "{key}" cosmetic needs a grant key`)
				assert(not keys[reward.Key], `season "{key}" repeats a cosmetic grant key at tier {tier}`)
				assert(Cosmetics.Items[reward.ItemId] ~= nil, `season "{key}" names unknown cosmetic {reward.ItemId}`)
				keys[reward.Key] = true
			end
		end
	end
	if not definition.Archived then
		table.insert(windows, definition)
	end
end

table.sort(windows, function(left, right)
	return left.StartsAt < right.StartsAt
end)
for index = 2, #windows do
	assert(
		windows[index].StartsAt >= windows[index - 1].EndsAt,
		`seasons "{windows[index - 1].Id}" and "{windows[index].Id}" overlap`
	)
end

return {
	Definitions = Definitions,
}
