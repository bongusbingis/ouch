-- Description: Server owner of season pass state: adopts the active season, accrues season XP, gates and grants premium ownership idempotently, validates claims, and settles what is owed at a season rollover.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Data"))
local Seasons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Seasons"))
local Products = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Products"))
local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local BattlePassLogic = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("BattlePassLogic")
)
local PlayerData = require(script.Parent.PlayerData)
local SeasonCosmetics = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("SeasonCosmetics")
)
local RewardService = require(script.Parent.RewardService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local BattlePassService = {}

type StartOptions = {
	players: any?,
	seasons: any?,
	products: any?,
	playerData: any?,
	rewardService: any?,
	network: any?,
	analyticsService: any?,
	monetizationService: any?,
	time: (() -> number)?,
	runAsync: ((callback: () -> ()) -> ())?,
	sweepSeconds: number?,
}

local SWEEP_SECONDS = 60

local started = false
local activePlayers: any = Players
local activeSeasons: any = Seasons
local activeProducts: any = Products
local activePlayerData: any = PlayerData
local activeRewardService: any = RewardService
local activeNetwork: any = Network
local activeAnalyticsService: any = AnalyticsService
local activeTime: () -> number = os.time
local activeRunAsync: (callback: () -> ()) -> () = task.spawn
local sweepSeconds = SWEEP_SECONDS
local sweeping = false
local connections: { any } = {}

local function activeSeasonAt(now: number): any
	return BattlePassLogic.activeSeason(activeSeasons.Definitions, now)
end

local function hasPremium(data: any, seasonId: string): boolean
	if seasonId == "" or data.Entitlements == nil then
		return false
	end
	return data.Entitlements.PremiumSeasons[seasonId] == true
end

local function premiumProductId(seasonId: string): number?
	for _, definition in activeProducts.Catalog do
		if
			definition.Type == "SeasonPass"
			and definition.SeasonId == seasonId
			and definition.Id ~= nil
			and (definition.CatalogStatus == nil or definition.CatalogStatus == "Active")
		then
			return definition.Id
		end
	end
	return nil
end

local function grantCosmetics(player: Player, data: any, stored: any, path: string, expectedId: string?): (boolean, string?)
	local valid, validationReason = BattlePassLogic.validateStoredState(stored, path, expectedId)
	if not valid then
		return false, validationReason
	end
	local season = activeSeasons.Definitions[stored.Id]
	if season == nil then
		return stored.Id == "", `unknown season {tostring(stored.Id)}`
	end
	local complete = true
	local failure: string? = nil
	if stored.CosmeticClaims == nil then
		warn(`[BattlePassService] {path}.CosmeticClaims for {player.Name}: historical field absent; initializing empty claim map`)
		stored.CosmeticClaims = {}
	end
	for _, reward in SeasonCosmetics.pending(season, stored, hasPremium(data, stored.Id)) do
		local ok, granted, reason = pcall(activeRewardService.grant, player, {
			kind = "Cosmetic",
			itemId = reward.itemId,
			duplicateRefund = false,
		})
		if ok and granted then
			stored.CosmeticClaims[reward.key] = true
		else
			complete = false
			failure = failure or `season {stored.Id} cosmetic {reward.key} item {reward.itemId}: {tostring(if ok then reason else granted)}`
		end
	end
	return complete, failure
end

local function grantUnclaimedTiers(player: Player, data: any, stored: any, archiveKey: string): (boolean, string?)
	local path = `SeasonHistory.{archiveKey}`
	if archiveKey == "" then
		return false, `SeasonHistory: empty archive key for {player.Name}; repair persisted profile`
	end
	local valid, validationReason = BattlePassLogic.validateStoredState(stored, path, archiveKey)
	if not valid then
		return false, validationReason
	end
	local season = activeSeasons.Definitions[stored.Id]
	if season == nil then
		return false, `{path}.Id: season definition {stored.Id} missing; restore its archived definition`
	end
	local complete = true
	local failure: string? = nil
	for _, owed in
		BattlePassLogic.unclaimedTiers(season, BattlePassLogic.readState(stored), hasPremium(data, stored.Id))
	do
		local ok, granted, reason = pcall(activeRewardService.grant, player, owed.reward)
		if ok and granted then
			local field = if owed.track == "Premium" then "ClaimedPremium" else "ClaimedFree"
			stored[field][tostring(owed.tier)] = true
			if owed.reward.kind == "Bonks" then
				pcall(
					activeAnalyticsService.logEconomyEvent,
					player,
					"Source",
					"Bonks",
					owed.reward.amount,
					data.Bonks,
					AnalyticsConfig.EconomyTransactionTypes.Gameplay,
					"SeasonReward",
					{ source = "SeasonRollover" }
				)
			end
		else
			complete = false
			failure = failure
				or `season {stored.Id} tier {owed.tier} {owed.track} {owed.reward.kind} {tostring(owed.reward.itemId or owed.reward.amount)}: {tostring(if ok then reason else granted)}`
		end
	end
	local cosmeticsComplete, cosmeticsReason = grantCosmetics(player, data, stored, path, archiveKey)
	return complete and cosmeticsComplete, failure or cosmeticsReason
end

local function archive(data: any, stored: any): boolean
	if stored.Id == "" then
		return true
	end
	if data.SeasonHistory[stored.Id] == nil then
		local count = 0
		for _ in data.SeasonHistory do
			count += 1
		end
		if count >= DataConfig.Persistence.MaxSeasonArchives then
			warn(
				`[BattlePassService] SeasonHistory.{stored.Id}: archive capacity {DataConfig.Persistence.MaxSeasonArchives} reached; remove only settled archived data through an approved migration`
			)
			return false
		end
		data.SeasonHistory[stored.Id] = BattlePassLogic.readState(stored)
	end
	return true
end

function BattlePassService.ensureData(player: Player): any
	local data = activePlayerData.get(player)
	if data == nil then
		return nil
	end
	if data.Season ~= nil then
		local valid, reason = BattlePassLogic.validateStoredState(data.Season, "Season")
		if not valid then
			error(`[BattlePassService] {reason} for {player.Name}; repair persisted profile`)
		end
	end
	if data.SeasonHistory ~= nil then
		if type(data.SeasonHistory) ~= "table" then
			error(`[BattlePassService] SeasonHistory for {player.Name}: expected table; repair persisted profile`)
		end
		for archiveKey, stored in data.SeasonHistory do
			if type(archiveKey) ~= "string" or archiveKey == "" then
				error(`[BattlePassService] SeasonHistory.{tostring(archiveKey)} for {player.Name}: expected nonempty string archive key; repair persisted profile`)
			end
			local valid, reason = BattlePassLogic.validateStoredState(stored, `SeasonHistory.{archiveKey}`, archiveKey)
			if not valid then
				error(`[BattlePassService] {reason} for {player.Name}; repair persisted profile`)
			end
		end
	end
	if data.Season == nil then
		data.Season = BattlePassLogic.blankState("")
	end
	if data.Entitlements == nil then
		data.Entitlements = { PremiumSeasons = {} }
	end

	if data.SeasonHistory == nil then
		data.SeasonHistory = {}
	end
	local season = activeSeasonAt(activeTime())
	local activeId = if season then season.Id else ""
	if data.Season.Id ~= activeId then
		if not archive(data, data.Season) then
			return nil
		end
		data.Season = BattlePassLogic.blankState(activeId)
	end
	for archiveKey, stored in data.SeasonHistory do
		local settled, reason = grantUnclaimedTiers(player, data, stored, archiveKey)
		if not settled then
			warn(`[BattlePassService] archived settlement pending for {player.Name}: {reason}`)
		end
	end
	local cosmeticsSettled, cosmeticsReason = grantCosmetics(player, data, data.Season, "Season")
	if not cosmeticsSettled then
		warn(`[BattlePassService] active cosmetic settlement pending for {player.Name}: {cosmeticsReason}`)
	end
	return data
end

function BattlePassService.stateFor(player: Player): any
	local data = BattlePassService.ensureData(player)
	if data == nil then
		return nil
	end
	local season = activeSeasonAt(activeTime())
	local stored = BattlePassLogic.readState(data.Season)
	local seasonId = if season then season.Id else ""
	return BattlePassLogic.publicState(season, stored, hasPremium(data, seasonId), premiumProductId(seasonId))
end

function BattlePassService.fireState(player: Player)
	local state = BattlePassService.stateFor(player)
	if state ~= nil then
		activeNetwork.fire("SeasonPassStateChanged", player, state)
	end
end

function BattlePassService.settleArchivedSeason(player: Player, seasonId: string, awardId: string): (boolean, string?)
	if seasonId == "" then
		return true, nil
	end
	local data = BattlePassService.ensureData(player)
	if data == nil then
		return false, `award {awardId} season {seasonId}: profile or archive unavailable`
	end
	if data.Season.Id == seasonId then
		return true, nil
	end
	local stored = data.SeasonHistory[seasonId]
	if stored == nil then
		local missing = `award {tostring(awardId)} season {tostring(seasonId)}: SeasonHistory.{tostring(seasonId)} missing`
		if type(awardId) ~= "string" or awardId == "" then
			return false, `{missing}; nonempty award ID required`
		end
		if type(seasonId) ~= "string" or seasonId == "" or activeSeasons.Definitions[seasonId] == nil then
			return false, `{missing}; known nonempty season ID required`
		end
		local journal = data.MatchAwards
		if type(journal) ~= "table" or journal.Version ~= 1 or type(journal.Pending) ~= "table" then
			return false, `{missing}; MatchAwards V1 Pending journal required`
		end
		local record = journal.Pending[awardId]
		if type(record) ~= "table" then
			return false, `{missing}; MatchAwards.Pending.{awardId} record required`
		end
		if record.Ready ~= true or record.ProgressionApplied ~= true or record.SeasonApplied ~= true then
			return false, `{missing}; MatchAwards.Pending.{awardId} must be ready, progression-applied, and season-applied`
		end
		if record.SeasonId ~= seasonId then
			return false, `{missing}; MatchAwards.Pending.{awardId}.SeasonId must equal {seasonId}`
		end
		if type(record.Awarded) ~= "table" or type(record.Awarded.XP) ~= "number" or record.Awarded.XP ~= 0 then
			return false, `{missing}; MatchAwards.Pending.{awardId}.Awarded.XP must be numeric zero`
		end
		return true, nil
	end
	local valid, validationReason = BattlePassLogic.validateStoredState(stored, `SeasonHistory.{seasonId}`, seasonId)
	if not valid then
		return false, `award {awardId} season {seasonId}: {validationReason}`
	end
	local settled, reason = grantUnclaimedTiers(player, data, stored, seasonId)
	if not settled then
		return false, `award {awardId}: {reason}`
	end
	return true, nil
end

-- The return value reports durable XP credit. Callers that require archived
-- reward settlement must also call settleArchivedSeason; retrying this method
-- after a partial settlement would credit XP again.
function BattlePassService.addSeasonXp(player: Player, amount: number, seasonId: string?): (boolean, string?)
	if amount <= 0 then
		return true
	end
	local data = BattlePassService.ensureData(player)
	if data == nil then
		return false
	end
	local id = seasonId or data.Season.Id
	-- No active season means season XP is dropped, deliberately: banking it would
	-- let players pre-farm the next season's track before it opens, and there is
	-- nowhere to store it that a rollover would not archive away. Career XP
	-- (Level.Points) and Bonks are unaffected -- only the tier track pauses. The
	-- splash card says so in its between-seasons state; keep the two in step, and
	-- do not add copy promising carry-over without changing this.
	if id == "" then
		return true
	end
	local stored = data.Season
	if stored.Id ~= id then
		if activeSeasons.Definitions[id] == nil then
			return false
		end
		if not archive(data, BattlePassLogic.blankState(id)) then
			return false
		end
		stored = data.SeasonHistory[id]
	end
	stored.XP += amount
	local pendingReason: string? = nil
	if stored.Id ~= data.Season.Id then
		local settled, reason = grantUnclaimedTiers(player, data, stored, id)
		if not settled then
			warn(`[BattlePassService] archived XP credited; settlement pending for {player.Name}: {reason}`)
			pendingReason = reason
		end
	end
	local notified, err = pcall(BattlePassService.fireState, player)
	if not notified then
		warn(`[BattlePassService] season XP credited; state notification failed for {player.Name}: {err}`)
		pendingReason = pendingReason or `state notification failed: {err}`
	end
	return true, pendingReason
end

function BattlePassService.grantPremium(player: Player, seasonId: string?): boolean
	if seasonId == nil or seasonId == "" then
		return false
	end
	if activeSeasons.Definitions[seasonId] == nil then
		warn(`[BattlePassService] refusing premium for unknown season "{seasonId}"`)
		return false
	end
	local data = BattlePassService.ensureData(player)
	if data == nil then
		return false
	end
	data.Entitlements.PremiumSeasons[seasonId] = true
	local stored = data.SeasonHistory[seasonId]
	local settled = stored == nil or grantUnclaimedTiers(player, data, stored, seasonId)
	BattlePassService.fireState(player)
	return settled
end

local function claimOne(player: Player, data: any, season: any, tier: number, track: string): (boolean, string?)
	local stored = BattlePassLogic.readState(data.Season)
	local owned = hasPremium(data, season.Id)
	local ok, reason = BattlePassLogic.canClaim(season, stored, tier, track :: any, owned)
	if not ok then
		return false, reason
	end

	local reward = BattlePassLogic.rewardAt(season, tier, track :: any)
	local granted, grantReason = activeRewardService.grant(player, reward)
	if not granted then
		return false, grantReason or "grant_failed"
	end

	local field = if track == "Premium" then "ClaimedPremium" else "ClaimedFree"
	data.Season[field][tostring(tier)] = true
	if reward.kind == "Bonks" then
		pcall(
			activeAnalyticsService.logEconomyEvent,
			player,
			"Source",
			"Bonks",
			reward.amount,
			data.Bonks,
			AnalyticsConfig.EconomyTransactionTypes.Gameplay,
			"SeasonReward",
			{ source = "SeasonClaim" }
		)
	end
	if not grantCosmetics(player, data, data.Season, "Season") then
		return false, "grant_failed"
	end
	pcall(activeAnalyticsService.logCustomEvent, player, AnalyticsConfig.CustomEvents.SeasonTierClaimed, 1, {
		seasonId = season.Id,
		tier = tier,
		track = track,
	})
	return true, nil
end

function BattlePassService.claim(player: Player, tier: number, track: string): (any?, string?)
	local data = BattlePassService.ensureData(player)
	if data == nil then
		return nil, "profile_not_ready"
	end
	local season = activeSeasonAt(activeTime())
	if season == nil then
		return nil, "no_active_season"
	end
	local ok, reason = claimOne(player, data, season, tier, track)
	if not ok then
		return nil, reason
	end
	local state = BattlePassService.stateFor(player)
	activeNetwork.fire("SeasonPassStateChanged", player, state)
	return state, nil
end

function BattlePassService.claimAll(player: Player): (any?, string?, number)
	local data = BattlePassService.ensureData(player)
	if data == nil then
		return nil, "profile_not_ready", 0
	end
	local season = activeSeasonAt(activeTime())
	if season == nil then
		return nil, "no_active_season", 0
	end

	local stored = BattlePassLogic.readState(data.Season)
	local owed = BattlePassLogic.unclaimedTiers(season, stored, hasPremium(data, season.Id))
	local claimed = 0
	local failure: string? = nil
	for _, entry in owed do
		local ok, reason = claimOne(player, data, season, entry.tier, entry.track)
		if ok then
			claimed += 1
		else
			failure = reason or "grant_failed"
		end
	end
	local state = BattlePassService.stateFor(player)
	activeNetwork.fire("SeasonPassStateChanged", player, state)
	if #SeasonCosmetics.pending(season, data.Season, hasPremium(data, season.Id)) > 0 then
		failure = failure or "grant_failed"
	end
	return if failure then nil else state, failure, claimed
end

local function sweep()
	for _, player in activePlayers:GetPlayers() do
		local before = activePlayerData.get(player)
		local storedId = if before and before.Season then before.Season.Id else nil
		local data = BattlePassService.ensureData(player)
		if data ~= nil and storedId ~= nil and data.Season.Id ~= storedId then
			BattlePassService.fireState(player)
		end
	end
end

function BattlePassService.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activePlayers = if options and options.players then options.players else Players
	activeSeasons = if options and options.seasons then options.seasons else Seasons
	activeProducts = if options and options.products then options.products else Products
	activePlayerData = if options and options.playerData then options.playerData else PlayerData
	activeRewardService = if options and options.rewardService then options.rewardService else RewardService
	activeNetwork = if options and options.network then options.network else Network
	activeAnalyticsService = if options and options.analyticsService then options.analyticsService else AnalyticsService
	activeTime = if options and options.time then options.time else os.time
	activeRunAsync = if options and options.runAsync then options.runAsync else task.spawn
	sweepSeconds = if options and options.sweepSeconds then options.sweepSeconds else SWEEP_SECONDS

	local monetization = options and options.monetizationService
	if monetization ~= nil then
		monetization.registerHandler("SeasonPass", function(player, definition, receiptInfo)
			if not BattlePassService.grantPremium(player, definition.SeasonId) then
				return false, nil
			end
			return true,
				{
					grantId = tostring(receiptInfo.PurchaseId),
					kind = "SeasonPass",
					productId = receiptInfo.ProductId,
					seasonId = definition.SeasonId,
				}
		end)
	end

	activeNetwork.handleProtected("GetSeasonPassState", { rateLimit = 4 }, function(player)
		return BattlePassService.stateFor(player)
	end)
	activeNetwork.handleProtected("ClaimSeasonTier", {
		rateLimit = 6,
		validate = function(_player, tier, track)
			if typeof(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 then
				return false, "tier must be a positive integer"
			end
			if track ~= "Free" and track ~= "Premium" then
				return false, "track must be Free or Premium"
			end
			return true
		end,
	}, function(player, tier, track)
		return BattlePassService.claim(player, tier, track)
	end)
	activeNetwork.handleProtected("ClaimAllSeasonTiers", { rateLimit = 2 }, function(player)
		return BattlePassService.claimAll(player)
	end)

	table.insert(
		connections,
		activePlayers.PlayerAdded:Connect(function(player)
			activeRunAsync(function()
				BattlePassService.fireState(player)
			end)
		end)
	)

	if sweepSeconds > 0 then
		sweeping = true
		activeRunAsync(function()
			while sweeping do
				task.wait(sweepSeconds)
				if sweeping then
					sweep()
				end
			end
		end)
	end
end

function BattlePassService._resetForTest()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	started = false
	sweeping = false
	activePlayers = Players
	activeSeasons = Seasons
	activeProducts = Products
	activePlayerData = PlayerData
	activeRewardService = RewardService
	activeNetwork = Network
	activeAnalyticsService = AnalyticsService
	activeTime = os.time
	activeRunAsync = task.spawn
	sweepSeconds = SWEEP_SECONDS
end

return BattlePassService
