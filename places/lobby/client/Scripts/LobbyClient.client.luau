-- Name: LobbyClient.client.luau
-- Author: Jack C.
-- Description: Lobby client entry point: resolves the first-session routing decision before anything is presented, then either runs the training overlay and the shared combat client or mounts the normal lobby root.
-- Created: 2026-08-15

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react-roblox"))
local Replica = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("replica"))
local EconomyStore = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("EconomyStore")
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

local modules = script.Parent.Parent:WaitForChild("Modules")
local lobby = modules:WaitForChild("Lobby")
local PartyBackgroundController = require(lobby:WaitForChild("PartyBackgroundController"))
local PartyClient = require(lobby:WaitForChild("PartyClient"))
local TeleportPresentationClient = require(lobby:WaitForChild("TeleportPresentationClient"))
local OnboardingClient = require(modules:WaitForChild("Onboarding"):WaitForChild("OnboardingClient"))
local ReactRoot = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("ReactRoot")
)
local views = script.Parent.Parent:WaitForChild("UI")
local LobbyApp = require(views:WaitForChild("LobbyApp"))
local OnboardingApp = require(views:WaitForChild("OnboardingApp"))
local CombatHUD = require(views:WaitForChild("CombatHUD"))

local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local partyClient = PartyClient.new()
local teleportPresentation = TeleportPresentationClient.start(function()
	partyClient:setTeleportPresentationReady()
end)
local background = PartyBackgroundController.start()

ConfigReplication.startClient({
	GameModes = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameModes")),
	Matchmaking = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config")),
	Shop = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Shop")),
	Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Crates")),
	Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat")),
	AimAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AimAssist")),
})
EconomyStore.start()
ShopClient.start()
UIFeedback.start()
partyClient:start()
OnboardingClient.start()

-- The routing decision is made before anything is on screen, so an eligible
-- player never sees the lobby appear and then get taken away from them.
local route = OnboardingClient.resolveRoute()

local combatModules: { [string]: any } = {}
local combatConnections: { any } = {}
local optionalCombat: { [string]: boolean } = {}
local combatStarted = false

local function startOptional(name: string, callback: () -> ())
	local ok, err = pcall(callback)
	optionalCombat[name] = ok
	if not ok then
		warn(`[LobbyClient] Optional {name} unavailable: {err}`)
	end
end

-- Training runs the real combat client, not a lesson-shaped imitation of it, so
-- the feel a player learns here is the feel they get in a match.
local function startCombatClient()
	if combatStarted then
		return
	end
	combatStarted = true
	local clientModules =
		Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Modules")
	local Input = clientModules:WaitForChild("Input")
	local Presentation = clientModules:WaitForChild("Presentation")

	combatModules.AssistConfig = require(Input:WaitForChild("AssistConfig"))
	combatModules.CombatState = require(Presentation:WaitForChild("CombatState"))
	combatModules.InputRouter = require(Input:WaitForChild("InputRouter"))
	combatModules.CameraAssist = require(Input:WaitForChild("CameraAssist"))
	combatModules.CombatInputSender = require(Input:WaitForChild("CombatInputSender"))

	Combat.setInputEnabled(false)
	combatModules.AssistConfig.start()
	combatModules.CombatState.start()
	combatModules.InputRouter.start()
	combatModules.CameraAssist.start()
	combatModules.CombatInputSender.start()

	local CombatSession = require(
		ReplicatedStorage:WaitForChild("Shared")
			:WaitForChild("Game")
			:WaitForChild("Adapters")
			:WaitForChild("CombatSession")
	)
	table.insert(combatConnections, CombatSession.observeLocal(Combat.setInputEnabled))

	startOptional("ArmIK", function()
		require(Presentation:WaitForChild("ArmIK")).start()
	end)
	startOptional("BallVisuals", function()
		combatModules.BallVisuals = require(Presentation:WaitForChild("BallVisuals"))
		combatModules.BallVisuals.start()
	end)
	startOptional("HammerVisuals", function()
		combatModules.HammerVisuals = require(Presentation:WaitForChild("HammerVisuals"))
		combatModules.HammerVisuals.start()
	end)
	startOptional("SplatEffects", function()
		combatModules.SplatEffects = require(Presentation:WaitForChild("SplatEffects"))
		combatModules.SplatEffects.start()
	end)
	startOptional("GameAudio", function()
		combatModules.GameAudio = require(Presentation:WaitForChild("GameAudio"))
	end)
	startOptional("ChargeAim", function()
		require(Presentation:WaitForChild("ChargeAim")).start()
	end)
	startOptional("ThrowUX", function()
		local ThrowUXClient = require(clientModules:WaitForChild("UI"):WaitForChild("ThrowUXClient"))
		combatModules.ThrowUXClient = ThrowUXClient
		ThrowUXClient.start()
	end)
	startOptional("WeaponAnimations", function()
		local WeaponAnimations = require(Presentation:WaitForChild("WeaponAnimations"))
		WeaponAnimations.start()
		table.insert(combatConnections, combatModules.CombatInputSender.onIntent(WeaponAnimations.onIntent))
	end)

	local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
	table.insert(
		combatConnections,
		Network.on("CombatSimEvent", function(events)
			for _, event in events do
				if optionalCombat.BallVisuals then
					combatModules.BallVisuals.onEvent(event)
				end
				if optionalCombat.HammerVisuals then
					combatModules.HammerVisuals.onEvent(event)
				end
				if optionalCombat.SplatEffects then
					combatModules.SplatEffects.onEvent(event)
				end
				if optionalCombat.GameAudio then
					combatModules.GameAudio.onEvent(event)
				end
			end
		end)
	)

	-- The training dummies are sim characters, so the reticle and the trajectory
	-- preview treat them exactly as they treat another player.
	local AimDirector = require(Input:WaitForChild("AimDirector"))
	AimDirector.registerCharacterSource("OnboardingDummies", function()
		local folder = workspace:FindFirstChild("OnboardingDummies")
		local entries: { [string]: Model } = {}
		if folder then
			for _, model in folder:GetChildren() do
				if model:IsA("Model") then
					entries[model.Name] = model
				end
			end
		end
		return entries
	end)
