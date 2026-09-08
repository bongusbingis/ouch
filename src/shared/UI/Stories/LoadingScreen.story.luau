-- Description: Studio story previewing the loading screen at a fixed progress state.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local LoadingScreen = require(script.Parent.Parent.Components.LoadingScreen)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(
		target,
		React.createElement(LoadingScreen, {
			Visible = true,
			Title = "GETTING EVERYONE READY",
			Detail = "3 OF 4 READY",
			Tip = "CATCH AN INCOMING DODGEBALL TO STEAL IT.",
		})
	)
end
