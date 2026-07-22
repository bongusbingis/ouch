--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local MenuManager = require(script.Parent.Parent.UI.MenuManager)

-- Reports UI-only telemetry (menu opens) to the server, which is the sole
-- caller of AnalyticsService. This module never calls AnalyticsService
-- itself — see server/Modules/AnalyticsService.luau.

local AnalyticsReporter = {}

local started = false

local function onMenuChanged(newMenu, _oldMenu, reason)
	if newMenu == nil then
		return
	end
	Network.fireServer("ReportAnalyticsEvent", {
		kind = "MenuOpened",
		menuId = newMenu,
		reason = reason,
	})
end

function AnalyticsReporter.start()
	if started then
		return
	end
	started = true
	MenuManager.onChanged(onMenuChanged)
end

return AnalyticsReporter
