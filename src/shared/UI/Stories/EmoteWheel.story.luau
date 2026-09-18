-- Description: Edit-mode preview of the gameplay emote wheel with a fixed local controller snapshot.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local EmoteWheel = require(script.Parent.Parent.Components.EmoteWheel)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(
		target,
		React.createElement(EmoteWheel, {
			ShowTouchButton = false,
			Snapshot = {
				open = true,
				selected = 2,
				slots = { "EmoteWave", "ShowtimeTwirl", "ShowtimeFlex", "ShowtimeBounce" },
				capacity = 6,
				deviceClass = "Keyboard",
				pointer = Vector2.zero,
			},
		})
	)
end
