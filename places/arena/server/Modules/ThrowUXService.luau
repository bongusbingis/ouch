-- Description: Serves the throw onboarding flag from the player's profile so the client knows whether the first-time swipe-throw prompt still needs to be shown, and records when it has been learned.

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
