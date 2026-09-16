-- Reproducible R11 economy model. Reads release configs; writes evidence only.
-- Exact finite-state pity/target calculation, plus seeded collection simulation.
--!nonstrict
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Loader = require("./loader")

local out = ".review/production/2026-09-09-batch1/r11"
fs.writeDir(out)
local map = process.exec("rojo", { "sourcemap", "tests.project.json", "-o", out .. "/sourcemap.json" })
assert(map.ok, map.stderr)
local root, pure = Loader.build(out .. "/sourcemap.json")
local config, game = root.ReplicatedStorage.Config, root.ReplicatedStorage.Shared.Game
local Cosmetics = pure(config.Cosmetics.Cosmetics)
local Crates = pure(config.Economy.Crates)
local Shop = pure(config.Economy.Shop)
local Passes = pure(config.Economy.GamePasses)
local Data = pure(config.Progression.Data)
local Seasons = pure(config.Progression.Seasons)
local Quests = pure(config.Progression.Quests)
local Daily = pure(config.DailyRewards)
local Odds = pure(game.Economy.CrateOdds)
local Rolls = pure(game.Economy.CrateRolls)
local Boosts = pure(game.Economy.Boosts)
local Featured = pure(game.Economy.FeaturedRotation)
local ShopRotation = pure(game.Economy.ShopRotation)
local DailyLogic = pure(game.DailyReward.DailyRewardLogic)
local BattlePass = pure(game.Progression.BattlePassLogic)
local rarityNames = { "Common", "Rare", "Legendary" }
local epsilon = 1e-12
local function sum(values)
	local total = 0
	for _, value in values do
		total += value
	end
	return total
end
local function key(pity)
	return tostring(pity.Rare or 0) .. ":" .. tostring(pity.Legendary or 0)
end
local function fresh(n)
	local values = table.create(n, 0)
	values[1] = 1
	return values
end
local validations = {}
local function check(name, condition)
	assert(condition, name)
	table.insert(validations, name)
end

-- Every probability and counter transition is taken from actual pure source.
local function chain(crate)
	local states, indices, edges = { {} }, { ["0:0"] = 1 }, {}
	local cursor = 1
	while cursor <= #states do
		local pity = states[cursor]
		local model = Odds.build(crate, Cosmetics.Items, Cosmetics.Rarities, pity)
		local row, mass, lower = {}, 0, 0
		for _, rarity in model.rarityOrder do
			local bucket = model.buckets[rarity]
			local probability = 0
			for _, outcome in model.outcomes do
				if outcome.rarity == rarity then
					probability += outcome.probability
				end
			end
			if probability > 0 then
				local pick = (lower + Cosmetics.Rarities[rarity].Weight / 2) / model.totalWeight
				local rolled = Rolls.roll(crate, Cosmetics.Items, Cosmetics.Rarities, {}, {
					NextNumber = function()
						return pick
					end,
					NextInteger = function()
						return 1
					end,
				}, pity)
				assert(rolled.rarity == rarity and not rolled.isDupe and rolled.bonksRefund == 0, "new roll mismatch")
				local owned = { [rolled.itemId] = true }
				local dupe = Rolls.roll(crate, Cosmetics.Items, Cosmetics.Rarities, owned, {
					NextNumber = function()
						return pick
					end,
					NextInteger = function()
						return 1
					end,
				}, pity)
				assert(
					dupe.isDupe and dupe.bonksRefund == Cosmetics.Rarities[rarity].DupeBonks,
					"duplicate refund mismatch"
				)
				local nextKey = key(rolled.pity)
				if not indices[nextKey] then
					table.insert(states, rolled.pity)
					indices[nextKey] = #states
				end
				table.insert(row, { to = indices[nextKey], p = probability, rarity = rarity, bucket = bucket })
				mass += probability
			end
			lower += Cosmetics.Rarities[rarity].Weight
		end
		assert(math.abs(mass - 1) < 1e-12, "pity transition probability must sum to one")
		edges[cursor] = row
		cursor += 1
	end
	return { states = states, edges = edges, indices = indices }
end

