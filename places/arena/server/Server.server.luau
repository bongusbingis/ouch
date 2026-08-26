-- Name: Server.server.luau
-- Author: Jack C.
-- Description: Arena profile lifecycle script, loading each player's profile on join and saving it on leave and at server shutdown.
-- Created: 2026-07-12

local Players = game:GetService("Players")

local Modules = script.Modules
local PlayerData = require(Modules.PlayerData)

Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.save(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(function()
		PlayerData.load(player)
	end)
end

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerData.save(player)
	end
end)
