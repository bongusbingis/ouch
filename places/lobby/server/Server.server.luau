-- Name: Server.server.luau
-- Author: Jack C.
-- Description: Lobby server entry point for player lifecycle: loads and saves profiles and starts the shared analytics, config, cosmetics, character color, and economy services.
-- Created: 2026-07-12

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = script:WaitForChild("Modules")
local _ = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AnalyticsService = require(Modules:WaitForChild("AnalyticsService"))
local ConfigLiveService = require(Modules:WaitForChild("ConfigLiveService"))
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))
local CharacterColorService = require(Modules:WaitForChild("CharacterColorService"))
local EconomyService = require(Modules:WaitForChild("EconomyService"))
local SettingsService = require(Modules:WaitForChild("SettingsService"))
local OnboardingService = require(Modules:WaitForChild("Onboarding"):WaitForChild("OnboardingService"))
local OnboardingCombat = require(Modules:WaitForChild("Onboarding"):WaitForChild("OnboardingCombat"))

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
AnalyticsService.start()
CosmeticsService.start()
CharacterColorService.start()
EconomyService.start()
SettingsService.start()
OnboardingCombat.start()
OnboardingService.start()

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
