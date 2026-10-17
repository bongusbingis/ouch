-- Description: Server implementation of sb-quest-reset, clearing stored daily quest progress and claim flags for each targeted player.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local QuestService = require(Server:WaitForChild("Modules"):WaitForChild("QuestService"))

return function(_context: any, players: { Player }): string
	local result = CommandUtil.runForPlayers(players, function(player)
		local ok = QuestService.resetForAdmin(player)
		return ok, if ok then nil else "profile_not_ready"
	end)
	return `Reset daily quests | {result}`
end
