--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local PlayerData = require(Server:WaitForChild("Modules"):WaitForChild("PlayerData"))

return function(_context: any, players: { Player }, field: string, value: number): string
	local result = CommandUtil.runForPlayers(players, function(player)
		local ok = PlayerData.setFieldForTesting(player, field, value)
		return ok, if ok then nil else "profile_not_ready"
	end)
	return `Set {field} to {value} | {result}`
end
