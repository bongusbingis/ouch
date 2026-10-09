-- Description: Starts arena UI independently from the loading/readiness coordinator so a presentation fault cannot keep an admitted player in an arrival screen.

--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PRELUDE_RELEASE_SECONDS = 15
local loadingClient: any = nil
local cleanupActions: { () -> () } = {}
local uiDestroyed = false
local preludeReleased = false
local dismissBootstrap: (() -> ())? = nil

local function reportIssue(path: string, reason: string)
	warn(`[ArenaUI] startup issue at {path}: {reason}`)
	if loadingClient and type(loadingClient.reportStartupIssue) == "function" then
		loadingClient.reportStartupIssue(path, reason)
	end
end

local function releaseArrivalLoading()
	if ReplicatedFirst:GetAttribute("ReactLoadingPresented") ~= true then
		ReplicatedFirst:SetAttribute("ReactLoadingPresented", true)
	end
end

local function releaseExpiredPrelude()
	preludeReleased = true
	releaseArrivalLoading()
	if dismissBootstrap then
		dismissBootstrap()
	end
end

-- This happens before any React/UI wait. LoadingBootstrap owns the arriving
-- GUI and removes it after the handoff, even if the prelude never becomes ready.
task.delay(PRELUDE_RELEASE_SECONDS, releaseExpiredPrelude)

local function child(parent: Instance?, name: string, path: string): Instance?
	if parent == nil then
		return nil
	end
	local value = parent:WaitForChild(name, PRELUDE_RELEASE_SECONDS)
	if value == nil then
		reportIssue(path, "child was unavailable before the bounded startup wait")
	end
	return value
end

local function folder(parent: Instance?, name: string, path: string): Folder?
	local value = child(parent, name, path)
	if value and value:IsA("Folder") then
		return value
	end
	if value then
		reportIssue(path, `expected Folder, received {value.ClassName}`)
	end
	return nil
end

local function module(parent: Instance?, name: string, path: string): any?
	local value = child(parent, name, path)
	if value == nil then
		return nil
	end
	if not value:IsA("ModuleScript") then
		reportIssue(path, `expected ModuleScript, received {value.ClassName}`)
		return nil
	end
	local ok, result = pcall(require, value)
	if not ok then
		reportIssue(path, `module load failed: {result}`)
		return nil
	end
	if uiDestroyed then
		return nil
	end
	return result
end

local function addCleanup(cleanup: (() -> ())?)
	if cleanup then
		if uiDestroyed then
			pcall(cleanup)
		else
			table.insert(cleanupActions, cleanup)
		end
	end
end

local function cleanupUi()
	if uiDestroyed then
		return
	end
	uiDestroyed = true
	for index = #cleanupActions, 1, -1 do
		local ok, reason = pcall(cleanupActions[index])
		if not ok then
			warn(`[ArenaUI] cleanup failed: {reason}`)
		end
	end
	table.clear(cleanupActions)
end

script.Destroying:Connect(cleanupUi)

local function startService(path: string, service: any?, startName: string, stopName: string, argument: any?)
	if uiDestroyed or type(service) ~= "table" then
		return false
	end
	local start = service[startName]
	local stop = service[stopName]
	if type(start) ~= "function" or type(stop) ~= "function" then
		reportIssue(path, "start or cleanup function is unavailable")
		return false
	end
	local ok: boolean
	local reason: any
	if argument == nil then
		ok, reason = pcall(start)
	else
		ok, reason = pcall(start, argument)
	end
	if not ok then
		reportIssue(path, `start failed: {reason}`)
		pcall(stop)
		return false
	end
	if uiDestroyed then
		pcall(stop)
		return false
	end
	addCleanup(stop)
	return true
end

-- The coordinator is intentionally outside the React prelude. It owns only
-- client-side progress; its validated server snapshot still decides readiness.
task.spawn(function()
	local modules = folder(script.Parent.Parent, "Modules", "Arena.Modules")
	local uiModules = folder(modules, "UI", "Arena.Modules.UI")
	loadingClient = module(uiModules, "ArenaLoadingClient", "ArenaLoadingClient")
	startService("ArenaLoadingClient", loadingClient, "start", "destroy")
end)

