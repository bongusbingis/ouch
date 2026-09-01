--!strict

-- Economy config domain: re-exports each member so `require(Config.Economy).<Member>`
-- reaches the same table as requiring the member module directly.

return {
	Shop = require(script:WaitForChild("Shop")),
	Crates = require(script:WaitForChild("Crates")),
	Products = require(script:WaitForChild("Products")),
	Bundles = require(script:WaitForChild("Bundles")),
	GamePasses = require(script:WaitForChild("GamePasses")),
}
