-- Description: Mounts the shared post-match results screen against the arena post-match adapter's snapshot and actions.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SharedUI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local PostMatchScreen = require(SharedUI:WaitForChild("Components"):WaitForChild("PostMatchScreen"))
local useExternalStore = require(SharedUI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local PostMatchClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("PostMatchClient"))

local c = React.createElement

return function()
	local snapshot = useExternalStore(PostMatchClient.getSnapshot, PostMatchClient.subscribe)
	return c(PostMatchScreen, {
		Visible = snapshot.visible,
		Result = snapshot.result,
		Status = snapshot.status,
		Requesting = snapshot.requesting,
		PendingAction = snapshot.pendingAction,
		Error = snapshot.error,
		OnPlayAgain = PostMatchClient.playAgain,
		OnReturnToLobby = PostMatchClient.returnToLobby,
		OnLeaveParty = PostMatchClient.leaveParty,
	})
end
