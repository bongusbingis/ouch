-- Description: Edit-mode preview of the Backpack wheel with local assigned and locked slots.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local BackpackEmoteWheel = require(script.Parent.Parent.Components.BackpackEmoteWheel)
local mount = require(script.Parent.StoryRoot)

local function Story(props)
	local selected, setSelected = React.useState(2)
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Layout = React.createElement(
			"UIListLayout",
			{ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Wheel = React.createElement(BackpackEmoteWheel, {
			LayoutOrder = 1,
			HeaderHeight = 42,
			ContentWidth = props.ContentWidth,
			Compact = props.Compact,
			ColorId = "CharacterColorBlue",
			CostumeId = "RainHopper",
			SelectedSlot = selected,
			PendingEmote = { displayName = "Confetti Twirl" },
			WheelSnapshot = {
				slots = { "EmoteWave", "ShowtimeTwirl", "ShowtimeFlex", "ShowtimeBounce" },
				capacity = 6,
			},
			OnSelectSlot = setSelected,
			OnAssign = function() end,
			OnLockedSlot = function() end,
		}),
	})
end

return function(target: Instance)
	return mount(
		target,
		React.createElement(Story, {
			ContentWidth = target:GetAttribute("ContentWidth") or 760,
			Compact = target:GetAttribute("Compact") == true,
		})
	)
end
