-- Description: Root React component for the arena, rendering the loading screen, the game-mode ballot, and the in-match menu from their adapters' snapshots.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("Gameplay"):WaitForChild("GameModes"))
local ArenaMaps = require(Config:WaitForChild("Gameplay"):WaitForChild("ArenaMaps"))
local T = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Tokens"))
local Queues = require(Config:WaitForChild("Gameplay"):WaitForChild("Queues"))
local Loading = require(Config:WaitForChild("Interface"):WaitForChild("Loading"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModeRegistry = require(Shared:WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry"))
local GameModeVoteViewModel = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Models")
		:WaitForChild("GameModeVoteViewModel")
)
local ArenaLoadingViewModel =
	require(Shared:WaitForChild("UI"):WaitForChild("Models"):WaitForChild("ArenaLoadingViewModel"))
local ErrorBoundary = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("ErrorBoundary"))
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
local MatchHUD = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("MatchHUD"))
local SplashdownHUD = require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("SplashdownHUD"))
local TeammateMarkers =
	require(Shared:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("Arena"):WaitForChild("TeammateMarkers"))
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local MatchHUDClient = require(script.Parent.Parent.Modules.UI.MatchHUDClient)
local SplashdownClient = require(script.Parent.Parent.Modules.UI.SplashdownClient)
local CombatMenuClient = require(Shared:WaitForChild("UI"):WaitForChild("Services"):WaitForChild("CombatMenuClient"))
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local c = React.createElement

local CURSOR_REASON = "LoadingAction"

export type Props = {
	OnPresented: (() -> ())?,
}

-- One crashing subtree must never unmount the rest of the arena UI: each major,
-- independent layer sits in its own boundary and drops to nothing on error.
-- resetKey grants a failed layer one fresh attempt when its round context changes.
local function guard(name: string, element: any, onError: ((err: any) -> ())?, resetKey: any?)
	return c(ErrorBoundary, { Name = `ArenaApp.{name}`, OnError = onError, ResetKey = resetKey }, { [name] = element })
end

local function imageId(value: any): string
	if value == nil or value == "" then
		return ""
	end
	local text = tostring(value)
	return if string.find(text, "rbxassetid://", 1, true) == 1 then text else `rbxassetid://{text}`
end

local function useLoadingTip(visible: boolean, tips: { string }): string?
	local tip, setTip = React.useState(nil :: string?)
	React.useEffect(function()
		if not visible then
			setTip(nil)
			return
		end
		local thread = task.delay(Loading.TipDelaySeconds, function()
			local index = 1
			setTip(tips[index])
			while true do
				task.wait(Loading.TipIntervalSeconds)
				index = index % #tips + 1
				setTip(tips[index])
			end
		end)
		return function()
			task.cancel(thread)
		end
	end, { visible })
	return tip
end

local function ConnectedTeammates(props: { Visible: boolean })
	local matchHUD = useExternalStore(MatchHUDClient.getSnapshot, MatchHUDClient.subscribe)
	return ReactRoblox.createPortal(
		c(TeammateMarkers, {
			Snapshot = matchHUD,
			Visible = props.Visible and not matchHUD.scoreboardOpen,
		}),
		playerGui
	)
end

local function ConnectedMatchHUD(props: { Visible: boolean })
	local matchHUD = useExternalStore(MatchHUDClient.getSnapshot, MatchHUDClient.subscribe)
	return c(MatchHUD, {
		Snapshot = matchHUD,
		Visible = props.Visible,
		OnToggleScores = MatchHUDClient.toggleScoreboard,
		OnCloseScores = MatchHUDClient.closeScoreboard,
	})
end

local function ConnectedSplashdownHUD(props: { Visible: boolean })
	local race = useExternalStore(SplashdownClient.getView, SplashdownClient.subscribeView)
	local matchHUD = useExternalStore(MatchHUDClient.getSnapshot, MatchHUDClient.subscribe)
	return c(SplashdownHUD, {
		Snapshot = race,
		Match = matchHUD,
		Visible = props.Visible and race.visible,
		OnToggleScores = MatchHUDClient.toggleScoreboard,
		OnCloseScores = MatchHUDClient.closeScoreboard,
	})
