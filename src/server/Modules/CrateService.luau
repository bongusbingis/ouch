-- Name: CrateService.luau
-- Author: Jack C.
-- Description: Handles crate opening from both the Bonks purchase path and Robux receipts through one roll-and-grant routine, applying the pure roll model and firing the reveal event the client renders.
-- Created: 2026-07-13

--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CrateRolls = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CrateRolls")
)
local AnalyticsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Analytics"))
local Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Shop"))
local FeaturedRotation = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Economy")
		:WaitForChild("FeaturedRotation")
)
local CrateBatch = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CrateBatch")
)
local CosmeticsService = require(script.Parent.CosmeticsService)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)
local PaidRandomPolicyService = require(script.Parent.PaidRandomPolicyService)

local CrateService = {}

local rng = Random.new()

type OpenEntry = {
	itemId: string,
	rarity: string,
	isDupe: boolean,
	bonksRefund: number,
	pityTriggered: string?,
}

type OpenResult = {
	openId: string,
	source: string,
	crateId: string,
	count: number,
	results: { OpenEntry },
}

local function rollOne(player: Player, crateId: string, source: string): OpenEntry?
	local crate = Crates[crateId]
	local data = PlayerData.get(player)
	if crate == nil or data == nil then
		return nil
	end
	if data.Crates == nil then
		data.Crates = { Pity = {} }
	end

	local result = CrateRolls.roll(
		crate,
		Cosmetics.Items,
		Cosmetics.Rarities,
		data.Cosmetics.Owned,
		rng,
		data.Crates.Pity[crateId]
	)
	data.Crates.Pity[crateId] = result.pity
	if result.isDupe then
		data.Bonks += result.bonksRefund
		AnalyticsService.logEconomyEvent(
			player,
			"Source",
			"Bonks",
			result.bonksRefund,
			data.Bonks,
			AnalyticsConfig.EconomyTransactionTypes.Gameplay,
			crateId
		)
	else
		CosmeticsService.grant(player, result.itemId)
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.CosmeticGranted, 1, {
			itemId = result.itemId,
			source = source,
			variantId = Shop.VariantId,
		})
	end

	local steps = AnalyticsConfig.ShopFunnelSteps.Completed
	AnalyticsService.logFunnelStep(player, AnalyticsConfig.Funnels.ShopPurchase, steps.step, steps.name, {
		crateId = crateId,
		rarity = result.rarity,
		source = source,
		isDupe = result.isDupe,
		pityTriggered = result.pityTriggered,
		variantId = Shop.VariantId,
	})
	return {
		itemId = result.itemId,
		rarity = result.rarity,
		isDupe = result.isDupe,
		bonksRefund = result.bonksRefund,
		pityTriggered = result.pityTriggered,
	}
end

