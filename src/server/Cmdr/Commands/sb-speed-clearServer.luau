--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommandUtil = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Cmdr"):WaitForChild("CommandUtil"))
local MovementSpeedService = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Adapters")
		:WaitForChild("MovementSpeedService")
)

return function(_context: any, targets: { Player }): string
	return CommandUtil.runForPlayers(targets, function(player)
		MovementSpeedService.clearModifier(player, "Cmdr")
		return true
	end)
end
