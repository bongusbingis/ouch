-- Name: JoinCodeModal.story.luau
-- Author: Jack C.
-- Description: Studio story previewing the party join-code modal.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local JoinCodeModal = require(script.Parent.Parent.Components.JoinCodeModal)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(
		target,
		React.createElement(JoinCodeModal, {
			Open = true,
			OnClose = function() end,
			OnSubmit = function()
				return false, "PARTY CODE NOT FOUND"
			end,
		})
	)
end
