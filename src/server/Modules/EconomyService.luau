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
