--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local PartyCode = require(script.Parent.Parent.Components.PartyCode)
local mount = require(script.Parent.StoryRoot)

local function Story()
	local visible, setVisible = React.useState(true)
	return React.createElement(PartyCode, {
		CodeText = if visible then "123-456" else "•••-•••",
		CodeVisible = visible,
		OnToggle = function()
			setVisible(not visible)
		end,
	})
end

return function(target: Instance)
	return mount(target, React.createElement(Story))
end
