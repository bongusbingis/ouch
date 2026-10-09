-- Description: Server implementation of sb-player-eliminate, routing through the match service elimination seam so scoring, quests, and respawn scheduling all run.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Modules = Server:WaitForChild("Modules")
local CommandUtil = require(Server:WaitForChild("Cmdr"):WaitForChild("CommandUtil"))
local MatchService = require(Modules:WaitForChild("MatchService"))
local QuestService = require(Modules:WaitForChild("QuestService"))

return function(context: any, targets: { Player }, source: Player?): string
	local creditedSource = source or context.Executor
	return CommandUtil.runForPlayers(targets, function(target)
		local eventSource = if target == creditedSource then nil else creditedSource
		local accepted, event = MatchService.eliminateForAdmin(eventSource, target)
		if not accepted then
			return false, "elimination_rejected"
		end
		QuestService.handleCombatEvent(event)
		return true
	end)
end
