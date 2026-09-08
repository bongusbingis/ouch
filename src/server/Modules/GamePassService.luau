-- Description: Reconciles game pass ownership on join and after purchase, granting the cosmetics a pass entitles idempotently and recording ownership for the entitlement cache.

--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local GamePasses = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("GamePasses"))
local DataConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Data"))
local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CosmeticsService = require(script.Parent.CosmeticsService)
local EntitlementService = require(script.Parent.EntitlementService)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CosmeticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic")
)

type StartOptions = {
	marketplace: any?,
	players: any?,
	playerData: any?,
	cosmeticsService: any?,
	entitlementService: any?,
	gamePasses: any?,
	cosmetics: any?,
	network: any?,
	analyticsService: any?,
	runAsync: ((callback: () -> ()) -> ())?,
	wait: ((seconds: number) -> ())?,
}

local GamePassService = {}

local RETRY_SECONDS = 0.25

local started = false
local generation = 0
local activeMarketplace: any = MarketplaceService
local activePlayers: any = Players
local activePlayerData: any = PlayerData
local activeCosmeticsService: any = CosmeticsService
local activeEntitlementService: any = EntitlementService
local activeGamePasses: any = GamePasses
local activeCosmetics: any = Cosmetics
local activeNetwork: any = Network
local activeAnalytics: any = AnalyticsService
local activeRunAsync: (callback: () -> ()) -> () = task.spawn
local activeWait: (seconds: number) -> () = task.wait
local connections: { any } = {}
local purchaseNotifications = setmetatable({}, { __mode = "k" }) :: { [Player]: { [number]: boolean } }

local function isActive(definition: any): boolean
	if definition.CatalogStatus ~= nil then
		return definition.CatalogStatus == "Active"
	end
	return definition.Enabled == true
end

local function sortedPassIds(): { number }
	local ids = {}
	for passId in activeGamePasses.ById do
		table.insert(ids, passId)
	end
	table.sort(ids)
	return ids
end

local function validateCatalog()
	for key, definition in activeGamePasses.Catalog do
		if isActive(definition) or definition.Id ~= nil then
			local allowedCategories = {}
			for _, category in definition.Categories do
				allowedCategories[category] = true
			end
			for _, itemId in definition.EntitlementItemIds do
				local item = activeCosmetics.Items[itemId]
				assert(item ~= nil, `[GamePassService] game pass "{key}" references unknown cosmetic "{itemId}"`)
				assert(
					allowedCategories[item.Category] == true,
					`[GamePassService] cosmetic "{itemId}" is outside game pass "{key}" categories`
				)
			end
		end
	end
end

local function waitForProfile(player: Player): boolean
	local currentGeneration = generation
	while currentGeneration == generation and player.Parent ~= nil do
		if activePlayerData.get(player) ~= nil then
			return true
		end
		activeWait(RETRY_SECONDS)
	end
	return false
end

