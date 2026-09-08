-- Description: Server implementation of sb-quest-complete, forcing an active daily quest to its completion threshold for each targeted player.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local QuestService = require(Server:WaitForChild("Modules"):WaitForChild("QuestService"))

return function(_context: any, players: { Player }, questId: string): string
	local result = CommandUtil.runForPlayers(players, function(player)
		return QuestService.completeForAdmin(player, questId)
	end)
	return `Completed {questId} | {result}`
end
