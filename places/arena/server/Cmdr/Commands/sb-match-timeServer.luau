--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local MatchService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("MatchService"))

return function(_context: any, seconds: number): string
	if seconds < 0 or seconds ~= seconds or seconds == math.huge then
		return "Seconds must be a finite, non-negative number."
	end

	local ok, reason = MatchService.setTimeForTesting(seconds)
	if not ok then
		return `Could not set match time: {reason or "unknown_error"}.`
	end
	return `Set match time to {string.format("%.1f", seconds)} seconds.`
end
