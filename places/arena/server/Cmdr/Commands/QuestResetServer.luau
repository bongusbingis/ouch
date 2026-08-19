--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local QuestService = require(Server:WaitForChild("Modules"):WaitForChild("QuestService"))

return function(_context: any, players: { Player }): string
	local result = CommandUtil.runForPlayers(players, function(player)
		local ok = QuestService.resetForTesting(player)
		return ok, if ok then nil else "profile_not_ready"
	end)
	return `Reset daily quests | {result}`
end
