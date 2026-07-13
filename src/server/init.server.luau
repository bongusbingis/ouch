local Players = game:GetService("Players")

local Modules = script.Modules
local PlayerData = require(Modules.PlayerData)

Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
end)
