-- Description: Edit-mode preview of the game-mode modal with no matchmaking request.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local QueuePickerModal = require(script.Parent.Parent.Components.QueuePickerModal)
local mount = require(script.Parent.StoryRoot)

local options = {
	{ id = "Arena", title = "ARENA PVP", description = "A fast dodgeball showdown." },
	{ id = "Splashdown", title = "SPLASHDOWN", description = "Race through the obstacle course." },
}

local function Story()
	local selected, setSelected = React.useState("Arena")
	return React.createElement(QueuePickerModal, {
		Open = true,
		FocusEnabled = false,
		Options = options,
		SelectedId = selected,
		Enabled = true,
		OnClose = function() end,
		OnSelect = setSelected,
	})
end

return function(target: Instance)
	return mount(target, React.createElement(Story))
end