-- Rolls are sequential on purpose: rollOne writes the pity counter back to the
-- profile each time, so a batch accumulates pity across its own opens and a
-- guarantee can land mid-batch. Ownership updates the same way, so the second
-- copy of a freshly granted item inside one batch is correctly a duplicate.
local function rollBatch(player: Player, crateId: string, source: string, openId: string, count: number): OpenResult?
	local results: { OpenEntry } = {}
	for _ = 1, count do
		local entry = rollOne(player, crateId, source)
		if entry == nil then
			return if #results == 0
				then nil
				else { openId = openId, source = source, crateId = crateId, count = #results, results = results }
		end
		table.insert(results, entry)
	end
	return { openId = openId, source = source, crateId = crateId, count = #results, results = results }
end

local function fireReveal(player: Player, payload: OpenResult)
	Network.fire("CrateOpened", player, payload)
end

local function logCrateFailure(player: Player, reason: string)
	AnalyticsService.logCustomEvent(
		player,
		AnalyticsConfig.CustomEvents.CratePurchaseFailed,
		1,
		{ reason = reason, variantId = Shop.VariantId }
	)
end

function CrateService.isOpenable(crateId: string): boolean
	local crate = Crates[crateId]
	return crate ~= nil and crate.CatalogStatus == "Active"
end

function CrateService.priceFor(crateId: string, now: number?): number?
	local crate = Crates[crateId]
	if crate == nil or crate.BonksPrice == nil then
		return nil
	end
	return FeaturedRotation.priceFor(Shop.Featured, crateId, crate.BonksPrice, now or os.time())
end

function CrateService.openWithBonks(player: Player, crateId: string, count: number?): (OpenResult?, string?)
	local crate = Crates[crateId]
	if crate == nil or crate.BonksPrice == nil or not CrateService.isOpenable(crateId) then
		logCrateFailure(player, "invalid_crate")
		return nil, "invalid_crate"
	end
	local quantity = if count == nil then 1 else count
	if not CrateBatch.isValidQuantity(crate, quantity) then
		logCrateFailure(player, "invalid_quantity")
		return nil, "invalid_quantity"
	end
	local unitPrice = CrateService.priceFor(crateId) :: number
	local price = CrateBatch.totalPrice(unitPrice, quantity)
	local policyAllowed, policyReason = PaidRandomPolicyService.canReceivePaidRandom(player)
	if not policyAllowed then
		logCrateFailure(player, policyReason or "paid_random_restricted")
		return nil, policyReason
	end
	local data = PlayerData.get(player)
	if data == nil then
		logCrateFailure(player, "no_profile")
		return nil, "no_profile"
	end
	if data.Bonks < price then
		logCrateFailure(player, "insufficient_bonks")
		return nil, "insufficient_bonks"
	end

	local steps = AnalyticsConfig.ShopFunnelSteps.Attempted
	AnalyticsService.logFunnelStep(player, AnalyticsConfig.Funnels.ShopPurchase, steps.step, steps.name, {
		crateId = crateId,
		source = "Bonks",
		count = quantity,
		variantId = Shop.VariantId,
	})

	local openId = HttpService:GenerateGUID(false)
	local ok, result = pcall(rollBatch, player, crateId, "Bonks", openId, quantity)
	if not ok then
		warn(`[CrateService] rollBatch failed for crate "{crateId}": {result}`)
		logCrateFailure(player, "crate_roll_failed")
		return nil, "crate_roll_failed"
	end
	if result == nil then
		logCrateFailure(player, "invalid_crate")
		return nil, "invalid_crate"
	end
	-- Charge only for the opens that actually resolved, so a batch cut short
	-- mid-roll can never bill for rewards the player did not receive.
	price = CrateBatch.totalPrice(unitPrice, result.count)

	data.Bonks -= price
	AnalyticsService.logEconomyEvent(
		player,
		"Sink",
		"Bonks",
		price,
		data.Bonks,
		AnalyticsConfig.EconomyTransactionTypes.Shop,
		crateId,
		{ variantId = Shop.VariantId, count = result.count }
	)
	fireReveal(player, result)
	return result, nil
end

local function grantRestrictedValue(player: Player, crateId: string, purchaseId: string, reason: string): boolean
	local crate = Crates[crateId]
	local data = PlayerData.get(player)
	if crate == nil or data == nil then
		return false
	end
	local amount = crate.BonksPrice
	if amount == nil or amount <= 0 then
		warn(`[CrateService] crate "{crateId}" is sold for Robux but has no BonksPrice to substitute`)
		return false
	end

	PlayerData.addBonks(player, amount)
	AnalyticsService.logEconomyEvent(
		player,
		"Source",
		"Bonks",
		amount,
		data.Bonks,
		AnalyticsConfig.EconomyTransactionTypes.IAP,
		crateId,
		{ substitutedFor = reason }
	)
	Network.fire("StorePurchaseGranted", player, {
		grantId = purchaseId,
		kind = "Bonks",
		amount = amount,
	})
	return true
end

function CrateService.openFromReceipt(player: Player, crateId: string, purchaseId: string): boolean
	if not CrateService.isOpenable(crateId) then
		return grantRestrictedValue(player, crateId, purchaseId, "crate_unavailable")
	end
	local allowed, reason = PaidRandomPolicyService.canReceivePaidRandom(player)
	if not allowed then
		return grantRestrictedValue(player, crateId, purchaseId, reason or "paid_random_restricted")
	end
	local result = rollBatch(player, crateId, "Robux", purchaseId, 1)
	if result == nil then
		return false
	end
	fireReveal(player, result)
	return true
end

function CrateService.openForTesting(player: Player, crateId: string): (OpenResult?, string?)
	if Crates[crateId] == nil then
		return nil, "invalid_crate"
	end
	local result = rollBatch(player, crateId, "Testing", HttpService:GenerateGUID(false), 1)
	if result ~= nil then
		fireReveal(player, result)
	end
	return result, if result then nil else "no_profile"
end

function CrateService.start()
	Network.handleProtected("OpenCrate", {
		rateLimit = 2,
		validate = function(_player, crateId, count)
			if typeof(crateId) ~= "string" then
				return false, "crateId must be a string"
			end
			if count ~= nil and not CrateBatch.isValidQuantity(Crates[crateId], count) then
				return false, "count must be an offered open quantity"
			end
			return true
		end,
	}, function(player, crateId, count)
		return CrateService.openWithBonks(player, crateId, count)
	end)
end

return CrateService
