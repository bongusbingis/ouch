-- Description: Mounts the teleport loading screen the lobby shows while a party is being sent to the arena, and reports back when it is on screen.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local UI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local LoadingScreen = require(UI:WaitForChild("Components"):WaitForChild("LoadingScreen"))
local ReactRoot = require(UI:WaitForChild("Services"):WaitForChild("ReactRoot"))
local TeleportGui = require(UI:WaitForChild("Services"):WaitForChild("TeleportGui"))

local TeleportPresentationClient = {}

function TeleportPresentationClient.start(onReady: () -> ())
	local container = ReactRoot.createDetached("ArenaTeleportGui", Enum.ScreenInsets.None, 1000)
	TeleportGui.prepare(container)
	local root = ReactRoblox.createRoot(container)
	local destroyed = false
	local registered = false
	local registering = false

	root:render(React.createElement(LoadingScreen, {
		Visible = true,
		ParentScreenInsets = Enum.ScreenInsets.None,
		Static = true,
		Title = "TRAVELING TO ARENA",
		Detail = "THE MATCH IS READY",
		OnPresented = function()
			if destroyed or registered or registering then
				return
			end
			registering = true
			task.spawn(function()
				local success, message = TeleportGui.register(container, function()
					return destroyed
				end)
				registering = false
				if not success then
					if message ~= "cancelled" then
						warn(`[TeleportPresentationClient] Could not register teleport UI: {message}`)
					end
					return
				end
				registered = true
				onReady()
			end)
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