-- Propagate probability after removing target/competitor item hazards.
local function advance(model, distribution, targetRarity, competitorRarity)
	local nextDistribution = table.create(#model.states, 0)
	local targetHit, competitorHit = 0, 0
	local counts = { Common = 0, Rare = 0, Legendary = 0 }
	for state, weight in distribution do
		if weight == 0 then
			continue
		end
		for _, edge in model.edges[state] do
			local mass = weight * edge.p
			counts[edge.rarity] += mass
			local hit = if edge.rarity == targetRarity then mass / #edge.bucket else 0
			local other = if edge.rarity == competitorRarity then mass / #edge.bucket else 0
			targetHit += hit
			competitorHit += other
			nextDistribution[edge.to] += mass - hit - other
		end
	end
	return nextDistribution, targetHit, competitorHit, counts
end

local function absorption(model, target, competitor, start)
	local distribution = table.create(#model.states, 0)
	distribution[start or 1] = 1
	local expected, win, otherWin = 0, 0, 0
	local counts = { Common = 0, Rare = 0, Legendary = 0 }
	local quantiles, survival = {}, { [0] = 1 }
	local step = 0
	while sum(distribution) > epsilon do
		step += 1
		assert(step < 20000, "target tail did not converge")
		expected += sum(distribution)
		local nextDistribution, hit, other, increment = advance(model, distribution, target, competitor)
		win += hit
		otherWin += other
		for rarity, count in increment do
			counts[rarity] += count
		end
		distribution = nextDistribution
		local remaining = sum(distribution)
		survival[step] = remaining
		for _, percentile in { 50, 90, 95 } do
			if quantiles[tostring(percentile)] == nil and remaining <= 1 - percentile / 100 then
				quantiles[tostring(percentile)] = step
			end
		end
	end
	return {
		opens = expected,
		targetFirst = win,
		otherFirst = otherWin,
		counts = counts,
		quantiles = quantiles,
		residual = sum(distribution),
		steps = step,
		survival = survival,
	}
end

local result = {
	methodology = "exact source-derived finite-state probability; seeded collection simulation separately labeled",
	crates = {},
	pacing = {},
	season = {},
	validations = validations,
	sourceHashes = {},
}
local crateIds = {}
for id, crate in Crates do
	if crate.CatalogStatus == "Active" then
		table.insert(crateIds, id)
	end
end
table.sort(crateIds)
for _, id in crateIds do
	local crate = Crates[id]
	for _, itemId in crate.ItemPool do
		local item = Cosmetics.Items[itemId]
		assert(
			not item.AlwaysAvailable and not item.Contents,
			"extend ownership marginals for composed/default crate items"
		)
		assert(item.Rarity ~= "Exclusive", "exclusive entered crate")
	end
	local model = chain(crate)
	local initialOdds = Odds.build(crate, Cosmetics.Items, Cosmetics.Rarities, {})
	local sizes = {}
	for _, rarity in rarityNames do
		sizes[rarity] = #initialOdds.buckets[rarity]
	end
	local eligibleForFeature = false
	for _, entry in Shop.Featured.Rotation do
		if entry.kind == "Crate" and entry.id == id then
			eligibleForFeature = true
		end
	end
	local discount = if eligibleForFeature
		then Featured.discountedPrice(crate.BonksPrice, Shop.Featured.DiscountPercent)
		else nil
	local info = {
		id = id,
		pool = crate.ItemPool,
		rarityCounts = sizes,
		states = #model.states,
		price = crate.BonksPrice,
		featuredPrice = discount,
		targets = {},
		horizons = {},
		collection = {},
	}
	local targetStats = {}
	for _, rarity in rarityNames do
		local stat = absorption(model, rarity)
		targetStats[rarity] = stat
		local refundsAllButTarget = 0
		for _, other in rarityNames do
			refundsAllButTarget += stat.counts[other] * Cosmetics.Rarities[other].DupeBonks
		end
		refundsAllButTarget -= Cosmetics.Rarities[rarity].DupeBonks
		local refundsNew = refundsAllButTarget
		for _, other in rarityNames do
			local newBefore = if other == rarity
				then (sizes[other] - 1) / 2
				else sizes[other] * absorption(model, rarity, other).otherFirst
			refundsNew -= newBefore * Cosmetics.Rarities[other].DupeBonks
		end
		local hotRare = model.indices[tostring(crate.Pity.Rare - 1) .. ":" .. tostring(crate.Pity.Rare - 1)]
		local hotLegendary = model.indices["0:" .. tostring(crate.Pity.Legendary - 1)]
		local entry = {
			rarity = rarity,
			representative = initialOdds.buckets[rarity][1],
			expectedOpens = stat.opens,
			median = stat.quantiles["50"],
			p90 = stat.quantiles["90"],
			p95 = stat.quantiles["95"],
			baseNetNew = stat.opens * crate.BonksPrice - refundsNew,
			baseNetAllButTargetOwned = stat.opens * crate.BonksPrice - refundsAllButTarget,
			featuredNetNew = if discount then stat.opens * discount - refundsNew else nil,
			expectedOpensRareDue = if hotRare then absorption(model, rarity, nil, hotRare).opens else nil,
			expectedOpensLegendaryDue = if hotLegendary
				then absorption(model, rarity, nil, hotLegendary).opens
				else nil,
			residualProbability = stat.residual,
			summedRolls = stat.steps,
		}
		table.insert(info.targets, entry)
	end
	local distribution = fresh(#model.states)
	local cumulative = { Common = 0, Rare = 0, Legendary = 0 }
	for n = 1, 5000 do
		local nextDistribution, _, _, counts = advance(model, distribution)
		for rarity, count in counts do
			cumulative[rarity] += count
		end
		distribution = nextDistribution
		if table.find({ 1, 2, 5, 10, 25, 50, 100, 250, 500 }, n) then
			local newItems, refundNew, refundOwned = 0, 0, 0
			for _, rarity in rarityNames do
				local survival = targetStats[rarity].survival[n] or 0
				local acquired = sizes[rarity] * (1 - survival)
				newItems += acquired
				refundOwned += cumulative[rarity] * Cosmetics.Rarities[rarity].DupeBonks
				refundNew += (cumulative[rarity] - acquired) * Cosmetics.Rarities[rarity].DupeBonks
			end
			table.insert(info.horizons, {
				opens = n,
				expectedDistinct = newItems,
				newOwnershipBaseNetPerOpen = crate.BonksPrice - refundNew / n,
				fullOwnershipBaseNetPerOpen = crate.BonksPrice - refundOwned / n,
				newOwnershipFeaturedNetPerOpen = if discount then discount - refundNew / n else nil,
			})
		end
	end
	local _, _, _, stationary = advance(model, distribution)
	local stationaryRefund = 0
	for rarity, probability in stationary do
		stationaryRefund += probability * Cosmetics.Rarities[rarity].DupeBonks
	end
	info.stationary = {
		rarity = stationary,
		refund = stationaryRefund,
		baseNetPerOpen = crate.BonksPrice - stationaryRefund,
		featuredNetPerOpen = if discount then discount - stationaryRefund else nil,
	}

	-- Cached edges use actual Odds/Rolls transitions; seed and independent item draw are explicit.
	local seed, runs = 20260909, 5000
	local function random()
		seed = seed * 16807 % 2147483647
		return (seed - 1) / 2147483646
	end
	local completed, opensTotal, squared, sinkTotal = {}, 0, 0, 0
	local targetSamples = {}
	for _, target in info.targets do
		targetSamples[target.representative] = { opens = 0, opensSquared = 0, net = 0, netSquared = 0 }
	end
	for _ = 1, runs do
		local owned, state, opened, distinct, refund = {}, 1, 0, 0, 0
		while distinct < #crate.ItemPool do
			opened += 1
			assert(opened < 20000, "collection simulation exceeded horizon")
			local pick, selected = random(), nil
			for _, edge in model.edges[state] do
				selected = edge
				pick -= edge.p
				if pick <= 0 then
					break
				end
			end
			local itemId = selected.bucket[math.floor(random() * #selected.bucket) + 1]
			state = selected.to
			if owned[itemId] then
				refund += Cosmetics.Rarities[selected.rarity].DupeBonks
			else
				owned[itemId] = true
				distinct += 1
				local sample = targetSamples[itemId]
				if sample then
					local net = opened * crate.BonksPrice - refund
					sample.opens += opened
					sample.opensSquared += opened * opened
					sample.net += net
					sample.netSquared += net * net
				end
			end
		end
		table.insert(completed, opened)
		opensTotal += opened
		squared += opened * opened
		sinkTotal += opened * crate.BonksPrice - refund
	end
	table.sort(completed)
	local mean = opensTotal / runs
	info.collection = {
		method = "seeded Monte Carlo, no direct/season grants",
		seed = 20260909,
		runs = runs,
		meanOpens = mean,
		meanStandardError = math.sqrt((squared - runs * mean * mean) / (runs - 1) / runs),
		median = completed[math.ceil(runs * 0.5)],
		p90 = completed[math.ceil(runs * 0.9)],
		meanBaseNetBonks = sinkTotal / runs,
	}
	info.targetMonteCarloCrosscheck = {}
	for _, target in info.targets do
		local sample = targetSamples[target.representative]
		local openMean, netMean = sample.opens / runs, sample.net / runs
		local openSe = math.sqrt((sample.opensSquared - runs * openMean * openMean) / (runs - 1) / runs)
		local netSe = math.sqrt((sample.netSquared - runs * netMean * netMean) / (runs - 1) / runs)
		check(
			id .. " " .. target.rarity .. " target opens/net agree with seeded simulation within 5 standard errors",
			math.abs(openMean - target.expectedOpens) <= 5 * openSe
				and math.abs(netMean - target.baseNetNew) <= 5 * netSe
		)
		table.insert(info.targetMonteCarloCrosscheck, {
			rarity = target.rarity,
			meanOpens = openMean,
			opensStandardError = openSe,
			meanNet = netMean,
			netStandardError = netSe,
		})
	end
	table.insert(result.crates, info)
	check(id .. " reachable transitions and refunds match actual Odds/Rolls", true)
	print(id .. ": " .. #model.states .. " reachable pity states; " .. #crate.ItemPool .. " items")
end

local scenarios = {
	{ name = "New", round = 6, queue = 1.5, results = 0.5, replay = 0, elims = 0, catches = 0, wins = 0.05 },
	{ name = "Casual", round = 5, queue = 1, results = 0.5, replay = 0.25, elims = 2, catches = 1, wins = 0.20 },
	{ name = "Skilled", round = 4, queue = 1, results = 0.5, replay = 0.75, elims = 6, catches = 3, wins = 0.40 },
	{ name = "Completionist", round = 4, queue = 1, results = 0.5, replay = 0.90, elims = 4, catches = 2, wins = 0.25 },
}
local season = Seasons.Definitions.S1
local thresholds = season.XpThresholds
local seasonCurrency, seasonCosmetics = { Free = 0, Premium = 0 }, { Free = 0, Premium = 0 }
for _, track in { "Free", "Premium" } do
	for _, reward in season[track .. "Rewards"] do
		if reward.kind == "Bonks" then
			seasonCurrency[track] += reward.amount
		end
	end
	for _, rewards in season.CosmeticRewards[track] do
		seasonCosmetics[track] += #rewards
	end
end
for _, assumptions in scenarios do
	for _, boosted in { false, true } do
		local multi = Boosts.multipliers(Passes.Catalog, if boosted then { DoubleXP = true, BonksBoost = true } else {})
		local cycle = assumptions.round + assumptions.results + (1 - assumptions.replay) * assumptions.queue
		local xp = Data.ProgressionXP.MatchComplete
			+ assumptions.elims * Data.ProgressionXP.Elim
			+ assumptions.catches * Data.ProgressionXP.Catch
		local bonks = Data.ProgressionBonks.MatchComplete
			+ assumptions.elims * Data.ProgressionBonks.Elim
			+ assumptions.catches * Data.ProgressionBonks.Catch
		local earnedXp = (1 - assumptions.wins) * Boosts.apply(xp, multi.Xp)
			+ assumptions.wins * Boosts.apply(xp + Data.ProgressionXP.Win, multi.Xp)
		local earnedBonks = (1 - assumptions.wins) * Boosts.apply(bonks, multi.Bonks)
			+ assumptions.wins * Boosts.apply(bonks + Data.ProgressionBonks.Win, multi.Bonks)
		local bonksHour, xpHour = earnedBonks * 60 / cycle, earnedXp * 60 / cycle
		table.insert(result.pacing, {
			cohort = assumptions.name,
			boosted = boosted,
			assumptions = assumptions,
			cycleMinutes = cycle,
			bonksPerMatch = earnedBonks,
			xpPerMatch = earnedXp,
			bonksPerHour = bonksHour,
			xpPerHour = xpHour,
			commonMinutesFromStartingBalance = math.max(0, Cosmetics.Rarities.Common.DirectBonks - Data.Template.Bonks)
				/ bonksHour
				* 60,
			rareMinutesFromStartingBalance = math.max(0, Cosmetics.Rarities.Rare.DirectBonks - Data.Template.Bonks)
				/ bonksHour
				* 60,
			legendaryMinutesFromStartingBalance = math.max(
				0,
				Cosmetics.Rarities.Legendary.DirectBonks - Data.Template.Bonks
			) / bonksHour * 60,
			baseCrateMinutesFromZero = Crates.DodgeballCrate.BonksPrice / bonksHour * 60,
			tier25Hours = thresholds[#thresholds] / xpHour,
			firstFreeSeasonCurrencyHours = thresholds[2] / xpHour,
			firstFreeSeasonCosmeticHours = thresholds[4] / xpHour,
		})
	end
end
local rewardAmounts, totalDaily = {}, 0
for _, reward in Daily.Rewards do
	totalDaily += reward.amount
end
for _, quest in Quests.Definitions do
	table.insert(rewardAmounts, quest.reward.amount)
end
table.sort(rewardAmounts)
local minQuest, maxQuest = 0, 0
for index = 1, Quests.DailyCount do
	minQuest += rewardAmounts[index]
	maxQuest += rewardAmounts[#rewardAmounts - index + 1]
end
result.claims = {
	dailyCycleBonks = totalDaily,
	dailyCycleClaims = Daily.CycleLength,
	questCount = Quests.DailyCount,
	selectedThreeMin = minQuest,
	selectedThreeMax = maxQuest,
	allDefinitionsMean = sum(rewardAmounts) / #rewardAmounts,
	note = "Claim/completion rates unmeasured; no daily or quest currency included in match Bonks/hour.",
}
result.shop = {
	eligiblePoolCount = #ShopRotation.pool(Cosmetics.Items, Shop.Rotation.Categories),
	offerCount = #Shop.Rotation.Roles,
	rotationSeconds = Shop.Rotation.RotationSeconds,
	note = "Direct-item timing is affordability only; target offer wait is not modeled or guaranteed.",
}
result.season = {
	id = season.Id,
	startsAt = season.StartsAt,
	endsAt = season.EndsAt,
	startsUtc = os.date("!%Y-%m-%dT%H:%M:%SZ", season.StartsAt),
	endsUtc = os.date("!%Y-%m-%dT%H:%M:%SZ", season.EndsAt),
	tiers = season.TierCount,
	thresholds = thresholds,
	bonks = seasonCurrency,
	cosmeticGrantEntries = seasonCosmetics,
	sensitivity = {},
}
-- Source start plus the actual planned September 12 launch and later UTC joins.
for _, day in { 1, 11, 25, 39 } do
	local join = season.StartsAt + (day - 1) * 86400
	local remaining = (season.EndsAt - join) / 86400
	local entry = { joinUtc = os.date("!%Y-%m-%d", join), remainingDays = remaining, cohorts = {} }
	for _, pacing in result.pacing do
		table.insert(entry.cohorts, {
			cohort = pacing.cohort,
			boosted = pacing.boosted,
			minutesPerRemainingDay = pacing.tier25Hours * 60 / remaining,
		})
	end
	table.insert(result.season.sensitivity, entry)
end

local state = DailyLogic.blankState()
local first, claim = DailyLogic.claim(state, Daily, season.StartsAt + 86399)
check("daily first claim pays configured day one", claim.reward.amount == Daily.Rewards[1].amount)
check("daily same UTC day cannot reclaim", DailyLogic.claim(first, Daily, season.StartsAt + 86399) == nil)
local second = DailyLogic.claim(first, Daily, season.StartsAt + 86400)
check("daily UTC midnight advances one day", second.Day == 2)
local later = DailyLogic.claim(second, Daily, season.StartsAt + 8 * 86400)
check("missed daily claims preserve cycle progress without reset", later.Day == 3)
check("season starts inclusive", BattlePass.activeSeason(Seasons.Definitions, season.StartsAt) == season)
check(
	"season ends exclusive and no S2 currently configured",
	BattlePass.activeSeason(Seasons.Definitions, season.EndsAt) == nil
)
local seasonState = BattlePass.blankState(season.Id)
seasonState.XP = thresholds[#thresholds]
local owedFree, owedBoth =
	BattlePass.unclaimedTiers(season, seasonState, false), BattlePass.unclaimedTiers(season, seasonState, true)
check("full season free/premium claims match config", #owedFree == 9 and #owedBoth == 26)

-- Reported by the root agent's actual lobby Studio Play inspection on 2026-09-09.
-- This is a separate price sensitivity, not an effective-config fetch by this probe.
-- Pool, probability, refund, pity and award rules remain source-model assumptions.
local studio = {
	observer = "/root",
	observation = "Lobby Studio Play client ConfigState; Effects featured UI displayed 637 WAS 750",
	date = "2026-09-09",
	placeId = 130584867985467,
	reportedPlayPlaceVersion = 0,
	observedAt = 1788946741,
	rawSnapshotPath = ".review/production/2026-09-09-batch1/config-live-lobby.json",
	probeAccessedStudio = false,
	scope = "price sensitivity only; published effective config and fulfillment not verified",
	observed = {
		EffectsCrateBonksPrice = 750,
		DodgeballCrateBonksPrice = 500,
		HammerCrateBonksPrice = 500,
		featuredDiscountPercent = 15,
		EffectsCrateDisplayedFeaturedPrice = 637,
		rotationSeconds = 86400,
		featuredSeconds = 604800,
		bundleSeconds = 604800,
		offerCount = 3,
		partyMax = 4,
		targetPlayers = 20,
		queueLimit = 100,
		pollSeconds = 2,
		voteSeconds = 10,
		variantId = "",
	},
	prices = {},
	targets = {},
}
if fs.isFile(studio.rawSnapshotPath) then
	studio.rawSnapshotSha256 = serde.hash("sha256", fs.readFile(studio.rawSnapshotPath))
end
local effects
for _, crate in result.crates do
	if crate.id == "EffectsCrate" then
		effects = crate
	end
end
assert(effects ~= nil, "Effects source model required for observed-price sensitivity")
local studioFeatured =
	Featured.discountedPrice(studio.observed.EffectsCrateBonksPrice, studio.observed.featuredDiscountPercent)
check(
	"root-observed Effects featured price matches source discount rounding",
	studioFeatured == studio.observed.EffectsCrateDisplayedFeaturedPrice
)
local sourceFirstRefund = effects.price - effects.horizons[1].fullOwnershipBaseNetPerOpen
for _, price in
	{
		{ label = "Source base", amount = effects.price },
		{ label = "Source featured", amount = effects.featuredPrice },
		{ label = "Observed Studio base", amount = studio.observed.EffectsCrateBonksPrice },
		{ label = "Observed Studio featured", amount = studioFeatured },
	}
do
	table.insert(studio.prices, {
		label = price.label,
		amount = price.amount,
		fullOwnershipColdFirstNet = price.amount - sourceFirstRefund,
		fullOwnershipStationaryNet = price.amount - effects.stationary.refund,
	})
end
for _, target in effects.targets do
	local row = { rarity = target.rarity, expectedOpens = target.expectedOpens, prices = {} }
	for _, price in studio.prices do
		local delta = target.expectedOpens * (price.amount - effects.price)
		table.insert(row.prices, {
			label = price.label,
			netNewInventory = target.baseNetNew + delta,
			netAllButTargetOwned = target.baseNetAllButTargetOwned + delta,
			deltaFromSourceBase = delta,
		})
	end
	table.insert(studio.targets, row)
end
result.observedStudioEffectsSensitivity = studio

local files = {
	"src/config/Progression/Data.luau",
	"src/config/Progression/Seasons.luau",
	"src/config/Progression/Quests.luau",
	"src/config/DailyRewards.luau",
	"src/config/Economy/Crates.luau",
	"src/config/Economy/GamePasses.luau",
	"src/config/Economy/Products.luau",
	"src/config/Economy/Shop.luau",
	"src/config/Cosmetics/Cosmetics.luau",
	"src/config/Cosmetics/DodgeballItems.luau",
	"src/config/Cosmetics/HammerItems.luau",
	"src/config/Cosmetics/CostumeItems.luau",
	"src/shared/Game/Economy/CrateOdds.luau",
	"src/shared/Game/Economy/CrateRolls.luau",
	"src/shared/Game/Economy/CosmeticsLogic.luau",
	"src/shared/Game/Economy/Boosts.luau",
	"src/shared/Game/Economy/FeaturedRotation.luau",
	"src/shared/Game/Economy/ShopRotation.luau",
	"src/shared/Game/Progression/BattlePassLogic.luau",
	"src/shared/Game/DailyReward/DailyRewardLogic.luau",
	"src/shared/Game/Economy/Participation.luau",
	"places/arena/server/Modules/ProgressionService.luau",
	"src/scripts/lune/probe-economy-release.luau",
	"src/scripts/lune/loader.luau",
}
for _, path in files do
	result.sourceHashes[path] = serde.hash("sha256", fs.readFile(path))
end
local git = process.exec("git", { "rev-parse", "HEAD" })
result.revision = string.gsub(git.stdout, "%s+$", "")
result.profileMode, result.players, result.platformServices = "synthetic mathematical cohorts", 0, "none"
fs.writeFile(out .. "/economy.json", serde.encode("json", result, true))

local lines = {
	"# Generated R11 economy tables",
	"",
	"All pacing rows are assumptions. See economy.json for inputs, methods and source hashes.",
	"Source prices below are a baseline. Root observed Effects 750 / featured 637 in lobby Studio Play; the separate sensitivity follows the source tables.",
	"",
	"## Match-only pacing",
	"",
	"| Cohort | Both boosters | Cycle min | Bonks/h | XP/h | Rare affordability min* | Legendary affordability min* | Tier 25 h |",
	"| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |",
}
for _, row in result.pacing do
	table.insert(
		lines,
		string.format(
			"| %s | %s | %.2f | %.1f | %.1f | %.1f | %.1f | %.2f |",
			row.cohort,
			tostring(row.boosted),
			row.cycleMinutes,
			row.bonksPerHour,
			row.xpPerHour,
			row.rareMinutesFromStartingBalance,
			row.legendaryMinutesFromStartingBalance,
			row.tier25Hours
		)
	)
end
table.insert(lines, "\n*From the untouched 1,000 starting balance, no other spending/grants; offer wait excluded.\n")
for _, crate in result.crates do
	table.insert(lines, "## " .. crate.id .. "\n")
	table.insert(
		lines,
		string.format(
			"Pool Common/Rare/Legendary: %d/%d/%d. Base price %d; featured %s.\n",
			crate.rarityCounts.Common,
			crate.rarityCounts.Rare,
			crate.rarityCounts.Legendary,
			crate.price,
			tostring(crate.featuredPrice or "not in rotation")
		)
	)
	table.insert(
		lines,
		"| Target rarity | E opens | Median | p90 | p95 | Net Bonks, empty inventory | Net Bonks, all but target owned | E opens Rare due | E opens Legendary due |"
	)
	table.insert(lines, "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for _, row in crate.targets do
		table.insert(
			lines,
			string.format(
				"| %s | %.4f | %d | %d | %d | %.2f | %.2f | %.4f | %.4f |",
				row.rarity,
				row.expectedOpens,
				row.median,
				row.p90,
				row.p95,
				row.baseNetNew,
				row.baseNetAllButTargetOwned,
				row.expectedOpensRareDue,
				row.expectedOpensLegendaryDue
			)
		)
	end
	table.insert(lines, "\n| Opens | Expected distinct | Empty-start mean net/open | Fully owned mean net/open |")
	table.insert(lines, "| --- | ---: | ---: | ---: |")
	for _, row in crate.horizons do
		table.insert(
			lines,
			string.format(
				"| %d | %.3f | %.3f | %.3f |",
				row.opens,
				row.expectedDistinct,
				row.newOwnershipBaseNetPerOpen,
				row.fullOwnershipBaseNetPerOpen
			)
		)
	end
	table.insert(
		lines,
		string.format(
			"\nSteady rarity Common/Rare/Legendary: %.5f%% / %.5f%% / %.5f%%; full-ownership refund %.5f, base sink %.5f.\n",
			crate.stationary.rarity.Common * 100,
			crate.stationary.rarity.Rare * 100,
			crate.stationary.rarity.Legendary * 100,
			crate.stationary.refund,
			crate.stationary.baseNetPerOpen
		)
	)
	local c = crate.collection
	table.insert(
		lines,
		string.format(
			"Collection Monte Carlo (%d runs, seed %d): mean %.2f opens (standard error %.2f); median %d, p90 %d; mean net %.2f Bonks.\n",
			c.runs,
			c.seed,
			c.meanOpens,
			c.meanStandardError,
			c.median,
			c.p90,
			c.meanBaseNetBonks
		)
	)
end
table.insert(lines, "## Root-observed Studio Effects price sensitivity\n")
table.insert(
	lines,
	"Root reported lobby Studio Play ConfigState Effects 750 and featured UI 637 WAS 750. This probe did not access Studio; pools, pity and refunds remain source assumptions.\n"
)
table.insert(
	lines,
	"| Empty-inventory target | E opens | Source base 500 | Source featured 425 | Observed base 750 | Observed featured 637 |"
)
table.insert(lines, "| --- | ---: | ---: | ---: | ---: | ---: |")
for _, target in studio.targets do
	table.insert(
		lines,
		string.format(
			"| %s | %.4f | %.2f | %.2f | %.2f | %.2f |",
			target.rarity,
			target.expectedOpens,
			target.prices[1].netNewInventory,
			target.prices[2].netNewInventory,
			target.prices[3].netNewInventory,
			target.prices[4].netNewInventory
		)
	)
end
table.insert(
	lines,
	"\n| Fully owned net sink/open | Source base 500 | Source featured 425 | Observed base 750 | Observed featured 637 |"
)
table.insert(lines, "| --- | ---: | ---: | ---: | ---: |")
table.insert(
	lines,
	string.format(
		"| Cold first roll | %.5f | %.5f | %.5f | %.5f |",
		studio.prices[1].fullOwnershipColdFirstNet,
		studio.prices[2].fullOwnershipColdFirstNet,
		studio.prices[3].fullOwnershipColdFirstNet,
		studio.prices[4].fullOwnershipColdFirstNet
	)
)
table.insert(
	lines,
	string.format(
		"| Stateful long-run | %.5f | %.5f | %.5f | %.5f |",
		studio.prices[1].fullOwnershipStationaryNet,
		studio.prices[2].fullOwnershipStationaryNet,
		studio.prices[3].fullOwnershipStationaryNet,
		studio.prices[4].fullOwnershipStationaryNet
	)
)
table.insert(
	lines,
	"\nNet target cost at price p = source net cost + (p - source base price) * E[opens]; no probability or acquisition-open changes are assumed. Review the intended effective settings with the owner; no runtime/published value was changed.\n"
)
table.insert(lines, "## Season sensitivity\n")
table.insert(lines, "| Join UTC | Days left | New min/day | Casual min/day | Skilled min/day | Completionist min/day |")
table.insert(lines, "| --- | ---: | ---: | ---: | ---: | ---: |")
for _, row in result.season.sensitivity do
	local values = {}
	for _, entry in row.cohorts do
		if not entry.boosted then
			table.insert(values, entry.minutesPerRemainingDay)
		end
	end
	table.insert(
		lines,
		string.format("| %s | %d | %.1f | %.1f | %.1f | %.1f |", row.joinUtc, row.remainingDays, unpack(values))
	)
end
table.insert(
	lines,
	"\nDouble XP halves these season minutes. Joining timestamps are 00:00 UTC; launch hour is unconfirmed.\n"
)
fs.writeFile(out .. "/tables.md", table.concat(lines, "\n") .. "\n")
print("Wrote " .. out .. "/economy.json and tables.md; " .. #validations .. " source/logic checks passed.")
