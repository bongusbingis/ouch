--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CrateRolls = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CrateRolls")
)
local AnalyticsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Analytics"))
local CosmeticsService = require(script.Parent.CosmeticsService)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)

-- Crate opening: Cash path via the OpenCrate remote, Robux path via
-- MonetizationService receipts. Both share one roll-and-grant routine; every
-- open fires CrateOpened to the buyer.
--
-- TODO(ui): the crate-reveal animation subscribes to the CrateOpened remote
-- ({ crateId, itemId, rarity, isDupe, cashRefund }).

local CrateService = {}

local rng = Random.new()

type OpenResult = {
	crateId: string,
	itemId: string,
	rarity: string,
	isDupe: boolean,
	cashRefund: number,
}

local function rollAndGrant(player: Player, crateId: string): OpenResult?
	local crate = Crates[crateId]
	local data = PlayerData.get(player)
	if crate == nil or data == nil then
		return nil
	end

	local result = CrateRolls.roll(crate, Cosmetics.Items, Cosmetics.Rarities, data.Cosmetics.Owned, rng)
	if result.isDupe then
		data.Cash += result.cashRefund
		AnalyticsService.logEconomyEvent(
			player,
			"Source",
			"Cash",
			result.cashRefund,
			data.Cash,
			AnalyticsConfig.EconomyTransactionTypes.Gameplay,
			crateId
		)
	else
		CosmeticsService.grant(player, result.itemId)
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.CosmeticGranted, 1, {
			itemId = result.itemId,
			source = "Crate",
		})
	end

	local payload: OpenResult = {
		crateId = crateId,
		itemId = result.itemId,
		rarity = result.rarity,
		isDupe = result.isDupe,
		cashRefund = result.cashRefund,
	}
	local steps = AnalyticsConfig.ShopFunnelSteps.Completed
	AnalyticsService.logFunnelStep(player, AnalyticsConfig.Funnels.ShopPurchase, steps.step, steps.name, {
		crateId = crateId,
		rarity = result.rarity,
		isDupe = result.isDupe,
	})
	Network.fire("CrateOpened", player, payload)
	return payload
end

local function logCrateFailure(player: Player, reason: string)
	AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.CratePurchaseFailed, 1, { reason = reason })
end

function CrateService.openWithCash(player: Player, crateId: string): (OpenResult?, string?)
	local crate = Crates[crateId]
	if crate == nil or crate.CashPrice == nil then
		logCrateFailure(player, "invalid_crate")
		return nil, "invalid_crate"
	end
	local data = PlayerData.get(player)
	if data == nil then
		logCrateFailure(player, "no_profile")
		return nil, "no_profile"
	end
	if data.Cash < crate.CashPrice then
		logCrateFailure(player, "insufficient_cash")
		return nil, "insufficient_cash"
	end

	local steps = AnalyticsConfig.ShopFunnelSteps.Attempted
	AnalyticsService.logFunnelStep(player, AnalyticsConfig.Funnels.ShopPurchase, steps.step, steps.name, {
		crateId = crateId,
	})

	-- Roll before charging: a misconfigured crate pool (e.g. all-zero-weight)
	-- asserts inside CrateRolls, and that must not cost the player cash.
	local ok, result = pcall(rollAndGrant, player, crateId)
	if not ok then
		warn(`[CrateService] rollAndGrant failed for crate "{crateId}": {result}`)
		logCrateFailure(player, "crate_roll_failed")
		return nil, "crate_roll_failed"
	end
	if result == nil then
		logCrateFailure(player, "invalid_crate")
		return nil, "invalid_crate"
	end

	data.Cash -= crate.CashPrice
	AnalyticsService.logEconomyEvent(
		player,
		"Sink",
		"Cash",
		crate.CashPrice,
		data.Cash,
		AnalyticsConfig.EconomyTransactionTypes.Shop,
		crateId
	)
	return result, nil
end

function CrateService.openFromReceipt(player: Player, crateId: string): boolean
	return rollAndGrant(player, crateId) ~= nil
end

function CrateService.openForTesting(player: Player, crateId: string): (OpenResult?, string?)
	if Crates[crateId] == nil then
		return nil, "invalid_crate"
	end
	local result = rollAndGrant(player, crateId)
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
		return CrateService.openWithCash(player, crateId)
	end)
end

return CrateService
