-- Description: Reports user interface interactions to the analytics service through one entry point.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local UIAnalytics = {}

function UIAnalytics.report(kind: string, fields: { [string]: any }?)
	local payload: { [string]: any } = { kind = kind }
	if fields then
		for key, value in fields do
			payload[key] = value
		end
	end
	Network.fireServer("ReportAnalyticsEvent", payload)
end

function UIAnalytics.menuOpened(menuId: string)
	UIAnalytics.report("MenuOpened", { menuId = menuId })
end

return UIAnalytics
