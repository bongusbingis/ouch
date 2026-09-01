--!strict

-- Gameplay config domain: re-exports each member so `require(Config.Gameplay).<Member>`
-- reaches the same table as requiring the member module directly.

return {
	Combat = require(script:WaitForChild("Combat")),
	AimAssist = require(script:WaitForChild("AimAssist")),
	MapFeatures = require(script:WaitForChild("MapFeatures")),
	GameModes = require(script:WaitForChild("GameModes")),
	Modes = require(script:WaitForChild("Modes")),
}
