-- Description: Edit-mode preview of the daily reward panel using a local seven-day reward projection.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local DailyRewardsPanel = require(script.Parent.Parent.Components.DailyRewardsPanel)
local mount = require(script.Parent.StoryRoot)

local days = {}
for day = 1, 7 do
	table.insert(days, {
		day = day,
		reward = { kind = "Bonks", amount = 75 + day * 25 },
		claimed = day < 3,
		available = day == 3,
		current = day == 3,
	})
end

return function(target: Instance)
	return mount(
		target,
		React.createElement(DailyRewardsPanel, {
			State = { canClaim = true, currentDay = 3, nextDay = 3, totalClaimed = 2, days = days },
			Compact = target:GetAttribute("Compact") == true,
			Summary = target:GetAttribute("Summary") == true,
			OnClaim = function() end,
		})
	)
end
