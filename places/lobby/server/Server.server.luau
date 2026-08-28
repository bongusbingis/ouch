-- Name: Server.server.luau
-- Author: Jack C.
-- Description: Lobby server entry point for player lifecycle: loads and saves profiles and starts the shared analytics, config, cosmetics, character color, economy, input, developer console, and first-session onboarding services.
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
local InputSetup = require(Modules:WaitForChild("InputSetup"))
local ThrowUXService = require(Modules:WaitForChild("ThrowUXService"))
local CmdrService = require(Modules:WaitForChild("CmdrService"))
local Onboarding = Modules:WaitForChild("Onboarding")
local OnboardingService = require(Onboarding:WaitForChild("OnboardingService"))
local OnboardingDebug = require(Onboarding:WaitForChild("OnboardingDebug"))

ConfigLiveService.start({
	modules = {
		GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModes")),
		Matchmaking = require(
			ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config")
		),
		Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Shop")),
		Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates")),
		-- The lobby runs real combat during onboarding, so the same sim-critical
		-- modules are live here and are held for the same reason: a training
		-- player's combat constants must not change underneath them.
		Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat")),
		AimAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AimAssist")),
	},
	holdSimOverrides = function()
		return OnboardingService.anyTraining()
	end,
})
AnalyticsService.start()
CosmeticsService.start()
CharacterColorService.start()
EconomyService.start()
InputSetup.start()
ThrowUXService.start()
CmdrService.start()
OnboardingService.start()
OnboardingDebug.start()

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
