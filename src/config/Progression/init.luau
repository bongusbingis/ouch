--!strict

-- Progression config domain: re-exports each member so `require(Config.Progression).<Member>`
-- reaches the same table as requiring the member module directly.

return {
	Data = require(script:WaitForChild("Data")),
	Quests = require(script:WaitForChild("Quests")),
	Seasons = require(script:WaitForChild("Seasons")),
}
