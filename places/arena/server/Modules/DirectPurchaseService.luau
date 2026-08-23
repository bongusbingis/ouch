--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Shop"))
local DirectPurchase = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("DirectPurchase")
)
local AnalyticsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Analytics"))
local CosmeticsService = require(script.Parent.CosmeticsService)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)
local ShopService = require(script.Parent.ShopService)

-- Owns the guaranteed Bonks-for-cosmetic path, and the only place Bonks buys a
-- cosmetic. Nothing here is random, so it is deliberately outside
-- PaidRandomPolicyService's gate. Bonks is deducted only after CosmeticsService
-- reports the item as newly granted.
--
-- Availability is asked of ShopService rather than decided here: a cosmetic in
-- a rotating-shop category is buyable only while that player is actually being
-- offered it, which is what stops the rotation from being decorative.

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
