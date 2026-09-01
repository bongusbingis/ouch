-- Name: sbCosmeticClearServer.luau
-- Author: Jack C.
-- Description: Server implementation of sb-cosmetic-clear, unequipping the named slot through the cosmetics service for each targeted player.
-- Created: 2026-07-15

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Modules = Server:WaitForChild("Modules")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))

return function(_context, players: { Player }, slot: string): string
	return CommandUtil.runForPlayers(players, function(player)
		return CosmeticsService.equip(player, slot, nil)
	end)
end
