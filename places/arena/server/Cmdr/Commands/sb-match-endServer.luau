--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local MatchService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("MatchService"))

return function(_context: any): string
	local ok, reason = MatchService.endForTesting()
	if not ok then
		return `Could not end the match: {reason or "unknown_error"}.`
	end
	return "Ended the active match."
end
