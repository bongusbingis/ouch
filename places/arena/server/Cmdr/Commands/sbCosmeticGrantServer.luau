-- Name: sbCosmeticGrantServer.luau
-- Author: Jack C.
-- Description: Server implementation of sb-cosmetic-grant, writing ownership of a named cosmetic into each targeted player's profile.
-- Created: 2026-07-15

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Modules = Server:WaitForChild("Modules")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))
local PlayerData = require(Modules:WaitForChild("PlayerData"))

return function(_context, players: { Player }, itemId: string): string
	return CommandUtil.runForPlayers(players, function(player)
		local data = PlayerData.get(player)
		if data == nil then
			return false, "no_profile"
		end
		if data.Cosmetics.Owned[itemId] == true then
			return false, "already_owned"
		end
		return CosmeticsService.grant(player, itemId), "grant_failed"
	end)
end
