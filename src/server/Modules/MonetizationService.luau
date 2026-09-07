-- Name: MonetizationService.luau
-- Author: Jack C.
-- Description: Owns receipt processing: records receipts in the profile for idempotency, dispatches to the registered handler per product type, and leaves unknown or failed receipts for Roblox to retry.
-- Created: 2026-07-13

--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataConfig = require(ReplicatedStorage.Config.Progression.Data)
local WriteThroughProxy = require(ReplicatedStorage.Shared.Game.Data.WriteThroughProxy)
local Products = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Products"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Crates"))
local Bundles = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Bundles"))
local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CrateService = require(script.Parent.CrateService)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)
local RewardService = require(script.Parent.RewardService)
local ReceiptHistory = require(ReplicatedStorage.Shared.Game.Economy.ReceiptHistory)

type StartOptions = {
	marketplace: any?,
	players: any?,
	products: any?,
	crates: any?,
	bundles: any?,
	crateService: any?,
	rewardService: any?,
	playerData: any?,
	analyticsService: any?,
	network: any?,
	time: (() -> number)?,
}

type GrantPayload = { [string]: any }
type Handler = (player: Player, def: any, receiptInfo: { [string]: any }) -> (boolean, GrantPayload?)

local MonetizationService = {}

local started = false
local activeMarketplace: any = MarketplaceService
local activePlayers: any = Players
local activeProducts: any = Products
local activeCrates: any = Crates
local activeBundles: any = Bundles
local activeCrateService: any = CrateService
local activeRewardService: any = RewardService
local activePlayerData: any = PlayerData
local activeAnalyticsService: any = AnalyticsService
local activeNetwork: any = Network
local activeTime: () -> number = os.time
local processing: { [number]: boolean } = {}

local handlers: { [string]: Handler } = {
	Crate = function(player, def, receiptInfo)
		return activeCrateService.openFromReceipt(player, def.CrateId, tostring(receiptInfo.PurchaseId))
	end,
	Bonks = function(player, def, receiptInfo)
		if type(def.BonksAmount) ~= "number" or def.BonksAmount <= 0 or def.BonksAmount % 1 ~= 0 then
			return false, nil
		end
		activePlayerData.addBonks(player, def.BonksAmount)
		return true,
			{
				grantId = tostring(receiptInfo.PurchaseId),
				kind = "Bonks",
				productId = receiptInfo.ProductId,
				amount = def.BonksAmount,
			}
	end,
	Cosmetic = function(player, def, receiptInfo)
		if type(def.ItemId) ~= "string" then
			return false, nil
		end
		if not activeRewardService.grant(player, { kind = "Cosmetic", itemId = def.ItemId }) then
			return false, nil
		end
		return true,
			{
				grantId = tostring(receiptInfo.PurchaseId),
				kind = "Cosmetic",
				productId = receiptInfo.ProductId,
				itemId = def.ItemId,
			}
	end,
	Bundle = function(player, def, receiptInfo)
		local bundle = activeBundles.Catalog[def.BundleId]
		if bundle == nil or #bundle.ItemIds == 0 then
			return false, nil
		end
		local data = activePlayerData.get(player)
		local work = data.ReceiptWork[tostring(receiptInfo.PurchaseId)]
		if work.ItemIds == nil then
			work.ItemIds = table.clone(bundle.ItemIds)
		end
		for _, itemId in work.ItemIds do
			if work.Items[itemId] then
				continue
			end
			if not activeRewardService.grant(player, { kind = "Cosmetic", itemId = itemId }) then
				return false, nil
			end
			work.Items[itemId] = true
		end
		return true,
			{
				grantId = tostring(receiptInfo.PurchaseId),
				kind = "Bundle",
				productId = receiptInfo.ProductId,
				bundleId = def.BundleId,
				itemIds = work.ItemIds,
			}
	end,
}

