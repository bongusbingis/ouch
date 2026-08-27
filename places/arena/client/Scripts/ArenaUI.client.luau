-- Name: ArenaUI.client.luau
-- Author: Jack C.
-- Description: Arena client entry point for user interface: mounts the React root, hands off from the bootstrap loading screen, and starts the UI adapter modules.
-- Created: 2026-08-17

--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local Replica = require(Packages:WaitForChild("replica"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local EconomyStore = require(Shared:WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("EconomyStore"))
local SettingsStore = require(Shared:WaitForChild("Game"):WaitForChild("Settings"):WaitForChild("SettingsStore"))
local ShopClient = require(Shared:WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("ShopClient"))
local LoadingScreen = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("LoadingScreen"))
local ReactRoot = require(Shared:WaitForChild("UI"):WaitForChild("Services"):WaitForChild("ReactRoot"))
local TeleportGui = require(Shared:WaitForChild("UI"):WaitForChild("Services"):WaitForChild("TeleportGui"))

local c = React.createElement

local bootstrapContainer = ReactRoot.create("ArenaLoadingBootstrap", Enum.ScreenInsets.None, 1100)
local bootstrapRoot = ReactRoblox.createRoot(bootstrapContainer)
local bootstrapPresented = false
local bootstrapDestroyed = false
local ArenaLoadingClient = nil

local function markBootstrapPresented()
	if bootstrapPresented then
		return
	end
	bootstrapPresented = true
	ReplicatedFirst:SetAttribute("ReactLoadingPresented", true)
	if ArenaLoadingClient then
		ArenaLoadingClient.markUiPresented()
	end
end

bootstrapRoot:render(c(LoadingScreen, {
	Visible = true,
	Title = "LOADING ARENA",
	Detail = "PREPARING THE ARENA",
	OnPresented = markBootstrapPresented,
}))

ArenaLoadingClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ArenaLoadingClient"))
local ModeVoteClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ModeVoteClient"))
local ArenaTeleportClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ArenaTeleportClient"))
local ArenaMenuClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ArenaMenuClient"))
local PostMatchClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("PostMatchClient"))
ArenaLoadingClient.start()
ModeVoteClient.start()
ArenaTeleportClient.start()
ArenaMenuClient.start()
PostMatchClient.start()
EconomyStore.start()
SettingsStore.start()
ShopClient.start({ DeferMarketplaceData = true })
if bootstrapPresented then
	ArenaLoadingClient.markUiPresented()
end

