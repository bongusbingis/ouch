--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local UI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local LoadingScreen = require(UI:WaitForChild("Components"):WaitForChild("LoadingScreen"))
local ReactRoot = require(UI:WaitForChild("Services"):WaitForChild("ReactRoot"))

local TeleportPresentationClient = {}

function TeleportPresentationClient.start(onReady: () -> ())
	local container = ReactRoot.createDetached("ArenaTeleportGui", Enum.ScreenInsets.None, 1000)
	local root = ReactRoblox.createRoot(container)
	local destroyed = false
	local registered = false

	root:render(React.createElement(LoadingScreen, {
		Visible = true,
		Static = true,
		Title = "TRAVELING TO ARENA",
		Detail = "THE MATCH IS READY",
		OnPresented = function()
			if destroyed or registered then
				return
			end
			local success, message = pcall(TeleportService.SetTeleportGui, TeleportService, container)
			if not success then
				warn(`[TeleportPresentationClient] Could not register teleport UI: {message}`)
				return
			end
			registered = true
			onReady()
		end,
	}))

	return {
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			root:unmount()
			container:Destroy()
		end,
	}
end

return TeleportPresentationClient
