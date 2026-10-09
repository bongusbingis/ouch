-- Description: Lobby client entry point: starts the party adapter, background controller, teleport presentation, and mounts the lobby React root.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
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
local DailyRewardStore = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("DailyReward")
		:WaitForChild("DailyRewardStore")
)
local SeasonStore = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("SeasonStore")
)
local QuestStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Quests"):WaitForChild("QuestStore")
)
local ShopClient = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("ShopClient")
)
local UIFeedback = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback")
)
local LiveConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("LiveConfig"))
local ConfigReplication = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Adapters")
		:WaitForChild("ConfigReplication")
)
local RotatingPlatforms = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("RotatingPlatforms")
)
local PlatformRider = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("PlatformRider")
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
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local EmoteWheel = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Components"):WaitForChild("EmoteWheel")
)
local EmoteWheelController = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Services")
		:WaitForChild("EmoteWheelController")
)

local RunService = game:GetService("RunService")
local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Debug"))
local LobbyCombatTestClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Debug"):WaitForChild("LobbyCombatTestClient"))
local CombatMenu = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CombatMenu")
)
local CombatMenuClient = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Services")
		:WaitForChild("CombatMenuClient")
)
local useExternalStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Hooks"):WaitForChild("useExternalStore")
)

-- Studio-only combat/cosmetics test session. Nothing below mounts or binds in a
-- normal lobby; the same gate the server uses keeps it out of production.
local combatTestEnabled = Debug.LobbyCombatTest == true and RunService:IsStudio()

local partyClient = PartyClient.new()
local teleportPresentation = TeleportPresentationClient.start(function()
	partyClient:setTeleportPresentationReady()
end)
local background = PartyBackgroundController.start()
local container = ReactRoot.create("LobbyRoot", Enum.ScreenInsets.CoreUISafeInsets, 0, true)
local root = ReactRoblox.createRoot(container)
-- Same surface the arena gives the combat HUD: no screen insets so the reticle
-- sits on the true centre, and its own root so lobby UI never reorders it.
local combatContainer = ReactRoot.create("LobbyCombatRoot", Enum.ScreenInsets.None, 100)
local combatRoot = ReactRoblox.createRoot(combatContainer)

ConfigReplication.startClient(LiveConfig.loadModules("lobby"))
EconomyStore.start()
SettingsStore.start()
ShopClient.start()
DailyRewardStore.start()
SeasonStore.start()
QuestStore.start()
UIFeedback.start()
partyClient:start()
OnboardingCombatClient.start()
OnboardingClient.start()
local motionStarted, motionError = pcall(RotatingPlatforms.startClientMover)
if not motionStarted then
	warn("[LobbyClient] rotating platform presentation unavailable: " .. tostring(motionError))
end
local riderStarted, riderError = pcall(PlatformRider.start)
if not riderStarted then
	warn("[LobbyClient] platform carry unavailable: " .. tostring(riderError))
end
OnboardingTargets.start()
OnboardingWaypoint.start()
OnboardingTargetMarkers.start()
OnboardingImpactVFX.start()
LobbyCombatTestClient.start()

-- The lobby backdrop is pinned in front of the camera, which would sit it
-- squarely in the player's view once training takes the camera. Onboarding's
-- active flag is the only thing that decides this, so it is read rather than
-- tracked separately.
local function applyBackgroundVisibility(snapshot)
	if background then
		background:setEnabled(not snapshot.active)
	end
end

local previousTouchControlsEnabled = GuiService.TouchControlsEnabled
local function applyMovementVisibility()
	GuiService.TouchControlsEnabled = OnboardingClient.getSnapshot().active
		or LobbyCombatTestClient.getSnapshot().active
end
applyBackgroundVisibility(OnboardingClient.getSnapshot())
applyMovementVisibility()
local unsubscribeMovement = OnboardingClient.subscribe(applyMovementVisibility)
local unsubscribeTestMovement = LobbyCombatTestClient.subscribe(applyMovementVisibility)
local unsubscribeBackground = OnboardingClient.subscribe(applyBackgroundVisibility)
root:render(React.createElement(LobbyApp, {
	PartyClient = partyClient,
	OnboardingClient = OnboardingClient,
	CombatTestClient = if combatTestEnabled then LobbyCombatTestClient else nil,
	ShopClient = ShopClient,
	DailyRewardStore = DailyRewardStore,
	SeasonStore = SeasonStore,
	QuestStore = QuestStore,
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
local emoteContainer = ReactRoot.create("LobbyEmoteRoot", Enum.ScreenInsets.CoreUISafeInsets, 800, true)
local emoteRoot = ReactRoblox.createRoot(emoteContainer)
emoteRoot:render(React.createElement(EmoteWheel, { ShowTouchButton = false }))
EmoteWheelController.start({
	onPlay = function(emoteId)
		Network.fireServer("PlayEmote", emoteId)
	end,
	isEnabled = function()
		return not OnboardingClient.getSnapshot().active
			and not LobbyCombatTestClient.getSnapshot().active
			and Players.LocalPlayer:GetAttribute("EmoteWheelBlocked") ~= true
	end,
})

-- The arena's overlay menu, mounted only for the Studio test session so a
-- developer can switch cosmetics mid-session exactly as they would in a match.
local menuContainer, menuRoot = nil, nil
if combatTestEnabled then
	CombatMenuClient.start()
	local function LobbyCombatMenu()
		local snapshot = useExternalStore(LobbyCombatTestClient.getSnapshot, LobbyCombatTestClient.subscribe)
		return React.createElement(CombatMenu, {
			Available = snapshot.active,
			ShopClient = ShopClient,
			Place = "Lobby",
		})
	end
	menuContainer = ReactRoot.create("LobbyMenuRoot", Enum.ScreenInsets.CoreUISafeInsets, 500, true)
	menuRoot = ReactRoblox.createRoot(menuContainer)
	menuRoot:render(React.createElement(LobbyCombatMenu))
end

Replica.RequestData()

script.Destroying:Connect(function()
	PlatformRider.stop()
	RotatingPlatforms.stop()
	root:unmount()
	container:Destroy()
	combatRoot:unmount()
	combatContainer:Destroy()
	EmoteWheelController.stop()
	emoteRoot:unmount()
	emoteContainer:Destroy()
	partyClient:destroy()
	unsubscribeBackground()
	unsubscribeMovement()
	unsubscribeTestMovement()
	GuiService.TouchControlsEnabled = previousTouchControlsEnabled
	OnboardingImpactVFX.destroy()
	OnboardingTargetMarkers.destroy()
	OnboardingTargets.destroy()
	OnboardingWaypoint.destroy()
	OnboardingClient.destroy()
	OnboardingCombatClient.destroy()
	LobbyCombatTestClient.destroy()
	if menuRoot then
		menuRoot:unmount()
	end
	if menuContainer then
		menuContainer:Destroy()
	end
	if combatTestEnabled then
		CombatMenuClient.destroy()
	end
	teleportPresentation.destroy()
	if background then
		background:destroy()
	end
	EconomyStore.stop()
	SettingsStore.stop()
	ShopClient.stop()
	DailyRewardStore.stop()
	SeasonStore.stop()
	QuestStore.stop()
	UIFeedback.destroy()
end)