end

return function(props: Props)
	local menu = useExternalStore(CombatMenuClient.getSnapshot, CombatMenuClient.subscribe)
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
				Description = GameModeVoteViewModel.description(
					mode.resolveRules(),
					mode.scoreScope == "Team",
					vote.scoreTargets[modeId]
				),
				ThumbnailId = imageId(definition.ThumbnailId),
				SortOrder = definition.SortOrder,
				VoteCount = vote.voteCounts[modeId] or 0,
				Selected = vote.selectedModeId == modeId,
			})
		end
	end

	local mapChips = GameModeVoteViewModel.mapChips(vote, ArenaMaps, function(key: string): Color3
		return (T.Colors :: any)[key] or T.Colors.Yellow
	end, imageId)

	-- A fixed-mode session (Splashdown) never shows a ballot: the vote step of
	-- the loading gate is satisfied outright so readiness reports as usual.
	local fixedMode = loading.fixedModeId ~= nil
	React.useEffect(function()
		if fixedMode then
			ArenaLoadingClient.markVotePrepared()
		end
	end, { fixedMode })
	local clientReady = loading.localReady and loading.serverReady
	-- A player already on their way to the lobby keeps the results screen, not the ballot.
	local canPresentVote = clientReady and vote.admitted and vote.open and not fixedMode and not postMatch.departing
	local votePresented = canPresentVote and presentedVoteStartsAt == vote.startsAt
	-- Results stay up while a packet is showing or the lobby trip is under way. A
	-- fixed-mode server has no ballot, so its intermission and starting beats show
	-- the loading screen instead of an empty world between races.
	local phase = loading.matchPhase
	local resultsShowing = postMatch.result ~= nil and (phase == "Results" or postMatch.departing)
	local matchVisible = clientReady
		and (
			phase == "Active"
			or resultsShowing
			or (not fixedMode and (phase == "Starting" or phase == "Intermission"))
		)
	local returning = teleportStatus ~= nil and teleportStatus.state ~= "Complete"
	-- Once the bounded startup deadline releases a degraded client, keep the
	-- healthy HUD/root visible instead of leaving a generic loading overlay up.
	-- A rejected player never becomes ready, so the startup deadline degrades them;
	-- the overlay still stays up because it carries their only way back to the lobby.
	local loadingVisible = returning
		or loading.admission == "Rejected"
		or (not loading.initializationDegraded and (not hostPresented or (not votePresented and not matchVisible)))
	-- Too few players for any mode leaves the server idle with no ballot; after a
	-- short wait say so and offer RETURN instead of an endless JOINING MATCH.
	local waitingForRoster = loadingVisible and ArenaLoadingViewModel.isWaitingForRoster(loading, vote, teleportStatus)
	local rosterWaited, setRosterWaited = React.useState(false)
	React.useEffect(function()
		if not waitingForRoster then
			setRosterWaited(false)
			return
		end
		local thread = task.delay(ArenaLoadingViewModel.RosterWaitSeconds, function()
			setRosterWaited(true)
		end)
		return function()
			task.cancel(thread)
		end
	end, { waitingForRoster })
	local rosterStalled = waitingForRoster and rosterWaited
	local hudAvailable = not loadingVisible and loading.matchPhase == "Active" and not menu.open
	local hudVisible = not loadingVisible
		and (loading.matchPhase == "Active" or loading.matchPhase == "Starting")
		and not menu.open
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	local currentModeId = loading.fixedModeId or (if matchState then matchState:GetAttribute("modeId") else nil)
	local raceMode = loading.fixedModeId == "Splashdown"
		or (currentModeId ~= nil and GameModes.IsCombat(currentModeId) == false)
	React.useEffect(function()
		MatchHUDClient.setAvailable(hudAvailable)
		return function()
			MatchHUDClient.setAvailable(false)
		end
	end, { hudAvailable })
	local tip = useLoadingTip(
		loadingVisible and not returning,
		if loading.fixedModeId == "Splashdown" then Loading.RaceTips else Loading.Tips
	)
	local title, detail =
		ArenaLoadingViewModel.copy(loading, vote, teleportStatus, postMatch.result ~= nil, rosterStalled)
	local queue = Queues.Queues[loading.queueId]
	local kicker = if queue then queue.Title else nil
	-- The bar counts assets while the client warms up, then the roster while
	-- the server waits for everyone; anything else waits on the dots.
	local progress: number? = nil
	if not loading.preloadReady and loading.preloadProgress > 0 then
		progress = loading.preloadProgress
	elseif loading.localReady and not loading.gateReleased and not returning then
		local count = if loading.arrivedPlayerCount < loading.expectedPlayerCount
			then loading.arrivedPlayerCount
			else loading.readyPlayerCount
		progress = count / math.max(loading.expectedPlayerCount, 1)
	end
	local primaryKind, secondaryKind = ArenaLoadingViewModel.actions(loading, teleportStatus, rosterStalled)
	local primaryAction = nil
	local secondaryAction = nil
	if primaryKind == "Retry" then
		primaryAction = { Text = "TRY AGAIN", Style = "Primary", OnActivated = ArenaTeleportClient.retry }
	elseif primaryKind == "Return" then
		primaryAction = { Text = "RETURN", Style = "Primary", OnActivated = ArenaTeleportClient.returnToLobby }
	end
	if secondaryKind == "Stay" then
		secondaryAction = { Text = "STAY", Style = "Secondary", OnActivated = ArenaTeleportClient.stay }
	end

	local function presentHost()
		if not hostPresented then
			setHostPresented(true)
			if props.OnPresented then
				props.OnPresented()
			end
		end
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
			then guard(
				"VoteBackdrop",
				c(LoadingBackdrop, {
					Native = {
						Active = false,
						ZIndex = 0,
					},
				})
			)
			else nil,
		GameModeSelect = if fixedMode
			then nil
			else guard(
				"GameModeSelect",
				c(GameModeSelect, {
					Active = canPresentVote,
					Prepared = vote.admitted and #modes > 0,
					Modes = modes,
					EndsAt = vote.endsAt,
					DurationSeconds = vote.durationSeconds,
					OnVote = ModeVoteClient.vote,
					Maps = mapChips,
					OnVoteMap = ModeVoteClient.voteMap,
					OnPrepared = ArenaLoadingClient.markVotePrepared,
					OnPresented = function()
						setPresentedVoteStartsAt(vote.startsAt)
						ArenaLoadingClient.markBallotPresented(vote.startsAt)
					end,
				}),
				nil,
				vote.startsAt
			),
		GameVersion = guard("GameVersion", c(GameVersion)),
		Teammates = guard("Teammates", c(ConnectedTeammates, { Visible = hudAvailable })),
		MatchHUD = if raceMode
			then nil
			else guard("MatchHUD", c(ConnectedMatchHUD, { Visible = hudVisible }), nil, phase),
		SplashdownHUD = if raceMode
			then guard("SplashdownHUD", c(ConnectedSplashdownHUD, { Visible = hudVisible }), nil, phase)
			else nil,
		-- If the loading screen itself crashes it can never report "presented";
		-- release that handshake so the host and HUD are not held back for good.
		LoadingScreen = guard(
			"LoadingScreen",
			c(LoadingScreen, {
				Visible = loadingVisible,
				ParentScreenInsets = Enum.ScreenInsets.None,
				Title = title,
				Detail = detail,
				Kicker = kicker,
				Tip = tip,
				Progress = progress,
				PrimaryAction = primaryAction,
				SecondaryAction = secondaryAction,
				OnPresented = presentHost,
			}),
			presentHost
		),
	})
end