local function ownsPass(player: Player, passId: number): boolean?
	local ok, owned = pcall(function()
		return activeMarketplace:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if not ok then
		warn(`[GamePassService] ownership lookup failed for {player.Name}, pass {passId}: {owned}`)
		return nil
	end
	return owned == true
end

local function grantConfiguredPass(player: Player, passId: number): (boolean, number)
	local definition = activeGamePasses.ById[passId]
	if definition == nil or activePlayerData.get(player) == nil then
		return false, 0
	end
	local granted = 0
	for _, itemId in definition.EntitlementItemIds do
		local ok, accepted, reason = pcall(activeCosmeticsService.grant, player, itemId)
		if not ok or (not accepted and reason ~= "already_owned") then
			return false, granted
		end
		if accepted then
			granted += 1
			pcall(activeAnalytics.logCustomEvent, player, AnalyticsConfig.CustomEvents.CosmeticGranted, 1, {
				itemId = itemId,
				passId = passId,
				source = "GamePass",
			})
		end
	end
	return true, granted
end

local function recordOwnership(passId: number, player: Player, owned: boolean)
	local key = activeGamePasses.KeyById and activeGamePasses.KeyById[passId]
	if key ~= nil then
		activeEntitlementService.setOwnership(player, key, owned)
	end
end

local function reconcilePass(player: Player, passId: number): (boolean?, number)
	local currentGeneration = generation
	local owned = ownsPass(player, passId)
	if currentGeneration ~= generation or player.Parent == nil then
		return nil, 0
	end
	if owned ~= nil then
		recordOwnership(passId, player, owned)
	end
	if owned ~= true then
		return owned, 0
	end
	local granted, count = grantConfiguredPass(player, passId)
	return if granted then true else nil, count
end

local function reconcilePlayer(player: Player, currentGeneration: number)
	if not waitForProfile(player) then
		return
	end
	local remaining = sortedPassIds()
	while currentGeneration == generation and player.Parent ~= nil and #remaining > 0 do
		local failed = {}
		for _, passId in remaining do
			if currentGeneration ~= generation or player.Parent == nil then
				return
			end
			if reconcilePass(player, passId) == nil then
				table.insert(failed, passId)
			end
		end
		remaining = failed
		if #remaining > 0 then
			activeWait(DataConfig.Persistence.EntitlementRetrySeconds)
		end
	end
end

local function notifyPurchase(player: Player, passId: number, itemCount: number)
	local notified = purchaseNotifications[player]
	if notified == nil then
		notified = {}
		purchaseNotifications[player] = notified
	end
	if notified[passId] then
		return
	end
	notified[passId] = true
	activeNetwork.fire("StorePurchaseGranted", player, {
		grantId = `pass:{passId}`,
		kind = "GamePass",
		passId = passId,
		itemCount = itemCount,
	})
end

local function onPurchaseFinished(player: Player, passId: number, wasPurchased: boolean)
	if not wasPurchased or activeGamePasses.ById[passId] == nil then
		return
	end
	local currentGeneration = generation
	activeRunAsync(function()
		if not waitForProfile(player) or currentGeneration ~= generation then
			return
		end
		while currentGeneration == generation and player.Parent ~= nil do
			local reconciled, itemCount = reconcilePass(player, passId)
			if reconciled == true then
				pcall(notifyPurchase, player, passId, itemCount)
				return
			end
			activeWait(DataConfig.Persistence.EntitlementRetrySeconds)
		end
	end)
end

local function schedulePlayer(player: Player)
	local currentGeneration = generation
	activeRunAsync(function()
		reconcilePlayer(player, currentGeneration)
	end)
end

function GamePassService.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activeMarketplace = if options and options.marketplace then options.marketplace else MarketplaceService
	activePlayers = if options and options.players then options.players else Players
	activePlayerData = if options and options.playerData then options.playerData else PlayerData
	activeCosmeticsService = if options and options.cosmeticsService then options.cosmeticsService else CosmeticsService
	activeEntitlementService = if options and options.entitlementService
		then options.entitlementService
		else EntitlementService
	activeGamePasses = if options and options.gamePasses then options.gamePasses else GamePasses
	activeCosmetics = if options and options.cosmetics then options.cosmetics else Cosmetics
	activeNetwork = if options and options.network then options.network else Network
	activeAnalytics = if options and options.analyticsService then options.analyticsService else AnalyticsService
	activeRunAsync = if options and options.runAsync then options.runAsync else task.spawn
	activeWait = if options and options.wait then options.wait else task.wait

	validateCatalog()
	table.insert(connections, activePlayers.PlayerAdded:Connect(schedulePlayer))
	table.insert(connections, activeMarketplace.PromptGamePassPurchaseFinished:Connect(onPurchaseFinished))
	for _, player in activePlayers:GetPlayers() do
		schedulePlayer(player)
	end
end

function GamePassService._resetForTest()
	generation += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	started = false
	activeMarketplace = MarketplaceService
	activePlayers = Players
	activePlayerData = PlayerData
	activeCosmeticsService = CosmeticsService
	activeEntitlementService = EntitlementService
	activeGamePasses = GamePasses
	activeCosmetics = Cosmetics
	activeNetwork = Network
	activeAnalytics = AnalyticsService
	activeRunAsync = task.spawn
	activeWait = task.wait
	table.clear(purchaseNotifications)
end

function GamePassService.purchaseState(player: Player): { [string]: boolean }
	local result = {}
	local data = activePlayerData.get(player)
	if data == nil then
		return result
	end
	for key, definition in activeGamePasses.Catalog do
		if not activeEntitlementService.has(player, key) then
			continue
		end
		local complete = true
		for _, itemId in definition.EntitlementItemIds do
			complete = complete and CosmeticsLogic.isOwned(activeCosmetics.Items, data.Cosmetics.Owned, itemId)
		end
		if complete then
			result[key] = true
		end
	end
	return result
end

return GamePassService
