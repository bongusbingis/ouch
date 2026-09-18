-- Description: Edit-mode preview of the Splashdown HUD using a fixed local race snapshot.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SplashdownHUD = require(script.Parent.Parent.Components.SplashdownHUD)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(
		target,
		React.createElement(SplashdownHUD, {
			Visible = true,
			Snapshot = {
				intro = false,
				roundLabel = "ROUND 2 / 3",
				title = "WHIRLPOOL RUN",
				clock = "1:24.6",
				checkpointLabel = "CHECKPOINT 3 / 5",
				checkpointProgress = 0.6,
				closing = nil,
				countdown = nil,
				finished = false,
				phase = "Racing",
				toast = {
					title = "CHECKPOINT CLEAR!",
					subtitle = "YOU'RE IN THE RUNNING",
					rows = {
						{ placement = 1, name = "Mochi", time = "1:19.2", points = 10, isLocal = false },
						{ placement = 2, name = "YOU", time = "1:24.6", points = 8, isLocal = true },
					},
					summary = "KEEP MOVING!",
				},
			},
			Match = nil,
		})
	)
end
