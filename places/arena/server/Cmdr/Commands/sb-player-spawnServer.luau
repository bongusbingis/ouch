-- Name: sb-player-spawnServer.luau
-- Author: Jack C.
-- Description: Server implementation of sb-player-spawn, teleporting each targeted player to an authored arena spawn through the arena service.
-- Created: 2026-07-15

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local CommandUtil = require(Server:WaitForChild("Cmdr"):WaitForChild("CommandUtil"))
local MatchService = require(Server:WaitForChild("Modules"):WaitForChild("MatchService"))

return function(_context: any, targets: { Player }): string
	return CommandUtil.runForPlayers(targets, function(player)
		return MatchService.teleportToSpawnForTesting(player)
	end)
end
