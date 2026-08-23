--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local ThrowUXService = {}
local started = false

function ThrowUXService.start()
	if started then
		return
	end
	started = true
	Network.handleProtected("MarkSwipeThrowLearned", { rateLimit = 1 }, function(player)
		PlayerData.markSwipeThrowLearned(player)
	end)
end

return ThrowUXService
