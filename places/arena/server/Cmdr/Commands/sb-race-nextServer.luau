-- Description: Server implementation of sb-race-next, advancing the race through the Splashdown service's admin seam.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local SplashdownService = require(
	ServerScriptService:WaitForChild("Server")
		:WaitForChild("Modules")
		:WaitForChild("Splashdown")
		:WaitForChild("SplashdownService")
)

return function(_context: any): string
	local ok, reason = SplashdownService.advanceForAdmin()
	if not ok then
		return `Could not advance the race: {reason or "unknown_error"}.`
	end
	local state = SplashdownService.stateForAdmin()
	return `Race is now {state.phase} (round {state.roundIndex}/{state.roundCount}).`
end
