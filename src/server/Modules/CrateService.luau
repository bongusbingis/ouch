-- Description: Handles crate opening from both the Bonks purchase path and Robux receipts through one roll-and-grant routine, applying the pure roll model and firing the reveal event the client renders.

--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Crates"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local CrateRolls = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CrateRolls")
)
local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Shop"))
local FeaturedRotation = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Economy")
		:WaitForChild("FeaturedRotation")
)
local CrateBatch = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CrateBatch")
)
local CosmeticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("CosmeticsLogic")
)
local WriteThroughProxy = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Data"):WaitForChild("WriteThroughProxy")
)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)
local PaidRandomPolicyService = require(script.Parent.PaidRandomPolicyService)

local CrateService = {}

local rng = Random.new()
local openingByPlayer: { [Player]: {} } = {}

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
	sequence: number?,
}

local function rollOne(data: any, crateId: string): OpenEntry
	local crate = Crates[crateId]
	local result = CrateRolls.roll(
		crate,
		Cosmetics.Items,
		Cosmetics.Rarities,
		data.Cosmetics.Owned,
		rng,
		data.Crates.Pity[crateId]
	)
	if result.isDupe then
		data.Bonks += result.bonksRefund
	else
		local grantIds = CosmeticsLogic.grantIds(Cosmetics.Items, result.itemId)
		assert(grantIds ~= nil, `crate "{crateId}" rolled an unknown item`)
		for _, itemId in grantIds do
			data.Cosmetics.Owned[itemId] = true
		end
	end

	data.Crates.Pity[crateId] = result.pity
	return {
		itemId = result.itemId,
		rarity = result.rarity,
		isDupe = result.isDupe,
		bonksRefund = result.bonksRefund,
		pityTriggered = result.pityTriggered,
	}
end

-- All rolls use detached state. A failed roll changes no live reward, pity or
-- wallet value; sequential draft writes still make in-batch duplicates/pity work.
local function rollBatch(
	player: Player,
	crateId: string,
	source: string,
	openId: string,
	count: number,
	unitPrice: number?,
	sequence: number?
): OpenResult?
	local data = PlayerData.get(player)
	if data == nil then
		return nil
	end
	local draft = {
		Bonks = data.Bonks,
		Cosmetics = WriteThroughProxy.snapshot(data.Cosmetics),
		Crates = if data.Crates then WriteThroughProxy.snapshot(data.Crates) else { Pity = {} },
	}
	local price = CrateBatch.totalPrice(unitPrice or 0, count)
	if draft.Bonks < price then
		return nil
	end
	local results: { OpenEntry } = {}
	for _ = 1, count do
		table.insert(results, rollOne(draft, crateId))
	end
	draft.Bonks -= price
	local result = {
		openId = openId,
		source = source,
		crateId = crateId,
		count = #results,
		results = results,
		sequence = sequence,
	}
	if source == "Bonks" then
		draft.Crates.LastBonksOpen = {
			sequence = sequence,
			crateId = crateId,
			count = count,
			unitPrice = unitPrice,
			result = result,
			revealed = false,
		}
	end
	if source == "Robux" then
		draft.ReceiptWork = WriteThroughProxy.snapshot(data.ReceiptWork or {})
		local work = draft.ReceiptWork[openId] or { Items = {} }
		work.Payload = { kind = "Crate", reveal = result }
		draft.ReceiptWork[openId] = work
	end
	if not PlayerData.commitCrateOpen(player, data, draft) then
		return nil
	end
	return result
end

local function logOpen(player: Player, payload: OpenResult, initialBonks: number)
	local balance = initialBonks
	for _, result in payload.results do
		if result.isDupe then
			balance += result.bonksRefund
			pcall(
				AnalyticsService.logEconomyEvent,
				player,
				"Source",
				"Bonks",
				result.bonksRefund,
				balance,
				AnalyticsConfig.EconomyTransactionTypes.Gameplay,
				payload.crateId
			)
		else
			pcall(
				AnalyticsService.logCustomEvent,
				player,
				AnalyticsConfig.CustomEvents.CosmeticGranted,
				1,
				{ itemId = result.itemId, source = payload.source, variantId = Shop.VariantId }
			)
		end
		local steps = AnalyticsConfig.ShopFunnelSteps.Completed
		pcall(AnalyticsService.logFunnelStep, player, AnalyticsConfig.Funnels.ShopPurchase, steps.step, steps.name, {
			crateId = payload.crateId,
			rarity = result.rarity,
			source = payload.source,
			isDupe = result.isDupe,
			pityTriggered = result.pityTriggered,
			variantId = Shop.VariantId,
		})
	end
