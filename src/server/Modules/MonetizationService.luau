--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Products"))
local CrateService = require(script.Parent.CrateService)
local PlayerData = require(script.Parent.PlayerData)

-- Owns ProcessReceipt. Receipts are recorded in the profile for idempotency
-- (retries after grant return PurchaseGranted without re-granting); unknown
-- products and failures return NotProcessedYet so Roblox retries/refunds.
-- New product types (battle pass) register a handler here.

local MonetizationService = {}

local MAX_RECEIPTS = 50

local handlers: { [string]: (player: Player, def: any) -> boolean } = {
	Crate = function(player, def)
		return CrateService.openFromReceipt(player, def.CrateId)
	end,
}

local function pruneReceipts(receipts: any)
	local keys = {}
	for key in receipts do
		table.insert(keys, key)
	end
	if #keys <= MAX_RECEIPTS then
		return
	end
	table.sort(keys, function(a, b)
		return receipts[a] < receipts[b]
	end)
	for index = 1, #keys - MAX_RECEIPTS do
		receipts[keys[index]] = nil
	end
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local def = Products[receiptInfo.ProductId]
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
	pruneReceipts(data.Receipts)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.registerHandler(productType: string, handler: (player: Player, def: any) -> boolean)
	handlers[productType] = handler
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