local UIFeedback = require(Shared:WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback"))
local arenaAppOk, ArenaApp = pcall(require, script.Parent.Parent:WaitForChild("UI"):WaitForChild("ArenaApp"))
if not arenaAppOk then
	warn(`[ArenaUI] Arena app failed to load: {ArenaApp}`)
	ArenaApp = function(props)
		return c(LoadingScreen, {
			Visible = true,
			Title = "ARENA COULD NOT LOAD",
			Detail = "RETURN TO THE LOBBY AND TRY AGAIN",
			PrimaryAction = {
				Text = "RETURN",
				Color = "Blue",
				OnActivated = ArenaTeleportClient.returnToLobby,
			},
			OnPresented = props.OnPresented,
		})
	end
end
local combatHudOk, CombatHUD = pcall(require, script.Parent.Parent:WaitForChild("UI"):WaitForChild("CombatHUD"))
if not combatHudOk then
	warn(`[ArenaUI] Combat HUD unavailable: {CombatHUD}`)
end
local arenaMenuOk, ArenaMenu = pcall(require, script.Parent.Parent:WaitForChild("UI"):WaitForChild("ArenaMenu"))
if not arenaMenuOk then
	warn(`[ArenaUI] Arena menu unavailable: {ArenaMenu}`)
end
local postMatchOk, PostMatchApp = pcall(require, script.Parent.Parent:WaitForChild("UI"):WaitForChild("PostMatchApp"))
if not postMatchOk then
	warn(`[ArenaUI] Post-match UI unavailable: {PostMatchApp}`)
end
local throwUxOk, ThrowUXClient =
	pcall(require, script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ThrowUXClient"))
if not throwUxOk then
	warn(`[ArenaUI] Throw feedback unavailable: {ThrowUXClient}`)
end

local container = ReactRoot.create("ArenaRoot", Enum.ScreenInsets.None, 1000)
local root = ReactRoblox.createRoot(container)
local combatContainer = ReactRoot.create("ArenaCombatRoot", Enum.ScreenInsets.None, 100)
local combatRoot = ReactRoblox.createRoot(combatContainer)
local menuContainer = ReactRoot.create("ArenaMenuRoot", Enum.ScreenInsets.DeviceSafeInsets, 500)
local menuRoot = ReactRoblox.createRoot(menuContainer)
local postMatchContainer = ReactRoot.create("ArenaPostMatchRoot", Enum.ScreenInsets.DeviceSafeInsets, 700)
local postMatchRoot = ReactRoblox.createRoot(postMatchContainer)

local function destroyBootstrap()
	if bootstrapDestroyed then
		return
	end
	bootstrapDestroyed = true
	bootstrapRoot:unmount()
	bootstrapContainer:Destroy()
end

root:render(c(ArenaApp, {
	OnPresented = function()
		markBootstrapPresented()
		destroyBootstrap()
	end,
}))
if combatHudOk then
	combatRoot:render(c(CombatHUD))
end
if arenaMenuOk then
	menuRoot:render(c(ArenaMenu, { ShopClient = ShopClient }))
end
if postMatchOk then
	postMatchRoot:render(c(PostMatchApp))
end
Replica.RequestData()

local teleportContainer = ReactRoot.createDetached("ArenaReturnLoadingScreen", Enum.ScreenInsets.None, 1100)
TeleportGui.prepare(teleportContainer)
local teleportRoot = ReactRoblox.createRoot(teleportContainer)
local teleportPresentationReady = false
local uiDestroyed = false
teleportRoot:render(c(LoadingScreen, {
	Visible = true,
	Static = true,
	Title = "RETURNING TO LOBBY",
	Detail = "TRAVELING FROM THE ARENA",
	OnPresented = function()
		if teleportPresentationReady then
			return
		end
		teleportPresentationReady = true
		task.spawn(function()
			local ok = TeleportGui.register(teleportContainer, function()
				return uiDestroyed
			end)
			if ok then
				for _ = 1, 6 do
					if uiDestroyed or Players.LocalPlayer:GetAttribute("TeleportPresentationReady") == true then
						return
					end
					Network.fireServer("TeleportPresentationReady")
					task.wait(1)
				end
			end
		end)
	end,
}))

UIFeedback.start()
if throwUxOk then
	local startedThrowUx, throwUxError = pcall(ThrowUXClient.start)
	if not startedThrowUx then
		warn(`[ArenaUI] Throw feedback could not start: {throwUxError}`)
		pcall(ThrowUXClient.destroy)
		throwUxOk = false
	end
end

script.Destroying:Connect(function()
	uiDestroyed = true
	destroyBootstrap()
	root:unmount()
	combatRoot:unmount()
	menuRoot:unmount()
	postMatchRoot:unmount()
	teleportRoot:unmount()
	container:Destroy()
	combatContainer:Destroy()
	menuContainer:Destroy()
	postMatchContainer:Destroy()
	teleportContainer:Destroy()
	if throwUxOk then
		ThrowUXClient.destroy()
	end
	ArenaTeleportClient.destroy()
	ArenaMenuClient.destroy()
	PostMatchClient.destroy()
	ModeVoteClient.destroy()
	ArenaLoadingClient.destroy()
	EconomyStore.stop()
	SettingsStore.stop()
	ShopClient.stop()
	UIFeedback.destroy()
end)
