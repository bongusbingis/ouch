--!strict

-- Cosmetics config domain: re-exports each member so `require(Config.Cosmetics).<Member>`
-- reaches the same table as requiring the member module directly.

return {
	Cosmetics = require(script:WaitForChild("Cosmetics")),
	CosmeticEffects = require(script:WaitForChild("CosmeticEffects")),
	Inventory = require(script:WaitForChild("Inventory")),
}
