--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local MatchService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("MatchService"))

return function(_context: any): string
	local state = MatchService.stateForTesting()
	local scoreEntries: { string } = {}
	for id, score in state.scores do
		table.insert(scoreEntries, `{id}={score}`)
	end
	table.sort(scoreEntries)

	local remaining = state.timeRemaining
	if state.phase == "Results" then
		remaining = state.resultsRemaining
	elseif state.phase == "Intermission" then
		remaining = state.intermissionRemaining
	end
	local scores = if #scoreEntries > 0 then table.concat(scoreEntries, ", ") else "none"
	return `Phase={state.phase} | Mode={state.modeId} | Map={state.mapId or "none"} | Remaining={string.format(
		"%.1f",
		remaining
	)} | Target={state.scoreTarget} | Winner={state.winnerId or "none"} | Scores: {scores}`
end
