--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local QuestsPanel = require(script.Parent.Parent.Components.QuestsPanel)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	local state = target:GetAttribute("PreviewState") or "Mixed"
	return mount(
		target,
		React.createElement(QuestsPanel, {
			Compact = target:GetAttribute("Compact") ~= false,
			Short = target:GetAttribute("Short") == true,
			State = {
				dailyKey = "preview",
				resetAt = 0,
				quests = if state == "Empty"
					then {}
					else {
						{
							questId = "catch",
							title = "Catch 3 dodgeballs",
							progress = 1,
							goal = 3,
							claimed = false,
							reward = { kind = "Bonks", amount = 150 },
						},
						{
							questId = "elims",
							title = "Get 3 dodgeball eliminations",
							progress = 3,
							goal = 3,
							claimed = false,
							reward = { kind = "Bonks", amount = 175 },
						},
						{
							questId = "wins",
							title = "Win 2 matches",
							progress = 2,
							goal = 2,
							claimed = true,
							reward = { kind = "Bonks", amount = 250 },
						},
					},
			},
			PendingClaims = if state == "Pending" then { elims = true } else {},
			OnClaim = function() end,
		})
	)
end
