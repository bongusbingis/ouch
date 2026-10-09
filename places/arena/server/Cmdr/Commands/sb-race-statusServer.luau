-- Description: Server implementation of sb-race-status, formatting the Splashdown service's admin state.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local SplashdownService = require(
	ServerScriptService:WaitForChild("Server")
		:WaitForChild("Modules")
		:WaitForChild("Splashdown")
		:WaitForChild("SplashdownService")
)

return function(_context: any): string
	local state = SplashdownService.stateForAdmin()
	if not state.active then
		return "Splashdown is not the venue on this server."
	end
	return `Phase={state.phase} | Round={state.roundIndex}/{state.roundCount} | Course={state.courseId or "none"} | Sequence={table.concat(
		state.sequence,
		","
	)} | Racers={state.racers} | Finished={state.finished}`
end
