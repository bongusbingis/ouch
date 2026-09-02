--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SettingsPage = require(script.Parent.Parent.Components.SettingsPage)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(target, React.createElement(SettingsPage, { Place = "Lobby" }))
end
