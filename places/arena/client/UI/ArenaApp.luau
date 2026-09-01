-- Name: ArenaApp.luau
-- Author: Jack C.
-- Description: Root React component for the arena, rendering the loading screen, the game-mode ballot, and the in-match menu from their adapters' snapshots.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("GameModes"))
local Loading = require(Config:WaitForChild("Loading"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModeRegistry = require(Shared:WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry"))
local GameModeSelect = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GameModeSelect"))
local GameVersion = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GameVersion"))
local LoadingBackdrop = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("LoadingBackdrop"))
local LoadingScreen = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("LoadingScreen"))
local useExternalStore = require(Shared:WaitForChild("UI"):WaitForChild("Hooks"):WaitForChild("useExternalStore"))
local ArenaLoadingClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ArenaLoadingClient"))
local ArenaTeleportClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ArenaTeleportClient"))
local ModeVoteClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ModeVoteClient"))
local PostMatchClient =
	require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("PostMatchClient"))
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local c = React.createElement

local CURSOR_REASON = "LoadingAction"

export type Props = {
	OnPresented: (() -> ())?,
}

local function imageId(value: any): string
	if value == nil or value == "" then
		return ""
	end
	local text = tostring(value)
	return if string.find(text, "rbxassetid://", 1, true) == 1 then text else `rbxassetid://{text}`
end

local function useLoadingTip(visible: boolean): string?
	local tip, setTip = React.useState(nil :: string?)
	React.useEffect(function()
		if not visible then
			setTip(nil)
			return
		end
		local thread = task.delay(Loading.TipDelaySeconds, function()
			local index = 1
			setTip(Loading.Tips[index])
			while true do
				task.wait(Loading.TipIntervalSeconds)
				index = index % #Loading.Tips + 1
				setTip(Loading.Tips[index])
			end
		end)
		return function()
			task.cancel(thread)
		end
	end, { visible })
	return tip
end

local function loadingCopy(loading, vote, teleportStatus, hasResult: boolean)
	if teleportStatus then
		if teleportStatus.state == "Failed" then
			return "RETURN FAILED", "WE COULD NOT REACH THE LOBBY"
		elseif teleportStatus.state == "Retrying" then
			return "RECONNECTING", `ATTEMPT {teleportStatus.attempt} OF {teleportStatus.maxAttempts}`
		elseif teleportStatus.state == "Attempting" then
			return "RETURNING TO LOBBY", "TRAVELING FROM THE ARENA"
		end
	end
	if loading.fatalError then
		return "ARENA COULD NOT LOAD", "CHECK YOUR CONNECTION AND TRY AGAIN"
	end
	if loading.admission == "Rejected" then
		return "UNABLE TO JOIN MATCH", "PLEASE RETURN TO THE LOBBY"
	elseif not loading.localReady then
		if loading.preloadReady and not loading.simulationReady then
			return "LOADING ARENA", "STARTING GAMEPLAY SYSTEMS"
		elseif loading.preloadReady then
			return "GETTING THE VOTE READY", nil
		end
		return "LOADING ARENA", "PREPARING THE ARENA"
	elseif not loading.gateReleased then
		if loading.arrivedPlayerCount < loading.expectedPlayerCount then
			return "WAITING FOR PLAYERS", `{loading.arrivedPlayerCount} OF {loading.expectedPlayerCount} IN ARENA`
		end
		return "GETTING EVERYONE READY", `{loading.readyPlayerCount} OF {loading.expectedPlayerCount} READY`
	elseif vote.open then
		return "GETTING THE VOTE READY", nil
	elseif loading.matchPhase == "Results" and not hasResult then
		return "JOINING NEXT ROUND", "THIS ROUND IS WRAPPING UP"
	end
	return "JOINING MATCH", nil
end

