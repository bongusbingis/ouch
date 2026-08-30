-- Name: LobbyClient.client.luau
-- Author: Jack C.
-- Description: Lobby client entry point: starts the party adapter, background controller, teleport presentation, and mounts the lobby React root.
-- Created: 2026-08-15

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react-roblox"))
local Replica = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("replica"))
local EconomyStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("EconomyStore")
)
local SettingsStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Settings"):WaitForChild("SettingsStore")
)
local ShopClient = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("ShopClient")
)
local UIFeedback = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback")
)
local ConfigReplication = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Adapters")
		:WaitForChild("ConfigReplication")
)

local lobby = script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Lobby")
local PartyBackgroundController = require(lobby:WaitForChild("PartyBackgroundController"))
local PartyClient = require(lobby:WaitForChild("PartyClient"))
local OnboardingClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Onboarding"):WaitForChild("OnboardingClient"))
local OnboardingCombatClient = require(
	script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Onboarding"):WaitForChild("OnboardingCombatClient")
)
local OnboardingWaypoint =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Onboarding"):WaitForChild("OnboardingWaypoint"))
local OnboardingTargets =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Onboarding"):WaitForChild("OnboardingTargets"))
local OnboardingImpactVFX =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Onboarding"):WaitForChild("OnboardingImpactVFX"))
local OnboardingTargetMarkers = require(
	script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Onboarding"):WaitForChild("OnboardingTargetMarkers")
)
local TeleportPresentationClient = require(lobby:WaitForChild("TeleportPresentationClient"))
local ReactRoot = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("ReactRoot")
)
local LobbyApp = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LobbyApp"))
local CombatHUD = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("CombatHUD"))
local OnboardingGestureLayer = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Components")
		:WaitForChild("Onboarding")
		:WaitForChild("OnboardingGestureLayer")
)

local partyClient = PartyClient.new()
local teleportPresentation = TeleportPresentationClient.start(function()
	partyClient:setTeleportPresentationReady()
end)
local background = PartyBackgroundController.start()
local container = ReactRoot.create("LobbyRoot")
local root = ReactRoblox.createRoot(container)
-- Same surface the arena gives the combat HUD: no screen insets so the reticle
-- sits on the true centre, and its own root so lobby UI never reorders it.
local combatContainer = ReactRoot.create("LobbyCombatRoot", Enum.ScreenInsets.None, 100)
local combatRoot = ReactRoblox.createRoot(combatContainer)

ConfigReplication.startClient({
	GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModes")),
	Matchmaking = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config")),
	Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Shop")),
	Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates")),
})
EconomyStore.start()
SettingsStore.start()
ShopClient.start()
UIFeedback.start()
partyClient:start()
OnboardingCombatClient.start()
OnboardingClient.start()
OnboardingTargets.start()
OnboardingWaypoint.start()
OnboardingTargetMarkers.start()
OnboardingImpactVFX.start()

-- The lobby backdrop is pinned in front of the camera, which would sit it
-- squarely in the player's view once training takes the camera. Onboarding's
-- active flag is the only thing that decides this, so it is read rather than
-- tracked separately.
local function applyBackgroundVisibility(snapshot)
	if background then
		background:setEnabled(not snapshot.active)
	end
end

applyBackgroundVisibility(OnboardingClient.getSnapshot())
local unsubscribeBackground = OnboardingClient.subscribe(applyBackgroundVisibility)
root:render(React.createElement(LobbyApp, {
	PartyClient = partyClient,
	OnboardingClient = OnboardingClient,
	ShopClient = ShopClient,
	OnPresented = function()
		ReplicatedFirst:SetAttribute("ReactLoadingPresented", true)
	end,
}))
combatRoot:render(React.createElement(React.Fragment, nil, {
	CombatHUD = React.createElement(CombatHUD),
	OnboardingGestures = React.createElement(OnboardingGestureLayer, {
		OnboardingClient = OnboardingClient,
	}),
}))
Replica.RequestData()

script.Destroying:Connect(function()
	root:unmount()
	container:Destroy()
	combatRoot:unmount()
	combatContainer:Destroy()
	partyClient:destroy()
	unsubscribeBackground()
	OnboardingImpactVFX.destroy()
	OnboardingTargetMarkers.destroy()
	OnboardingTargets.destroy()
	OnboardingWaypoint.destroy()
	OnboardingClient.destroy()
	OnboardingCombatClient.destroy()
	teleportPresentation.destroy()
	if background then
		background:destroy()
	end
	EconomyStore.stop()
	SettingsStore.stop()
	ShopClient.stop()
	UIFeedback.destroy()
end)
