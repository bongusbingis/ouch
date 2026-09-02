--!strict

-- Infra config domain: re-exports each member so `require(Config.Infra).<Member>`
-- reaches the same table as requiring the member module directly.

return {
	Analytics = require(script:WaitForChild("Analytics")),
	Debug = require(script:WaitForChild("Debug")),
	Audio = require(script:WaitForChild("Audio")),
	Animations = require(script:WaitForChild("Animations")),
	ThrowPose = require(script:WaitForChild("ThrowPose")),
}
