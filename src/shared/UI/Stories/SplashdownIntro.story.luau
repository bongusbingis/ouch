-- Description: Edit-mode preview of the Splashdown course intro with a local deadline.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SplashdownIntro = require(script.Parent.Parent.Components.SplashdownIntro)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(
		target,
		React.createElement(SplashdownIntro, {
			CourseId = "WhirlPool",
			RoundLabel = "ROUND 1 / 3",
			Title = "WHIRLPOOL RUN",
			EndsAt = Workspace:GetServerTimeNow() + 9,
		})
	)
end
