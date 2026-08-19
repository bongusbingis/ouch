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
local CosmeticsService = require(script.Parent.CosmeticsService)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)
local PaidRandomPolicyService = require(script.Parent.PaidRandomPolicyService)

-- Owns both crate payment paths and emits one identified result payload for
-- client reveal deduplication.

local CrateService = {}

local rng = Random.new()

type OpenResult = {
	openId: string,
	source: string,
	crateId: string,
	itemId: string,
	rarity: string,
	isDupe: boolean,
	bonksRefund: number,
	pityTriggered: string?,
}

local function rollAndGrant(player: Player, crateId: string, source: string, openId: string): OpenResult?
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
		})
	end

	local payload: OpenResult = {
		openId = openId,
		source = source,
		crateId = crateId,
		itemId = result.itemId,
		rarity = result.rarity,
		isDupe = result.isDupe,
		bonksRefund = result.bonksRefund,
		pityTriggered = result.pityTriggered,
	}
	local steps = AnalyticsConfig.ShopFunnelSteps.Completed
	AnalyticsService.logFunnelStep(player, AnalyticsConfig.Funnels.ShopPurchase, steps.step, steps.name, {
		crateId = crateId,
		rarity = result.rarity,
		source = source,
		isDupe = result.isDupe,
		pityTriggered = result.pityTriggered,
	})
	Network.fire("CrateOpened", player, payload)
	return payload
end

local function logCrateFailure(player: Player, reason: string)
	AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.CratePurchaseFailed, 1, { reason = reason })
end

-- Authoritative price. The storefront calls the same function, so the featured
-- discount it advertises is the one actually charged.
function CrateService.priceFor(crateId: string, now: number?): number?
	local crate = Crates[crateId]
	if crate == nil or crate.BonksPrice == nil then
		return nil
	end
	return FeaturedRotation.priceFor(Shop.Featured, crateId, crate.BonksPrice, now or os.time())
end

function CrateService.openWithBonks(player: Player, crateId: string): (OpenResult?, string?)
	local crate = Crates[crateId]
	if crate == nil or crate.BonksPrice == nil then
		logCrateFailure(player, "invalid_crate")
		return nil, "invalid_crate"
	end
	local price = CrateService.priceFor(crateId) :: number
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
	})

	local openId = HttpService:GenerateGUID(false)
	local ok, result = pcall(rollAndGrant, player, crateId, "Bonks", openId)
	if not ok then
		warn(`[CrateService] rollAndGrant failed for crate "{crateId}": {result}`)
		logCrateFailure(player, "crate_roll_failed")
		return nil, "crate_roll_failed"
	end
	if result == nil then
		logCrateFailure(player, "invalid_crate")
		return nil, "invalid_crate"
	end

	data.Bonks -= price
	AnalyticsService.logEconomyEvent(
		player,
		"Sink",
		"Bonks",
		price,
		data.Bonks,
		AnalyticsConfig.EconomyTransactionTypes.Shop,
		crateId
	)
	return result, nil
end

-- Roblox has already charged this receipt, so a restricted player must still be
-- made whole: pay the crate's Bonks value instead of rolling a random item.
-- Returning false here would strand the purchase in ProcessReceipt retries.
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
	local allowed, reason = PaidRandomPolicyService.canReceivePaidRandom(player)
	if not allowed then
		return grantRestrictedValue(player, crateId, purchaseId, reason or "paid_random_restricted")
	end
	return rollAndGrant(player, crateId, "Robux", purchaseId) ~= nil
end

function CrateService.openForTesting(player: Player, crateId: string): (OpenResult?, string?)
	if Crates[crateId] == nil then
		return nil, "invalid_crate"
	end
	local result = rollAndGrant(player, crateId, "Testing", "test-open")
	return result, if result then nil else "no_profile"
end

function CrateService.start()
	Network.handleProtected("OpenCrate", {
		rateLimit = 2,
		validate = function(_player, crateId)
			if typeof(crateId) ~= "string" then
				return false, "crateId must be a string"
			end
			return true
		end,
	}, function(player, crateId)
		return CrateService.openWithBonks(player, crateId)
	end)
end

return CrateService
