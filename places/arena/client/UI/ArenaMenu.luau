-- Name: ArenaMenu.luau
-- Author: Jack C.
-- Description: Arena wrapper around the shared CombatMenu: derives menu availability from the arena's loading, vote, and teleport adapters and renders the shared overlay menu with the arena's settings context.
-- Created: 2026-08-24

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local CombatMenu = require(UI:WaitForChild("Components"):WaitForChild("CombatMenu"))
local useExternalStore = require(UI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))

local ArenaLoadingClient = require(script.Parent.Parent.Modules.UI.ArenaLoadingClient)
local ArenaTeleportClient = require(script.Parent.Parent.Modules.UI.ArenaTeleportClient)
local ModeVoteClient = require(script.Parent.Parent.Modules.UI.ModeVoteClient)

local c = React.createElement

-- The menu is only reachable inside an admitted, ready, active match with no
-- ballot or teleport in progress; anything else keeps the toggle hidden.
local function menuAvailable(loading, vote, teleportStatus): boolean
	local admission = loading.admission
	local phase = loading.matchPhase
	local returning = teleportStatus ~= nil and teleportStatus.state ~= "Complete"
	return (admission == "Matched" or admission == "Direct")
		and loading.localReady
		and loading.serverReady
		and not vote.open
		and not returning
		and phase == "Active"
end

return function(props)
	local loading = useExternalStore(ArenaLoadingClient.getSnapshot, ArenaLoadingClient.subscribe)
	local vote = useExternalStore(ModeVoteClient.getSnapshot, ModeVoteClient.subscribe)
	local teleportStatus = useExternalStore(ArenaTeleportClient.getSnapshot, ArenaTeleportClient.subscribe)

	return c(CombatMenu, {
		Available = menuAvailable(loading, vote, teleportStatus),
		ShopClient = props.ShopClient,
		Place = "Arena",
	})
end
