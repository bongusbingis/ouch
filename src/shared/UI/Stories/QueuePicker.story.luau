-- Description: Interactive edit-mode preview of the standalone queue picker.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local QueuePicker = require(script.Parent.Parent.Components.QueuePicker)
local mount = require(script.Parent.StoryRoot)

local options = {
	{ id = "Arena", title = "ARENA PVP", description = "A fast dodgeball showdown." },
	{ id = "Splashdown", title = "SPLASHDOWN", description = "Race through the obstacle course." },
}

local function Story(props)
	local selected, setSelected = React.useState("Arena")
	return React.createElement(QueuePicker, {
		Options = options,
		SelectedId = selected,
		Enabled = true,
		Compact = props.Compact,
		Stacked = props.Stacked,
		CardHeight = 220,
		Native = { Size = UDim2.fromScale(1, 1) },
		OnSelect = setSelected,
	})
end

return function(target: Instance)
	return mount(
		target,
		React.createElement(Story, {
			Compact = target:GetAttribute("Compact") == true,
			Stacked = target:GetAttribute("Stacked") == true,
		})
	)
end
