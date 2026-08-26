-- Name: sbCosmeticRevokeServer.luau
-- Author: Jack C.
-- Description: Server implementation of sb-cosmetic-revoke, removing ownership of a named cosmetic and unequipping it if it was in use.
-- Created: 2026-07-15

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Modules = Server:WaitForChild("Modules")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))

return function(_context, players: { Player }, itemId: string): string
	return CommandUtil.runForPlayers(players, function(player)
		return CosmeticsService.revokeForTesting(player, itemId)
	end)
end
