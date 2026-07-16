--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local CommandUtil = require(Server:WaitForChild("Cmdr"):WaitForChild("CommandUtil"))
local InputSetup = require(Server:WaitForChild("Modules"):WaitForChild("InputSetup"))

return function(_context: any, targets: { Player }, deviceClass: string): string
	return CommandUtil.runForPlayers(targets, function(player)
		if not InputSetup.setDeviceClass(player, deviceClass) then
			return false, "invalid_device_class"
		end
		return true
	end)
end
