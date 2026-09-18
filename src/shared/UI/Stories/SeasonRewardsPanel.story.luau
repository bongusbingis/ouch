-- Description: Edit-mode preview of the reward browser using only local reward states.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SeasonRewardsPanel = require(script.Parent.Parent.Components.SeasonRewardsPanel)
local mount = require(script.Parent.StoryRoot)

local entries = {
	{
		key = "1:Free:Base",
		tier = 1,
		track = "Free",
		kind = "Bonks",
		amount = 100,
		claimed = true,
		unlocked = true,
		claimable = false,
		needsPremium = false,
	},
	{
		key = "2:Free:Base",
		tier = 2,
		track = "Free",
		kind = "Bonks",
		amount = 200,
		claimed = false,
		unlocked = true,
		claimable = true,
		needsPremium = false,
	},
	{
		key = "3:Free:Base",
		tier = 3,
		track = "Free",
		kind = "Bonks",
		amount = 300,
		claimed = false,
		unlocked = false,
		claimable = false,
		needsPremium = false,
	},
	{
		key = "1:Premium:Base",
		tier = 1,
		track = "Premium",
		kind = "Bonks",
		amount = 250,
		claimed = false,
		unlocked = true,
		claimable = false,
		needsPremium = true,
	},
	{
		key = "2:Premium:Base",
		tier = 2,
		track = "Premium",
		kind = "Bonks",
		amount = 500,
		claimed = false,
		unlocked = false,
		claimable = false,
		needsPremium = true,
	},
}

local function Story(props)
	local selected, setSelected = React.useState("2:Free:Base")
	return React.createElement(SeasonRewardsPanel, {
		Entries = entries,
		SelectedKey = selected,
		Compact = props.Compact,
		Width = props.Width,
		OnSelectEntry = function(entry)
			setSelected(entry.key)
		end,
	})
end

return function(target: Instance)
	return mount(
		target,
		React.createElement(Story, {
			Compact = target:GetAttribute("Compact") == true,
			Width = target:GetAttribute("Width") or 900,
		})
	)
end
