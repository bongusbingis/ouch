--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

-- Client half of UI analytics. The server decides what each report becomes
-- (AnalyticsLogic.routeUIEvent turns a Shop open into funnel step 1 and the
-- rest into custom events), so this only names what the player did.

local AnalyticsReporter = {}

function AnalyticsReporter.report(kind: string, fields: { [string]: any }?)
	local payload: { [string]: any } = { kind = kind }
	if fields then
		for key, value in fields do
			payload[key] = value
		end
	end
	Network.fireServer("ReportAnalyticsEvent", payload)
end

function AnalyticsReporter.menuOpened(menuId: string)
	AnalyticsReporter.report("MenuOpened", { menuId = menuId })
end

return AnalyticsReporter
