-- Name: QuestClaimServer.luau
-- Author: Jack C.
-- Description: Server implementation of sb-quest-claim, invoking the quest service's claim path for each targeted player.
-- Created: 2026-07-15

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local QuestService = require(Server:WaitForChild("Modules"):WaitForChild("QuestService"))

return function(_context: any, players: { Player }, questId: string): string
	local result = CommandUtil.runForPlayers(players, function(player)
		local ok, response = QuestService.claim(player, questId)
		return ok, if ok then nil else tostring(response)
	end)
	return `Claimed {questId} | {result}`
end
