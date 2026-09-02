--!strict

-- Interface config domain: re-exports each member so `require(Config.Interface).<Member>`
-- reaches the same table as requiring the member module directly.

return {
	UI = require(script:WaitForChild("UI")),
	Loading = require(script:WaitForChild("Loading")),
	Onboarding = require(script:WaitForChild("Onboarding")),
	PostMatch = require(script:WaitForChild("PostMatch")),
	Input = require(script:WaitForChild("Input")),
	MobileInput = require(script:WaitForChild("MobileInput")),
	ThrowUX = require(script:WaitForChild("ThrowUX")),
}
