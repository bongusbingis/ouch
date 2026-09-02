--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local TopBar = require(script.Parent.Parent.Components.TopBar)
local mount = require(script.Parent.StoryRoot)

local function Story()
	local page, setPage = React.useState("SplashScreen")
	return React.createElement(TopBar, {
		CurrentPage = page,
		OnNavigate = setPage,
	})
end

return function(target: Instance)
	return mount(target, React.createElement(Story))
end
