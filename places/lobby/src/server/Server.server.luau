-- Lobby profile lifecycle and cosmetic equip authority. The shared services
-- are mapped from the canonical source tree by lobby.project.json.

local Players = game:GetService("Players")

local Modules = script.Modules
local PlayerData = require(Modules.PlayerData)
local CosmeticsService = require(Modules.CosmeticsService)

CosmeticsService.start()

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