task.spawn(function()
	local packages = folder(ReplicatedStorage, "Packages", "ReplicatedStorage.Packages")
	local react = module(packages, "react", "ReplicatedStorage.Packages.react")
	local reactRoblox = module(packages, "react-roblox", "ReplicatedStorage.Packages.react-roblox")
	local shared = folder(ReplicatedStorage, "Shared", "ReplicatedStorage.Shared")
	local sharedUi = folder(shared, "UI", "ReplicatedStorage.Shared.UI")
	local components = folder(sharedUi, "Components", "ReplicatedStorage.Shared.UI.Components")
	local services = folder(sharedUi, "Services", "ReplicatedStorage.Shared.UI.Services")
	local reactRoot = module(services, "ReactRoot", "ReactRoot")
	local loadingScreen = module(components, "LoadingScreen", "LoadingScreen")
	local network = module(shared, "Network", "Network")
	local replica = module(packages, "replica", "replica")
	if uiDestroyed or react == nil or reactRoblox == nil or reactRoot == nil then
		return
	end

	local c = react.createElement
	local bootstrapContainer: any = nil
	local bootstrapRoot: any = nil
	local bootstrapDestroyed = false
	local function destroyBootstrap()
		if bootstrapDestroyed then
			return
		end
		bootstrapDestroyed = true
		if bootstrapRoot then
			pcall(bootstrapRoot.unmount, bootstrapRoot)
		end
		if bootstrapContainer then
			bootstrapContainer:Destroy()
		end
	end
	dismissBootstrap = destroyBootstrap
	addCleanup(destroyBootstrap)
	if loadingScreen and not preludeReleased then
		local created, container = pcall(reactRoot.create, "ArenaLoadingBootstrap", Enum.ScreenInsets.None, 1100)
		if created then
			bootstrapContainer = container
			local rooted, root = pcall(reactRoblox.createRoot, container)
			if rooted then
				bootstrapRoot = root
				if preludeReleased then
					destroyBootstrap()
					return
				end
				local rendered, reason = pcall(function()
					root:render(c(loadingScreen, {
						Visible = true,
						ParentScreenInsets = Enum.ScreenInsets.None,
						Title = "LOADING ARENA",
						OnPresented = function()
							releaseArrivalLoading()
							if loadingClient and type(loadingClient.markUiPresented) == "function" then
								loadingClient.markUiPresented()
							end
						end,
					}))
				end)
				if not rendered then
					reportIssue("ArenaLoadingBootstrap", `render failed: {reason}`)
					destroyBootstrap()
				end
			else
				reportIssue("ArenaLoadingBootstrap", `root creation failed: {root}`)
			end
		else
			reportIssue("ArenaLoadingBootstrap", `container creation failed: {container}`)
		end
	end

	local arenaModules = folder(script.Parent.Parent, "Modules", "Arena.Modules")
	local arenaUiModules = folder(arenaModules, "UI", "Arena.Modules.UI")
	local sharedGame = folder(shared, "Game", "ReplicatedStorage.Shared.Game")
	local economy = folder(sharedGame, "Economy", "ReplicatedStorage.Shared.Game.Economy")
	local settings = folder(sharedGame, "Settings", "ReplicatedStorage.Shared.Game.Settings")
	local progression = folder(sharedGame, "Progression", "ReplicatedStorage.Shared.Game.Progression")

	local arenaCoreUi = module(arenaUiModules, "ArenaCoreUI", "ArenaCoreUI")
	local modeVoteClient = module(arenaUiModules, "ModeVoteClient", "ModeVoteClient")
	local splashdownClient = module(arenaUiModules, "SplashdownClient", "SplashdownClient")
	local arenaTeleportClient = module(arenaUiModules, "ArenaTeleportClient", "ArenaTeleportClient")
	local postMatchClient = module(arenaUiModules, "PostMatchClient", "PostMatchClient")
	local combatMenuClient = module(services, "CombatMenuClient", "CombatMenuClient")
	local economyStore = module(economy, "EconomyStore", "EconomyStore")
	local settingsStore = module(settings, "SettingsStore", "SettingsStore")
	local seasonStore = module(progression, "SeasonStore", "SeasonStore")
	local shopClient = module(economy, "ShopClient", "ShopClient")
	local throwUxClient = module(arenaUiModules, "ThrowUXClient", "ThrowUXClient")
	local teleportGui = module(services, "TeleportGui", "TeleportGui")
	if uiDestroyed then
		return
	end

	startService("ArenaCoreUI", arenaCoreUi, "start", "destroy")
	startService("ModeVoteClient", modeVoteClient, "start", "destroy")
	startService("SplashdownClient", splashdownClient, "start", "destroy")
	startService("ArenaTeleportClient", arenaTeleportClient, "start", "destroy")
	startService("CombatMenuClient", combatMenuClient, "start", "destroy")
	startService("PostMatchClient", postMatchClient, "start", "destroy")
	startService("EconomyStore", economyStore, "start", "stop")
	startService("SettingsStore", settingsStore, "start", "stop")
	startService("SeasonStore", seasonStore, "start", "stop")
	startService("ShopClient", shopClient, "start", "stop", { DeferMarketplaceData = true })
	startService("ThrowUXClient", throwUxClient, "start", "destroy")
	task.spawn(function()
		local uiFeedback = module(services, "UIFeedback", "UIFeedback")
		startService("UIFeedback", uiFeedback, "start", "destroy")
	end)
	if replica and type(replica.RequestData) == "function" then
		local requested, reason = pcall(replica.RequestData)
		if not requested then
			reportIssue("Replica.RequestData", tostring(reason))
		end
	end

	local function renderRoot(name: string, insets: Enum.ScreenInsets, order: number, component: any?, props: any?)
		if uiDestroyed or component == nil then
			return
		end
		local created, container = pcall(reactRoot.create, name, insets, order, true)
		if not created then
			reportIssue(name, `container creation failed: {container}`)
			return
		end
		if uiDestroyed then
			container:Destroy()
			return
		end
		addCleanup(function()
			container:Destroy()
		end)
		local rooted, root = pcall(reactRoblox.createRoot, container)
		if not rooted then
			reportIssue(name, `root creation failed: {root}`)
			return
		end
		if uiDestroyed then
			pcall(root.unmount, root)
			container:Destroy()
			return
		end
		addCleanup(function()
			root:unmount()
		end)
		local rendered, reason = pcall(function()
			root:render(c(component, props))
		end)
		if not rendered then
			reportIssue(name, `render failed: {reason}`)
			pcall(root.unmount, root)
			container:Destroy()
		end
	end

	local arenaUi = folder(script.Parent.Parent, "UI", "Arena.UI")
	local arenaApp = module(arenaUi, "ArenaApp", "ArenaApp")
	local combatHud = module(arenaUi, "CombatHUD", "CombatHUD")
	local arenaMenu = module(arenaUi, "ArenaMenu", "ArenaMenu")
	local postMatchApp = module(arenaUi, "PostMatchApp", "PostMatchApp")
	renderRoot("ArenaRoot", Enum.ScreenInsets.None, 1000, arenaApp, {
		OnPresented = function()
			releaseArrivalLoading()
			destroyBootstrap()
			if loadingClient and type(loadingClient.markUiPresented) == "function" then
				loadingClient.markUiPresented()
			end
		end,
	})
	renderRoot("ArenaCombatRoot", Enum.ScreenInsets.None, 100, combatHud)
	if shopClient then
		renderRoot("ArenaMenuRoot", Enum.ScreenInsets.CoreUISafeInsets, 500, arenaMenu, { ShopClient = shopClient })
	end
	renderRoot("ArenaPostMatchRoot", Enum.ScreenInsets.None, 700, postMatchApp)

	-- The return teleport screen is independent from the arena roots. Keep its
	-- registration and bounded acknowledgement alive when another root fails.
	if uiDestroyed then
		return
	end
	if
		teleportGui
		and loadingScreen
		and type(teleportGui.prepare) == "function"
		and type(teleportGui.register) == "function"
	then
		local created, teleportContainer =
			pcall(reactRoot.createDetached, "ArenaReturnLoadingScreen", Enum.ScreenInsets.None, 1100)
		if created then
			addCleanup(function()
				teleportContainer:Destroy()
			end)
			local prepared, prepareReason = pcall(teleportGui.prepare, teleportContainer)
			if not prepared then
				reportIssue("TeleportGui.prepare", tostring(prepareReason))
			else
				local rooted, teleportRoot = pcall(reactRoblox.createRoot, teleportContainer)
				if rooted then
					addCleanup(function()
						teleportRoot:unmount()
					end)
					local rendered, renderReason = pcall(function()
						teleportRoot:render(c(loadingScreen, {
							Visible = true,
							ParentScreenInsets = Enum.ScreenInsets.None,
							Static = true,
							Title = "RETURNING TO LOBBY",
							Detail = "TRAVELING FROM THE ARENA",
							OnPresented = function()
								if uiDestroyed then
									return
								end
								task.spawn(function()
									local registered = teleportGui.register(teleportContainer, function()
										return uiDestroyed
									end)
									if not registered or network == nil then
										return
									end
									for _ = 1, 6 do
										if
											uiDestroyed
											or Players.LocalPlayer:GetAttribute("TeleportPresentationReady") == true
										then
											return
										end
										network.fireServer("TeleportPresentationReady")
										task.wait(1)
									end
								end)
							end,
						}))
					end)
					if not rendered then
						reportIssue("ArenaReturnLoadingScreen", tostring(renderReason))
					end
				else
					reportIssue("ArenaReturnLoadingScreen", tostring(teleportRoot))
				end
			end
		else
			reportIssue("ArenaReturnLoadingScreen", tostring(teleportContainer))
		end
	end

	-- Emotes are optional presentation. A broken control or touch exclusion must
	-- not tear down the roots and clients that already started above.
	local emoteWheel = module(components, "EmoteWheel", "EmoteWheel")
	local emoteController = module(services, "EmoteWheelController", "EmoteWheelController")
	local playerModule = module(game:GetService("StarterPlayer"), "PlayerModule", "StarterPlayer.PlayerModule")
	local combat = if type(playerModule) == "table" then playerModule.Combat else nil
	if
		emoteWheel
		and emoteController
		and type(combat) == "table"
		and type(combat.registerHudExclusion) == "function"
	then
		renderRoot("ArenaEmoteRoot", Enum.ScreenInsets.CoreUISafeInsets, 800, emoteWheel, {
			EmptySlotsAssignable = false,
			TouchButtonPlacement = "BesideToolbar",
			RegisterTouchExclusion = function(rect)
				local ok, result = pcall(combat.registerHudExclusion, "EmoteButton", rect)
				if not ok or result == false then
					local reason = if ok then "registration returned false" else tostring(result)
					reportIssue("EmoteWheel.registerHudExclusion", reason)
					return false, reason
				end
				return true, nil
			end,
		})
		if network and type(emoteController.start) == "function" and type(emoteController.stop) == "function" then
			startService("EmoteWheelController", emoteController, "start", "stop", {
				onPlay = function(emoteId)
					network.fireServer("PlayEmote", emoteId)
				end,
				isEnabled = function()
					if combatMenuClient and combatMenuClient.getSnapshot().open then
						return false
					end
					if postMatchClient and postMatchClient.getSnapshot().visible then
						return true
					end
					local state = ReplicatedStorage:FindFirstChild("MatchState")
					return state ~= nil
						and state:GetAttribute("phase") == "Active"
						and Players.LocalPlayer:GetAttribute("ArenaReady") == true
				end,
			})
			if
				type(emoteController.subscribe) == "function"
				and type(combat.requestCameraSuppression) == "function"
			then
				local subscribed, unsubscribe = pcall(emoteController.subscribe, function(wheel)
					if uiDestroyed then
						return
					end
					if wheel.open then
						combat.requestCameraSuppression("EmoteWheel")
					elseif type(combat.releaseCameraSuppression) == "function" then
						combat.releaseCameraSuppression("EmoteWheel")
					end
				end)
				if subscribed and type(unsubscribe) == "function" then
					addCleanup(unsubscribe)
				end
				if type(combat.releaseCameraSuppression) == "function" then
					addCleanup(function()
						combat.releaseCameraSuppression("EmoteWheel")
					end)
				end
			end
		end
	else
		reportIssue("EmoteWheel", "optional emote HUD was skipped")
	end
end)
