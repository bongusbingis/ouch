-- Description: Root React component for the arena, rendering the loading screen, the game-mode ballot, and the in-match menu from their adapters' snapshots.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("Gameplay"):WaitForChild("GameModes"))
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

local function loadingCopy(loading, vote, teleportStatus, hasResult: boolean)
	local fixed = loading.fixedModeId ~= nil
	if teleportStatus then
		if teleportStatus.state == "Failed" then
			if teleportStatus.reason == "rewards_pending" then
				return "REWARDS ARE STILL SAVING", "TRY AGAIN TO CHECK YOUR REWARDS AND RETURN"
			end
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
			return if fixed then "GETTING THE RACE READY" else "GETTING THE VOTE READY", nil
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
	elseif fixed then
		return "GETTING THE RACE READY", "THE NEXT RACE STARTS SOON"
	end
	return "JOINING MATCH", nil
end

return function(props: Props)
	local matchHUD = useExternalStore(MatchHUDClient.getSnapshot, MatchHUDClient.subscribe)
	local race = useExternalStore(SplashdownClient.getView, SplashdownClient.subscribeView)
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

	-- A fixed-mode session (Splashdown) never shows a ballot: the vote step of
	-- the loading gate is satisfied outright so readiness reports as usual.
	local fixedMode = loading.fixedModeId ~= nil
	React.useEffect(function()
		if fixedMode then
			ArenaLoadingClient.markVotePrepared()
		end
	end, { fixedMode })
	local clientReady = loading.localReady and loading.serverReady
	local canPresentVote = clientReady and vote.admitted and vote.open and not fixedMode
	local votePresented = canPresentVote and presentedVoteStartsAt == vote.startsAt
	local matchVisible = clientReady
		and (
			loading.matchPhase == "Active"
			or loading.matchPhase == "Starting"
			or loading.matchPhase == "Intermission"
			or (loading.matchPhase == "Results" and postMatch.result ~= nil)
		)
	local returning = teleportStatus ~= nil and teleportStatus.state ~= "Complete"
	local loadingVisible = not hostPresented or returning or (not votePresented and not matchVisible)
	local hudAvailable = not loadingVisible and loading.matchPhase == "Active" and not menu.open
	local hudVisible = not loadingVisible
		and (loading.matchPhase == "Active" or loading.matchPhase == "Starting")
		and not menu.open
	-- The race HUD replaces the brawl HUD for the whole non-combat mode; the
	-- match HUD's own combat flag comes from the same replicated mode id.
	local raceMode = matchHUD.combat == false or loading.fixedModeId == "Splashdown"
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
	local title, detail = loadingCopy(loading, vote, teleportStatus, postMatch.result ~= nil)
	local queue = Queues.Queues[loading.queueId]
	local kicker = if queue then queue.Title else nil
	-- The bar counts assets while the client warms up, then the roster while
	-- the server waits for everyone; anything else waits on the dots.
	local progress: number? = nil
	if not loading.preloadReady and loading.preloadProgress > 0 then
		progress = loading.preloadProgress
	elseif loading.localReady and not loading.gateReleased and not returning and loading.fatalError == nil then
		local count = if loading.arrivedPlayerCount < loading.expectedPlayerCount
			then loading.arrivedPlayerCount
			else loading.readyPlayerCount
		progress = count / math.max(loading.expectedPlayerCount, 1)
	end
	local primaryAction = nil
	local secondaryAction = nil
	if teleportStatus and teleportStatus.state == "Failed" then
		primaryAction = {
			Text = "TRY AGAIN",
			Style = "Primary",
			OnActivated = ArenaTeleportClient.retry,
		}
		secondaryAction = {
			Text = "STAY",
			Style = "Secondary",
			OnActivated = ArenaTeleportClient.stay,
		}
	elseif loading.fatalError then
		primaryAction = if loading.simulationReady
			then {
				Text = "TRY AGAIN",
				Style = "Primary",
				OnActivated = ArenaLoadingClient.retryInitialization,
			}
			else nil
		secondaryAction = {
			Text = "RETURN",
			Style = "Secondary",
			OnActivated = ArenaTeleportClient.returnToLobby,
		}
	elseif loading.admission == "Rejected" then
		primaryAction = {
			Text = "RETURN",
			Style = "Primary",
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
		GameModeSelect = if fixedMode
			then nil
			else c(GameModeSelect, {
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
		Teammates = ReactRoblox.createPortal(
			c(TeammateMarkers, { Snapshot = matchHUD, Visible = hudAvailable and not matchHUD.scoreboardOpen }),
			playerGui
		),
		MatchHUD = if raceMode
			then nil
			else c(MatchHUD, {
				Snapshot = matchHUD,
				Visible = hudVisible,
				OnToggleScores = MatchHUDClient.toggleScoreboard,
				OnCloseScores = MatchHUDClient.closeScoreboard,
			}),
		SplashdownHUD = if raceMode
			then c(SplashdownHUD, {
				Snapshot = race,
				Match = matchHUD,
				Visible = hudVisible and race.visible,
				OnToggleScores = MatchHUDClient.toggleScoreboard,
				OnCloseScores = MatchHUDClient.closeScoreboard,
			})
			else nil,
		LoadingScreen = c(LoadingScreen, {
			Visible = loadingVisible,
			ParentScreenInsets = Enum.ScreenInsets.None,
			Title = title,
			Detail = detail,
			Kicker = kicker,
			Tip = tip,
			Progress = progress,
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
