-- Description: Studio story previewing the candy loading screen while a race server waits for its roster, with the queue kicker, a partly filled roster bar and a rotating tip.

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
			Kicker = "SPLASHDOWN",
			Title = "GETTING EVERYONE READY",
			Detail = "18 OF 24 READY",
			Progress = 0.75,
			Tip = "PURPLE LAVA SENDS YOU BACK TO YOUR LAST CHECKPOINT.",
		})
	)
end