return function(props: Props)
	local loading = useExternalStore(ArenaLoadingClient.getSnapshot, ArenaLoadingClient.subscribe)
	local vote = useExternalStore(ModeVoteClient.getSnapshot, ModeVoteClient.subscribe)
	local teleportStatus = useExternalStore(ArenaTeleportClient.getSnapshot, ArenaTeleportClient.subscribe)
	local postMatch = useExternalStore(PostMatchClient.getSnapshot, PostMatchClient.subscribe)
	local hostPresented, setHostPresented = React.useState(false)
	local presentedVoteStartsAt, setPresentedVoteStartsAt = React.useState(-1)
	local options = if #vote.options > 0 then vote.options else loading.modeOptions
	local modes = {}
	for _, modeId in options do
		local definition = GameModes.Modes[modeId]
		local mode = ModeRegistry.get(modeId)
		if definition ~= nil and definition.Enabled and mode ~= nil then
			table.insert(modes, {
				Id = modeId,
				Title = definition.Title,
				Description = definition.Description,
				ThumbnailId = imageId(definition.ThumbnailId),
				SortOrder = definition.SortOrder,
				VoteCount = vote.voteCounts[modeId] or 0,
				Selected = vote.selectedModeId == modeId,
			})
		end
	end

	local clientReady = loading.localReady and loading.serverReady
	local canPresentVote = clientReady and vote.admitted and vote.open
	local votePresented = canPresentVote and presentedVoteStartsAt == vote.startsAt
	local matchVisible = clientReady
		and (
			loading.matchPhase == "Active"
			or loading.matchPhase == "Intermission"
			or (loading.matchPhase == "Results" and postMatch.result ~= nil)
		)
	local returning = teleportStatus ~= nil and teleportStatus.state ~= "Complete"
	local loadingVisible = not hostPresented or returning or (not votePresented and not matchVisible)
	local tip = useLoadingTip(loadingVisible and not returning)
	local title, detail = loadingCopy(loading, vote, teleportStatus, postMatch.result ~= nil)
	local primaryAction = nil
	local secondaryAction = nil
	if teleportStatus and teleportStatus.state == "Failed" then
		primaryAction = {
			Text = "TRY AGAIN",
			Color = "Blue",
			OnActivated = ArenaTeleportClient.retry,
		}
		secondaryAction = {
			Text = "STAY",
			Color = "Red",
			OnActivated = ArenaTeleportClient.stay,
		}
	elseif loading.fatalError then
		primaryAction = {
			Text = "TRY AGAIN",
			Color = "Blue",
			OnActivated = ArenaLoadingClient.retryInitialization,
		}
		secondaryAction = {
			Text = "RETURN",
			Color = "Red",
			OnActivated = ArenaTeleportClient.returnToLobby,
		}
	elseif loading.admission == "Rejected" then
		primaryAction = {
			Text = "RETURN",
			Color = "Blue",
			OnActivated = ArenaTeleportClient.returnToLobby,
		}
	end

	local actionable = primaryAction ~= nil or secondaryAction ~= nil
	React.useEffect(function()
		if actionable then
			Combat.requestCursor(CURSOR_REASON)
		else
			Combat.releaseCursor(CURSOR_REASON)
		end
		return function()
			Combat.releaseCursor(CURSOR_REASON)
		end
	end, { actionable })

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		VoteBackdrop = if vote.admitted
				and vote.open
				and not loading.worldReady
			then c(LoadingBackdrop, {
				Native = {
					Active = false,
					ZIndex = 0,
				},
			})
			else nil,
		GameModeSelect = c(GameModeSelect, {
			Active = canPresentVote,
			Prepared = vote.admitted and #modes > 0,
			Modes = modes,
			EndsAt = vote.endsAt,
			DurationSeconds = vote.durationSeconds,
			OnVote = ModeVoteClient.vote,
			OnPrepared = ArenaLoadingClient.markVotePrepared,
			OnPresented = function()
				setPresentedVoteStartsAt(vote.startsAt)
				ArenaLoadingClient.markBallotPresented(vote.startsAt)
			end,
		}),
		GameVersion = c(GameVersion),
		LoadingScreen = c(LoadingScreen, {
			Visible = loadingVisible,
			Title = title,
			Detail = detail,
			Tip = tip,
			Progress = if not loading.preloadReady and loading.preloadProgress > 0
				then loading.preloadProgress
				else nil,
			PrimaryAction = primaryAction,
			SecondaryAction = secondaryAction,
			OnPresented = function()
				if not hostPresented then
					setHostPresented(true)
					if props.OnPresented then
						props.OnPresented()
					end
				end
			end,
		}),
	})
end
