--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local LoadingScreen = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("LoadingScreen"))
local ReactRoot = require(Shared:WaitForChild("UI"):WaitForChild("Services"):WaitForChild("ReactRoot"))

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
ArenaLoadingClient.start()
ModeVoteClient.start()
ArenaTeleportClient.start()
if bootstrapPresented then
	ArenaLoadingClient.markUiPresented()
end

local UIFeedback = require(Shared:WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback"))
local ArenaApp = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ArenaApp"))
local CombatHUD = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("CombatHUD"))
local ThrowUXClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ThrowUXClient"))

local container = ReactRoot.create("ArenaRoot", Enum.ScreenInsets.None, 1000)
local root = ReactRoblox.createRoot(container)
local combatContainer = ReactRoot.create("ArenaCombatRoot", Enum.ScreenInsets.None, 100)
local combatRoot = ReactRoblox.createRoot(combatContainer)

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
combatRoot:render(c(CombatHUD))

local teleportContainer = ReactRoot.createDetached("ArenaReturnLoadingScreen", Enum.ScreenInsets.None, 1100)
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
		local ok = pcall(TeleportService.SetTeleportGui, TeleportService, teleportContainer)
		if ok then
			task.spawn(function()
				for _ = 1, 6 do
					if uiDestroyed or Players.LocalPlayer:GetAttribute("TeleportPresentationReady") == true then
						return
					end
					Network.fireServer("TeleportPresentationReady")
					task.wait(1)
				end
			end)
		end
	end,
}))

UIFeedback.start()
ThrowUXClient.start()

script.Destroying:Connect(function()
	uiDestroyed = true
	destroyBootstrap()
	root:unmount()
	combatRoot:unmount()
	teleportRoot:unmount()
	container:Destroy()
	combatContainer:Destroy()
	teleportContainer:Destroy()
	ThrowUXClient.destroy()
	ArenaTeleportClient.destroy()
	ModeVoteClient.destroy()
	ArenaLoadingClient.destroy()
	UIFeedback.destroy()
end)