local function grantReceipt(receiptInfo: { [string]: any }, player: Player): Enum.ProductPurchaseDecision
	local def = activeProducts.ById[receiptInfo.ProductId]
	if def == nil then
		warn(`[Monetization] receipt for unmapped product {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local handler = handlers[def.Type]
	if handler == nil then
		warn(`[Monetization] no handler for product type "{def.Type}"`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = activePlayerData.get(player)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptKey = tostring(receiptInfo.PurchaseId)
	if data.ReceiptWork == nil then
		data.ReceiptWork = {}
	end
	if data.Receipts[receiptKey] == nil then
		if data.ReceiptWork[receiptKey] == nil then
			local count = 0
			for _ in data.ReceiptWork do
				count += 1
			end
			if count >= DataConfig.Persistence.MaxPendingReceipts then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			data.ReceiptWork[receiptKey] = { Items = {} }
		end
		local ok, granted, payload = pcall(handler, player, def, receiptInfo)
		if not ok or not granted or activePlayerData.get(player) ~= data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.ReceiptWork[receiptKey].Payload = payload
		data.Receipts[receiptKey] = {
			at = activeTime(),
			productId = receiptInfo.ProductId,
			payload = payload,
		}
		ReceiptHistory.prune(data.Receipts, DataConfig.Persistence.ReceiptDetailHistory, receiptKey)
	end
	if not activePlayerData.confirmReceiptSaved(player, receiptKey) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local work = data.ReceiptWork[receiptKey]
	if work then
		if def.Type == "Bonks" then
			pcall(
				activeAnalyticsService.logEconomyEvent,
				player,
				"Source",
				"Bonks",
				def.BonksAmount,
				data.Bonks,
				AnalyticsConfig.EconomyTransactionTypes.IAP,
				tostring(receiptInfo.ProductId),
				{ productType = def.Type }
			)
		end
		local payload = if work.Payload then WriteThroughProxy.snapshot(work.Payload) else nil
		if payload then
			if payload.kind == "Crate" then
				pcall(activeNetwork.fire, "CrateOpened", player, payload.reveal)
			else
				payload.productId = receiptInfo.ProductId
				payload.grantId = receiptKey
				pcall(activeNetwork.fire, "StorePurchaseGranted", player, payload)
			end
		end
		data.ReceiptWork[receiptKey] = nil
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = activePlayers:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil or processing[player.UserId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local release = activePlayerData.acquireWriteLease(player)
	if release == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	processing[player.UserId] = true
	local ok, result = pcall(grantReceipt, receiptInfo, player)
	processing[player.UserId] = nil
	release()
	if not ok then
		warn(`[Monetization] receipt {receiptInfo.PurchaseId} failed: {result}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return result
end

function MonetizationService.registerHandler(productType: string, handler: Handler)
	handlers[productType] = handler
end

function MonetizationService.purchaseState(player: Player): { any }
	return ReceiptHistory.recent(activePlayerData.savedReceipts(player), DataConfig.Persistence.ReceiptDetailHistory)
end

function MonetizationService.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activeMarketplace = if options and options.marketplace then options.marketplace else MarketplaceService
	activePlayers = if options and options.players then options.players else Players
	activeProducts = if options and options.products then options.products else Products
	activeCrates = if options and options.crates then options.crates else Crates
	activeBundles = if options and options.bundles then options.bundles else Bundles
	activeCrateService = if options and options.crateService then options.crateService else CrateService
	activeRewardService = if options and options.rewardService then options.rewardService else RewardService
	activePlayerData = if options and options.playerData then options.playerData else PlayerData
	activeAnalyticsService = if options and options.analyticsService then options.analyticsService else AnalyticsService
	activeNetwork = if options and options.network then options.network else Network
	activeTime = if options and options.time then options.time else os.time

	for productId, definition in activeProducts.ById do
		assert(
			handlers[definition.Type] ~= nil,
			`[Monetization] product {productId} has unsupported type "{definition.Type}"`
		)
		if definition.Type == "Crate" then
			assert(
				activeCrates[definition.CrateId] ~= nil,
				`[Monetization] product {productId} references an unknown crate`
			)
			if definition.CatalogStatus == "Active" then
				assert(
					activeCrates[definition.CrateId].CatalogStatus == "Active",
					`[Monetization] product {productId} sells a crate that is not Active`
				)
			end
		elseif definition.Type == "Bundle" then
			assert(
				activeBundles.Catalog[definition.BundleId] ~= nil,
				`[Monetization] product {productId} references an unknown bundle`
			)
		end
	end
	activeMarketplace.ProcessReceipt = processReceipt
end

function MonetizationService._resetForTest()
	table.clear(processing)
	started = false
	activeMarketplace = MarketplaceService
	activePlayers = Players
	activeProducts = Products
	activeCrates = Crates
	activeBundles = Bundles
	activeCrateService = CrateService
	activeRewardService = RewardService
	activePlayerData = PlayerData
	activeAnalyticsService = AnalyticsService
	activeNetwork = Network
	activeTime = os.time
end

return MonetizationService