end

local container = ReactRoot.create("LobbyRoot")
local root = ReactRoblox.createRoot(container)
local onboardingContainer = ReactRoot.create("OnboardingRoot", Enum.ScreenInsets.DeviceSafeInsets, 900)
local onboardingRoot = ReactRoblox.createRoot(onboardingContainer)
local combatContainer = ReactRoot.create("LobbyCombatRoot", Enum.ScreenInsets.None, 100)
local combatRoot = ReactRoblox.createRoot(combatContainer)

local function markPresented()
	ReplicatedFirst:SetAttribute("ReactLoadingPresented", true)
end

local function renderLobby(training: boolean)
	-- The lobby is suppressed rather than destroyed while training: the party
	-- adapter keeps running, so party membership and matchmaking survive
	-- untouched, and the reveal is a re-render rather than a rebuild.
	root:render(React.createElement(LobbyApp, {
		PartyClient = partyClient,
		ShopClient = ShopClient,
		Suppressed = training,
		CameraEnabled = not training,
		WorldPresentationEnabled = not training,
		OnPresented = markPresented,
	}))
end

local overlayMounted = false

-- Training can also begin later, from a voluntary replay, so mounting is driven
-- by the route rather than by which one happened to be true at startup.
local function applyRoute(training: boolean)
	if training and not overlayMounted then
		overlayMounted = true
		startCombatClient()
		onboardingRoot:render(React.createElement(OnboardingApp, { OnPresented = markPresented }))
		combatRoot:render(React.createElement(CombatHUD))
	elseif not training and overlayMounted then
		overlayMounted = false
		onboardingRoot:render(nil)
		combatRoot:render(nil)
	end
	renderLobby(training)
end

applyRoute(route == "Training")

OnboardingClient.subscribe(function(snapshot)
	if snapshot.route == "Training" or snapshot.route == "Lobby" then
		applyRoute(snapshot.route == "Training")
	end
end)

Replica.RequestData()

script.Destroying:Connect(function()
	root:unmount()
	onboardingRoot:unmount()
	combatRoot:unmount()
	container:Destroy()
	onboardingContainer:Destroy()
	combatContainer:Destroy()
	for _, connection in combatConnections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		else
			connection()
		end
	end
	table.clear(combatConnections)
	if combatStarted then
		combatModules.InputRouter.destroy()
		combatModules.CombatInputSender.destroy()
		combatModules.CombatState.destroy()
		if optionalCombat.ThrowUX then
			combatModules.ThrowUXClient.destroy()
		end
	end
	OnboardingClient.destroy()
	partyClient:destroy()
	teleportPresentation.destroy()
	if background then
		background:destroy()
	end
	EconomyStore.stop()
	ShopClient.stop()
	UIFeedback.destroy()
end)
