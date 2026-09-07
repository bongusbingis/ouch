-- Name: BattlePassService.luau
-- Author: Jack C.
-- Description: Server owner of season pass state: adopts the active season, accrues season XP, gates and grants premium ownership idempotently, validates claims, and settles what is owed at a season rollover.
-- Created: 2026-08-12

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
local SeasonCosmetics = require(ReplicatedStorage.Shared.Game.Progression.SeasonCosmetics)
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

local function grantCosmetics(player: Player, data: any, stored: any): boolean
	local season = activeSeasons.Definitions[stored.Id]
	if season == nil then
		return stored.Id == ""
	end
	local complete = true
	stored.CosmeticClaims = stored.CosmeticClaims or {}
	for _, reward in SeasonCosmetics.pending(season, stored, hasPremium(data, stored.Id)) do
		local granted = activeRewardService.grant(player, {
			kind = "Cosmetic",
			itemId = reward.itemId,
			duplicateRefund = false,
		})
		if granted then
			stored.CosmeticClaims[reward.key] = true
		else
			complete = false
		end
	end
	return complete
end

local function grantUnclaimedTiers(player: Player, data: any, stored: any): boolean
	local season = activeSeasons.Definitions[stored.Id]
	if season == nil then
		return stored.Id == ""
	end
	local complete = true
	for _, owed in
		BattlePassLogic.unclaimedTiers(season, BattlePassLogic.readState(stored), hasPremium(data, stored.Id))
	do
		local granted = activeRewardService.grant(player, owed.reward)
		if granted then
			local field = if owed.track == "Premium" then "ClaimedPremium" else "ClaimedFree"
			stored[field][tostring(owed.tier)] = true
		else
			complete = false
		end
	end
	return grantCosmetics(player, data, stored) and complete
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
			warn("[BattlePassService] season archive capacity reached; retaining all unpaid progress")
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
	for _, stored in data.SeasonHistory do
		grantUnclaimedTiers(player, data, stored)
	end
	grantCosmetics(player, data, data.Season)
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

function BattlePassService.addSeasonXp(player: Player, amount: number, seasonId: string?): boolean
	if amount <= 0 then
		return true
	end
	local data = BattlePassService.ensureData(player)
	if data == nil then
		return false
	end
	local id = seasonId or data.Season.Id
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
	if stored.Id ~= data.Season.Id then
		pcall(grantUnclaimedTiers, player, data, stored)
	end
	pcall(BattlePassService.fireState, player)
	return true
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
	local settled = stored == nil or grantUnclaimedTiers(player, data, stored)
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
	if not grantCosmetics(player, data, data.Season) then
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
