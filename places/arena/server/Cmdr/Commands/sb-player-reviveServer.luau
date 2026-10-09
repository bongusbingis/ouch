-- Description: Server implementation of sb-player-revive, respawning each targeted eliminated player through the normal match respawn path.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local CommandUtil = require(Server:WaitForChild("Cmdr"):WaitForChild("CommandUtil"))
local MatchService = require(Server:WaitForChild("Modules"):WaitForChild("MatchService"))

return function(_context: any, targets: { Player }): string
	return CommandUtil.runForPlayers(targets, function(player)
		return MatchService.reviveForAdmin(player)
	end)
end
