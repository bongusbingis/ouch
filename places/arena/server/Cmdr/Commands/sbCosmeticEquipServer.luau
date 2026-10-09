-- Description: Server implementation of sb-cosmetic-equip, equipping a named cosmetic into its configured slot for each targeted player.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Modules = Server:WaitForChild("Modules")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))

return function(_context, players: { Player }, itemId: string): string
	local item = Cosmetics.Items[itemId]
	if item == nil then
		return `Unknown cosmetic: {itemId}`
	end
	return CommandUtil.runForPlayers(players, function(player)
		return CosmeticsService.equip(player, item.Category, itemId)
	end)
end
