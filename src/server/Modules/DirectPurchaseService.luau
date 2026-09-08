-- Description: Handles buying a single named cosmetic outright with Bonks, enforcing price, ownership, affordability, and whether the item is currently offered.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Shop"))
local DirectPurchase = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("DirectPurchase")
)
local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local CosmeticsService = require(script.Parent.CosmeticsService)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)
local ShopService = require(script.Parent.ShopService)

local DirectPurchaseService = {}

local started = false

export type PurchaseResult = {
	itemId: string,
	rarity: string,
	price: number,
}

function DirectPurchaseService.purchase(player: Player, itemId: string): (PurchaseResult?, string?)
	local data = PlayerData.get(player)
	if data == nil then
		return nil, "no_profile"
	end

	if not ShopService.isPurchasable(player, itemId) then
		return nil, "not_offered"
	end

	local price, reason =
		DirectPurchase.evaluate(itemId, Cosmetics.Items, Cosmetics.Rarities, data.Cosmetics.Owned, data.Bonks)
	if price == nil then
		return nil, reason
	end

	if not CosmeticsService.grant(player, itemId) then
		return nil, "grant_failed"
	end
	data.Bonks -= price

	local item = Cosmetics.Items[itemId]
	AnalyticsService.logEconomyEvent(
		player,
		"Sink",
		"Bonks",
		price,
		data.Bonks,
		AnalyticsConfig.EconomyTransactionTypes.Shop,
		itemId,
		{ rarity = item.Rarity, source = "DirectBuy", variantId = Shop.VariantId }
	)
	AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.CosmeticGranted, 1, {
		itemId = itemId,
		source = "DirectBuy",
		variantId = Shop.VariantId,
	})

	return { itemId = itemId, rarity = item.Rarity, price = price }, nil
end

function DirectPurchaseService.start()
	if started then
		return
	end
	started = true
	Network.handleProtected("PurchaseCosmetic", {
		rateLimit = 2,
		validate = function(_player, itemId)
			if typeof(itemId) ~= "string" then
				return false, "itemId must be a string"
			end
			return true
		end,
	}, function(player, itemId)
		return DirectPurchaseService.purchase(player, itemId)
	end)
end

function DirectPurchaseService._resetForTest()
	started = false
end

return DirectPurchaseService
