--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Products"))
local AnalyticsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Analytics"))
local CrateService = require(script.Parent.CrateService)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)

-- Owns ProcessReceipt. Receipts are recorded in the profile for idempotency
-- (retries after grant return PurchaseGranted without re-granting); unknown
-- products and failures return NotProcessedYet so Roblox retries/refunds.
-- New product types (battle pass) register a handler here.
--
-- Receipts are kept for the life of the profile, never pruned: Roblox may
-- retry ProcessReceipt for an already-granted purchase at any point in the
-- future, and evicting a receipt would make that retry re-grant for free.

local MonetizationService = {}

local handlers: { [string]: (player: Player, def: any) -> boolean } = {
	Crate = function(player, def)
		return CrateService.openFromReceipt(player, def.CrateId)
	end,
	Cash = function(player, def)
		if type(def.CashAmount) ~= "number" or def.CashAmount <= 0 or def.CashAmount % 1 ~= 0 then
			return false
		end
		PlayerData.addCash(player, def.CashAmount)
		return true
	end,
}

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local def = Products.ById[receiptInfo.ProductId]
	if def == nil then
		warn(`[Monetization] receipt for unmapped product {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local handler = handlers[def.Type]
	if handler == nil then
		warn(`[Monetization] no handler for product type "{def.Type}"`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = PlayerData.get(player)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptKey = tostring(receiptInfo.PurchaseId)
	if data.Receipts[receiptKey] ~= nil then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, granted = pcall(handler, player, def)
	if not ok or not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.Receipts[receiptKey] = os.time()
	AnalyticsService.logEconomyEvent(
		player,
		"Source",
		"Robux",
		(receiptInfo.CurrencySpent :: number?) or 0,
		0,
		AnalyticsConfig.EconomyTransactionTypes.IAP,
		tostring(receiptInfo.ProductId),
		{ productType = def.Type }
	)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.registerHandler(productType: string, handler: (player: Player, def: any) -> boolean)
	handlers[productType] = handler
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
