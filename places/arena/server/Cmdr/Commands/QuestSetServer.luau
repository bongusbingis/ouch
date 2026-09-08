-- Description: Server implementation of sb-quest-set, writing an explicit progress value onto an active daily quest for each targeted player.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local QuestService = require(Server:WaitForChild("Modules"):WaitForChild("QuestService"))

return function(_context: any, players: { Player }, questId: string, progress: number): string
	local result = CommandUtil.runForPlayers(players, function(player)
		return QuestService.setProgressForAdmin(player, questId, progress)
	end)
	return `Set {questId} to {progress} | {result}`
end
