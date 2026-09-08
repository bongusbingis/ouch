-- Description: Starts the shared economy service cohort in one call so both the lobby and the arena bring up the same set of storefront, entitlement, and monetization services.

--!strict

local MatchAwardService = require(script.Parent.MatchAwardService)
local BattlePassService = require(script.Parent.BattlePassService)
local CrateService = require(script.Parent.CrateService)
local DailyRewardService = require(script.Parent.DailyRewardService)
local DirectPurchaseService = require(script.Parent.DirectPurchaseService)
local EntitlementService = require(script.Parent.EntitlementService)
local GamePassService = require(script.Parent.GamePassService)
local MonetizationService = require(script.Parent.MonetizationService)
local PaidRandomPolicyService = require(script.Parent.PaidRandomPolicyService)
local ShopService = require(script.Parent.ShopService)
local Network = require(game:GetService("ReplicatedStorage").Shared.Network)

local EconomyService = {}

local started = false

function EconomyService.start()
	if started then
		return
	end
	started = true

	EntitlementService.start()
	BattlePassService.start({ monetizationService = MonetizationService })
	PaidRandomPolicyService.start()
	CrateService.start()
	ShopService.start()
	DirectPurchaseService.start()
	MonetizationService.start()
	GamePassService.start()
	MatchAwardService.start()
	DailyRewardService.start()
	Network.handleProtected("GetPurchaseState", { rateLimit = 2 }, function(player)
		return {
			receipts = MonetizationService.purchaseState(player),
			ownedPasses = GamePassService.purchaseState(player),
		}
	end)
end

return EconomyService
