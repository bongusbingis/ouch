-- Name: NotificationModal.story.luau
-- Author: Jack C.
-- Description: Studio story previewing the notification and confirmation modal.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local NotificationModal = require(script.Parent.Parent.Components.NotificationModal)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(
		target,
		React.createElement(NotificationModal, {
			Request = {
				Title = "KICK PLAYER?",
				Description = "ARE YOU SURE YOU WANT TO REMOVE PLAYER FROM YOUR PARTY?",
				Buttons = {
					{ Color = "Red", Text = "KICK", Value = true },
					{ Color = "Blue", Text = "CANCEL", Value = false },
				},
			},
			OnChoose = function() end,
		})
	)
end
