-- Name: EconomyService.luau
-- Author: Jack C.
-- Description: Starts the shared economy service cohort in one call so both the lobby and the arena bring up the same set of storefront, entitlement, and monetization services.
-- Created: 2026-08-23

--!strict

local BattlePassService = require(script.Parent.BattlePassService)
local CrateService = require(script.Parent.CrateService)
local DirectPurchaseService = require(script.Parent.DirectPurchaseService)
local EntitlementService = require(script.Parent.EntitlementService)
local GamePassService = require(script.Parent.GamePassService)
local MonetizationService = require(script.Parent.MonetizationService)
local PaidRandomPolicyService = require(script.Parent.PaidRandomPolicyService)
local ShopService = require(script.Parent.ShopService)

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
end

return EconomyService
