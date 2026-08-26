-- Name: sb-match-restartServer.luau
-- Author: Jack C.
-- Description: Server implementation of sb-match-restart, restarting the match through the match service's developer mode-selection seam.
-- Created: 2026-07-15

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local MatchService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("MatchService"))

return function(_context: any, modeId: string?): string
	local ok, reason = MatchService.restartForTesting(modeId)
	if not ok then
		return `Could not restart the match: {reason or "unknown_error"}.`
	end

	local state = MatchService.stateForTesting()
	return `Restarted {state.modeId}.`
end
