-- Description: Studio story previewing the game mode ballot with fixed vote snapshots.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local GameModeSelect = require(script.Parent.Parent.Components.GameModeSelect)
local StoryRoot = require(script.Parent.StoryRoot)

local c = React.createElement

local function Story()
	local selected, setSelected = React.useState("FFA")
	return c("ScreenGui", {
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		GameModeSelect = c(GameModeSelect, {
			Active = true,
			EndsAt = Workspace:GetServerTimeNow() + 10,
			DurationSeconds = 10,
			Modes = {
				{
					Id = "FFA",
					Title = "FREE-FOR-ALL",
					Description = "First to 15 eliminations wins. Outlast other players to win.",
					ThumbnailId = "",
					SortOrder = 1,
					VoteCount = 1,
					Selected = selected == "FFA",
				},
				{
					Id = "TDM",
					Title = "TEAM DEATHMATCH",
					Description = "First team to 40 eliminations wins. Work together to win.",
					ThumbnailId = "",
					SortOrder = 2,
					VoteCount = 2,
					Selected = selected == "TDM",
				},
				{
					Id = "Infection",
					Title = "INFECTION",
					Description = "Survivors dodge the infected until the round timer expires.",
					ThumbnailId = "",
					SortOrder = 3,
					VoteCount = 3,
					Selected = selected == "Infection",
				},
			},
			OnVote = setSelected,
		}),
	})
end

return function(target: Instance)
	return StoryRoot(target, c(Story))
end
