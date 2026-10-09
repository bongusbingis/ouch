-- Description: Server implementation of sb-speed-scale, setting a named multiplicative walk-speed modifier on each targeted player.

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

return function(_context: any, targets: { Player }, scale: number): string
	if scale <= 0 or scale ~= scale or scale == math.huge then
		return "Scale must be a finite, positive number."
	end

	return CommandUtil.runForPlayers(targets, function(player)
		MovementSpeedService.setModifier(player, "Cmdr", scale)
		return true
	end)
end
