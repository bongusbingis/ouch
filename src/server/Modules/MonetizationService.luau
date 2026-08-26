-- Name: MonetizationService.luau
-- Author: Jack C.
-- Description: Owns receipt processing: records receipts in the profile for idempotency, dispatches to the registered handler per product type, and leaves unknown or failed receipts for Roblox to retry.
-- Created: 2026-07-13

--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Products"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates"))
local Bundles = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Bundles"))
local AnalyticsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Analytics"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CrateService = require(script.Parent.CrateService)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)
local RewardService = require(script.Parent.RewardService)

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

local handlers: { [string]: Handler } = {
	Crate = function(player, def, receiptInfo)
		return activeCrateService.openFromReceipt(player, def.CrateId, tostring(receiptInfo.PurchaseId)), nil
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
		for _, itemId in bundle.ItemIds do
			if not activeRewardService.grant(player, { kind = "Cosmetic", itemId = itemId }) then
				return false, nil
			end
		end
		return true,
			{
				grantId = tostring(receiptInfo.PurchaseId),
				kind = "Bundle",
				productId = receiptInfo.ProductId,
				bundleId = def.BundleId,
				itemIds = bundle.ItemIds,
			}
	end,
}

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
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

	local player = activePlayers:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = activePlayerData.get(player)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptKey = tostring(receiptInfo.PurchaseId)
	if data.Receipts[receiptKey] ~= nil then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, granted, payload = pcall(handler, player, def, receiptInfo)
	if not ok or not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.Receipts[receiptKey] = activeTime()
	activeAnalyticsService.logEconomyEvent(
		player,
		"Source",
		"Robux",
		(receiptInfo.CurrencySpent :: number?) or 0,
		0,
		AnalyticsConfig.EconomyTransactionTypes.IAP,
		tostring(receiptInfo.ProductId),
		{ productType = def.Type }
	)
	if payload then
		activeNetwork.fire("StorePurchaseGranted", player, payload)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.registerHandler(productType: string, handler: Handler)
	handlers[productType] = handler
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
			assert(
				activeCrates[definition.CrateId].CatalogStatus == "Active",
				`[Monetization] product {productId} sells a crate that is not Active`
			)
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
