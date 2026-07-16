--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Modules = Server:WaitForChild("Modules")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))
local PlayerData = require(Modules:WaitForChild("PlayerData"))

return function(_context, players: { Player }): string
	local granted = 0
	local output = CommandUtil.runForPlayers(players, function(player)
		if PlayerData.get(player) == nil then
			return false, "no_profile"
		end
		granted += CosmeticsService.grantAllForTesting(player)
		return true
	end)
	return `{output} | Granted {granted} new cosmetics`
end
