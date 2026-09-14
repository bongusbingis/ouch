-- Description: Mounts the shared post-match results screen against the arena post-match adapter's snapshot and actions.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SharedUI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local PostMatchScreen = require(SharedUI:WaitForChild("Components"):WaitForChild("PostMatchScreen"))
local useExternalStore = require(SharedUI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local CombatMenuClient = require(SharedUI:WaitForChild("Services"):WaitForChild("CombatMenuClient"))
local PostMatchClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("PostMatchClient"))

local c = React.createElement

local function openShop()
	CombatMenuClient.navigate("Shop")
	CombatMenuClient.open()
end

return function()
	local snapshot = useExternalStore(PostMatchClient.getSnapshot, PostMatchClient.subscribe)
	local menu = useExternalStore(CombatMenuClient.getSnapshot, CombatMenuClient.subscribe)
	return c(PostMatchScreen, {
		-- This root sits above the menu root, so the results screen stands down
		-- while the menu is open rather than covering it. The return countdown
		-- keeps running underneath; closing the menu brings the results back.
		Visible = snapshot.visible and not menu.open,
		Result = snapshot.result,
		Status = snapshot.status,
		Requesting = snapshot.requesting,
		PendingAction = snapshot.pendingAction,
		Error = snapshot.error,
		OnPlayAgain = PostMatchClient.playAgain,
		OnReturnToLobby = PostMatchClient.returnToLobby,
		OnLeaveParty = PostMatchClient.leaveParty,
		OnOpenShop = openShop,
	})
end
