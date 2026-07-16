--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local CommandUtil = require(Server:WaitForChild("Cmdr"):WaitForChild("CommandUtil"))
local BallService = require(Server:WaitForChild("Modules"):WaitForChild("BallService"))

return function(_context: any, targets: { Player }): string
	return CommandUtil.runForPlayers(targets, function(player)
		if not BallService.grantHeldBall(player) then
			return false, "already_holding_or_no_character"
		end
		return true
	end)
end