end

local function fireReveal(player: Player, payload: OpenResult)
	local ok, err = pcall(Network.fire, "CrateOpened", player, payload)
	if not ok then
		warn(`[CrateService] committed open {payload.openId} reveal failed: {err}`)
	end
end

local function logCrateFailure(player: Player, reason: string)
	pcall(
		AnalyticsService.logCustomEvent,
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

local function lastBonksOpen(player: Player): any?
	local data = PlayerData.get(player)
	return data and data.Crates and data.Crates.LastBonksOpen
end

local function validSequence(sequence: any): boolean
	return type(sequence) == "number" and sequence >= 1 and sequence < 9007199254740991 and sequence % 1 == 0
end

local function replayBonksOpen(
	player: Player,
	crateId: string,
	count: number,
	sequence: number,
	unitPrice: number
): (OpenResult?, string?)
	local last = lastBonksOpen(player)
	local completed = if last then last.sequence else 0
	if sequence == completed then
		if last.crateId ~= crateId or last.count ~= count or last.unitPrice ~= unitPrice then
			return nil, "crate_request_mismatch"
		end
		return WriteThroughProxy.snapshot(last.result), nil
	elseif sequence < completed then
		return nil, "crate_request_stale"
	elseif sequence ~= completed + 1 then
		return nil, "crate_request_gap"
	end
	return nil, nil
end

local function performBonksOpen(
	player: Player,
	crateId: string,
	quantity: number,
	sequence: number,
	expectedUnitPrice: number
): (OpenResult?, string?)
	local crate = Crates[crateId]
	if crate == nil or crate.BonksPrice == nil or not CrateService.isOpenable(crateId) then
		logCrateFailure(player, "invalid_crate")
		return nil, "invalid_crate"
	end
	if not CrateBatch.isValidQuantity(crate, quantity) then
		logCrateFailure(player, "invalid_quantity")
		return nil, "invalid_quantity"
	end
	local unitPrice = CrateService.priceFor(crateId) :: number
	if unitPrice ~= expectedUnitPrice then
		return nil, "crate_price_changed"
	end
	local price = CrateBatch.totalPrice(unitPrice, quantity)
	local profile = PlayerData.get(player)
	if profile == nil then
		return nil, "no_profile"
	end
	local policyAllowed, policyReason = PaidRandomPolicyService.canReceivePaidRandom(player)
	if PlayerData.get(player) ~= profile then
		return nil, "no_profile"
	end
	local replay, replayReason = replayBonksOpen(player, crateId, quantity, sequence, expectedUnitPrice)
	if replay or replayReason then
		return replay, replayReason
	end
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

	local initialBonks = data.Bonks
	local openId = HttpService:GenerateGUID(false)
	local ok, result = pcall(rollBatch, player, crateId, "Bonks", openId, quantity, unitPrice, sequence)
	if not ok then
		warn(`[CrateService] rollBatch failed for crate "{crateId}": {result}`)
		logCrateFailure(player, "crate_roll_failed")
		return nil, "crate_roll_failed"
	end
	if result == nil then
		logCrateFailure(player, "invalid_crate")
		return nil, "invalid_crate"
	end
	-- The entire batch and charge are already committed before any observer runs.
	local steps = AnalyticsConfig.ShopFunnelSteps.Attempted
	pcall(AnalyticsService.logFunnelStep, player, AnalyticsConfig.Funnels.ShopPurchase, steps.step, steps.name, {
		crateId = crateId,
		source = "Bonks",
		count = quantity,
		variantId = Shop.VariantId,
	})
	logOpen(player, result, initialBonks)
	pcall(
		AnalyticsService.logEconomyEvent,
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

function CrateService.openWithBonks(
	player: Player,
	crateId: string,
	count: number?,
	sequence: number?,
	expectedUnitPrice: number?
): (OpenResult?, string?)
	local quantity = if count == nil then 1 else count
	-- Server-only admin calls may omit identity. The remote requires both fields.
	local last = lastBonksOpen(player)
	local requestSequence = sequence or (if last then last.sequence + 1 else 1)
	local unitPrice = expectedUnitPrice or CrateService.priceFor(crateId)
	if
		not validSequence(requestSequence)
		or type(unitPrice) ~= "number"
		or unitPrice ~= unitPrice
		or unitPrice <= 0
		or unitPrice == math.huge
	then
		return nil, "crate_request_mismatch"
	end
	local replay, reason = replayBonksOpen(player, crateId, quantity, requestSequence, unitPrice)
	if replay or reason then
		return replay, reason
	end
	if openingByPlayer[player] then
		return nil, "crate_processing"
	end
	local request = {}
	openingByPlayer[player] = request
	local ok, result, failure = pcall(performBonksOpen, player, crateId, quantity, requestSequence, unitPrice)
	if openingByPlayer[player] == request then
		openingByPlayer[player] = nil
	end
	if not ok then
		warn(`[CrateService] Bonks request {requestSequence} failed for {player.UserId}: {result}`)
		local committed = replayBonksOpen(player, crateId, quantity, requestSequence, unitPrice)
		return committed, if committed then nil else "crate_recovery_required"
	end
	return result, failure
end

function CrateService.acknowledgeBonksOpen(player: Player, sequence: number)
	local last = lastBonksOpen(player)
	if last and last.sequence == sequence then
		last.revealed = true
	end
end

local function grantRestrictedValue(
	player: Player,
	crateId: string,
	purchaseId: string,
	reason: string
): (boolean, any?)
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
	pcall(
		AnalyticsService.logEconomyEvent,
		player,
		"Source",
		"Bonks",
		amount,
		data.Bonks,
		AnalyticsConfig.EconomyTransactionTypes.IAP,
		crateId,
		{ substitutedFor = reason }
	)
	return true, {
		grantId = purchaseId,
		kind = "Bonks",
		amount = amount,
	}
end

function CrateService.openFromReceipt(player: Player, crateId: string, purchaseId: string): (boolean, any?)
	local data = PlayerData.get(player)
	local work = data and data.ReceiptWork and data.ReceiptWork[purchaseId]
	if work and work.Payload and work.Payload.kind == "Crate" then
		return true, WriteThroughProxy.snapshot(work.Payload)
	end
	if not CrateService.isOpenable(crateId) then
		return grantRestrictedValue(player, crateId, purchaseId, "crate_unavailable")
	end
	local profile = PlayerData.get(player)
	if profile == nil then
		return false
	end
	local allowed, reason = PaidRandomPolicyService.canReceivePaidRandom(player)
	if PlayerData.get(player) ~= profile then
		return false
	end
	if reason == "policy_unavailable" then
		return false
	end
	if not allowed then
		return grantRestrictedValue(player, crateId, purchaseId, reason or "paid_random_restricted")
	end
	local result = rollBatch(player, crateId, "Robux", purchaseId, 1)
	if result == nil then
		return false
	end
	logOpen(player, result, profile.Bonks - result.results[1].bonksRefund)
	return true, { kind = "Crate", reveal = result }
end

function CrateService.openForAdmin(player: Player, crateId: string): (OpenResult?, string?)
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
		validate = function(_player, crateId, count, sequence, unitPrice)
			if typeof(crateId) ~= "string" then
				return false, "crateId must be a string"
			end
			if type(count) ~= "number" or count < 1 or count > 10 or count % 1 ~= 0 then
				return false, "count must be a supported open quantity"
			end
			if
				not validSequence(sequence)
				or type(unitPrice) ~= "number"
				or unitPrice ~= unitPrice
				or unitPrice <= 0
				or unitPrice == math.huge
			then
				return false, "crate request identity and price are required"
			end
			return true
		end,
	}, function(player, crateId, count, sequence, unitPrice)
		return CrateService.openWithBonks(player, crateId, count, sequence, unitPrice)
	end)
	Network.handleProtected("AcknowledgeBonksCrate", {
		rateLimit = 4,
		validate = function(_player, sequence)
			return validSequence(sequence)
		end,
	}, CrateService.acknowledgeBonksOpen)
	Players.PlayerRemoving:Connect(function(player)
		openingByPlayer[player] = nil
	end)
end

return CrateService
