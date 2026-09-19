-- Description: Server implementation of sb-cooldowns-reset, queueing a weapon-state reset on the sim adapter for each targeted player.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommandUtil = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Cmdr"):WaitForChild("CommandUtil"))
local CombatSimServer = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Adapters")
		:WaitForChild("CombatSimServer")
)

return function(_context: any, targets: { Player }): string
	local result = CommandUtil.runForPlayers(targets, function(player)
		if not CombatSimServer.resetWeaponsForAdmin(player) then
			return false, "reset_rejected"
		end
		return true
	end)
	return `Queued weapon resets. {result}`
end
