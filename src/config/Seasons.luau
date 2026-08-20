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

local Cosmetics = require(script.Parent.Cosmetics)

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
}

local TIER_COUNT = 25

local function thresholds(count: number): { number }
	local list = {}
	for tier = 1, count do
		table.insert(list, 600 * tier + 8 * tier * tier)
	end
	return list
end

-- 2026-09-01T00:00:00Z, running six weeks with a one-week rest before S2.
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
		-- The free track has to be worth engaging with: it is the on-ramp that
		-- makes the premium track legible before anyone is asked to pay.
		FreeRewards = {
			[2] = { kind = "Bonks", amount = 250 },
			[4] = { kind = "Cosmetic", itemId = "TrailCoralGlow" },
			[6] = { kind = "Bonks", amount = 350 },
			[9] = { kind = "Cosmetic", itemId = "TrailSlateStreak" },
			[12] = { kind = "Bonks", amount = 500 },
			[15] = { kind = "Cosmetic", itemId = "TrailLavenderDrift" },
			[18] = { kind = "Bonks", amount = 700 },
			[21] = { kind = "Cosmetic", itemId = "TrailPeachFizz" },
			[25] = { kind = "Cosmetic", itemId = "TrailAquaLine" },
		},
		PremiumRewards = {
			[1] = { kind = "Cosmetic", itemId = "TrailHoneyGlide" },
			[3] = { kind = "Bonks", amount = 500 },
			[5] = { kind = "Cosmetic", itemId = "TrailStaticSnap" },
			[7] = { kind = "Cosmetic", itemId = "TrailBerryDash" },
			[8] = { kind = "Bonks", amount = 500 },
			[10] = { kind = "Cosmetic", itemId = "TrailPollenBurst" },
			[11] = { kind = "Cosmetic", itemId = "TrailSageWisp" },
			[13] = { kind = "Bonks", amount = 750 },
			[14] = { kind = "Cosmetic", itemId = "TrailInkSpill" },
			[16] = { kind = "Cosmetic", itemId = "TrailCopperArc" },
			[17] = { kind = "Bonks", amount = 750 },
			[19] = { kind = "Cosmetic", itemId = "TrailCitrusFlare" },
			[20] = { kind = "Cosmetic", itemId = "TrailIndigoTrace" },
			[22] = { kind = "Bonks", amount = 1000 },
			[23] = { kind = "Cosmetic", itemId = "TrailGlacierEdge" },
			[24] = { kind = "Cosmetic", itemId = "TrailRubyStreak" },
			-- Retired permanently when the season ends.
			[25] = { kind = "Cosmetic", itemId = "TrailPhoenixPlume" },
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
