--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SplashPage = require(script.Parent.Parent.Components.SplashPage)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(
		target,
		React.createElement(SplashPage, {
			PartyState = "PRESS PLAY TO MATCHMAKE",
			ShowMatchmakingActivity = false,
			PlayText = "PLAY",
			PlayEnabled = true,
			OnPlay = function() end,
			OnInvite = function() end,
			OnJoinCode = function() end,
		})
	)
end
