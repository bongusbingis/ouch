-- Lobby profile lifecycle and cosmetic equip authority. The shared services
-- are mapped from the canonical source tree by lobby.project.json.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = script:WaitForChild("Modules")
-- Ensure the shared Network module runs on server startup so remotes are
-- materialized for tests and runtime consumers.
local _ = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AnalyticsService = require(Modules:WaitForChild("AnalyticsService"))
local ConfigLiveService = require(Modules:WaitForChild("ConfigLiveService"))
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))
local CharacterColorService = require(Modules:WaitForChild("CharacterColorService"))
local EconomyService = require(Modules:WaitForChild("EconomyService"))

ConfigLiveService.start({
	modules = {
		GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModes")),
		Matchmaking = require(
			ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config")
		),
		Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Shop")),
		Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates")),
	},
})
-- No match loop in the lobby; session, onboarding, economy and funnel
-- reporting still run.
AnalyticsService.start()
CosmeticsService.start()
CharacterColorService.start()
EconomyService.start()

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
