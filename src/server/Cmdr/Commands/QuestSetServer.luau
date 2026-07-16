--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local QuestService = require(Server:WaitForChild("Modules"):WaitForChild("QuestService"))

return function(_context: any, players: { Player }, questId: string, progress: number): string
	local result = CommandUtil.runForPlayers(players, function(player)
		return QuestService.setProgressForTesting(player, questId, progress)
	end)
	return `Set {questId} to {progress} | {result}`
end
