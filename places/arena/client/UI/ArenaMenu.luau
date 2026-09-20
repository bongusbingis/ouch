-- Description: Arena wrapper around the shared CombatMenu: derives menu availability from the arena's loading, vote, and teleport adapters and renders the shared overlay menu with the arena's settings context.

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
local PostMatchClient = require(script.Parent.Parent.Modules.UI.PostMatchClient)
local SplashdownClient = require(script.Parent.Parent.Modules.UI.SplashdownClient)

local c = React.createElement

-- The menu is reachable inside an admitted, ready match with no ballot or teleport
-- in progress. Results counts as well as Active: the wait on the results screen is
-- the idlest moment in the loop and the one where a player has just been paid, so
-- locking the storefront there while leaving it open mid-fight had it backwards.
-- Results without a packet yet is still the wrap-up loading screen, not a wait.
local function menuAvailable(loading, vote, teleportStatus, hasResult: boolean): boolean
	local admission = loading.admission
	local phase = loading.matchPhase
	local returning = teleportStatus ~= nil and teleportStatus.state ~= "Complete"
	return (admission == "Matched" or admission == "Direct")
		and loading.localReady
		and loading.serverReady
		and not vote.open
		and not returning
		and (phase == "Active" or (phase == "Results" and hasResult))
end

return function(props)
	local loading = useExternalStore(ArenaLoadingClient.getSnapshot, ArenaLoadingClient.subscribe)
	local vote = useExternalStore(ModeVoteClient.getSnapshot, ModeVoteClient.subscribe)
	local teleportStatus = useExternalStore(ArenaTeleportClient.getSnapshot, ArenaTeleportClient.subscribe)
	local postMatch = useExternalStore(PostMatchClient.getSnapshot, PostMatchClient.subscribe)
	local race = useExternalStore(SplashdownClient.getSnapshot, SplashdownClient.subscribe)

	return c(CombatMenu, {
		Available = race.phase ~= "Intro" and menuAvailable(loading, vote, teleportStatus, postMatch.result ~= nil),
		ShopClient = props.ShopClient,
		Place = "Arena",
	})
end
