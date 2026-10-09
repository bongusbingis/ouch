-- Description: Server implementation of sb-data-add, applying a signed delta to the named profile field through PlayerData for each targeted player.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Cmdr = Server:WaitForChild("Cmdr")
local CommandUtil = require(Cmdr:WaitForChild("CommandUtil"))
local PlayerData = require(Server:WaitForChild("Modules"):WaitForChild("PlayerData"))

return function(_context: any, players: { Player }, field: string, amount: number): string
	local result = CommandUtil.runForPlayers(players, function(player)
		local ok = PlayerData.addFieldForAdmin(player, field, amount)
		return ok, if ok then nil else "profile_not_ready"
	end)
	local signedAmount = if amount >= 0 then `+{amount}` else tostring(amount)
	return `Changed {field} by {signedAmount} | {result}`
end
