-- Description: Sole owner of the authoritative game-mode ballot: opens the vote for admitted ready players, counts validated votes, extends for late arrivals, resolves ties randomly, and projects a coherent snapshot for the UI.

--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("Gameplay"):WaitForChild("GameModes"))
local Loading = require(Config:WaitForChild("Interface"):WaitForChild("Loading"))
local Game = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local ModeVote = require(Game:WaitForChild("Modes"):WaitForChild("ModeVote"))
local ModeRegistry = require(Game:WaitForChild("Modes"):WaitForChild("ModeRegistry"))
local ScoreTarget = require(Game:WaitForChild("Modes"):WaitForChild("ScoreTarget"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local ArenaMaps = require(Config:WaitForChild("Gameplay"):WaitForChild("ArenaMaps"))
local AnalyticsConfig = require(Config:WaitForChild("Infra"):WaitForChild("Analytics"))
local AnalyticsService = require(script.Parent.AnalyticsService)
local ArenaMapService = require(script.Parent.ArenaMapService)
local ArenaReturnService = require(script.Parent.ArenaReturnService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local MatchService = require(script.Parent.MatchService)

local ModeVoteService = {}

local STATE_FOLDER_NAME = "ModeVoteState"
local SNAPSHOT_VALUE_NAME = "Snapshot"
local SNAPSHOT_SCHEMA_VERSION = 1
local SELECTION_ATTRIBUTE = "ModeVoteSelection"
local MAP_SELECTION_ATTRIBUTE = "MapVoteSelection"
local LATE_READY_MINIMUM_SECONDS = Loading.LateVoteMinimumSeconds
local MAXIMUM_VOTE_EXTENSION_SECONDS = Loading.LateVoteMaximumExtensionSeconds

local snapshotValue: StringValue? = nil
local vote: ModeVote.State? = nil
local mapVote: ModeVote.State? = nil
local voteStartsAt = 0
local voteEndsAt = 0
local voteMaximumEndsAt = 0
local pendingWinner: string? = nil
local winnerModeId = ""
local winnerMapId = ""
local revision = 0
local deadlineRevision = 0
local started = false
local random = Random.new()
local beginVote: () -> ()
local strandedReturnPending = false
local strandedSince: number? = nil
local settleUntil = 0
local settleRescheduled = false

local function playablePlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if ArenaSessionService.isRoundEligible(player) then
			table.insert(result, player)
		end
	end
	return result
end

local function admittedPlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if ArenaSessionService.isAdmitted(player) then
			table.insert(result, player)
		end
	end
	return result
end

local function ensureSnapshotValue(): StringValue
	if snapshotValue then
		return snapshotValue
	end

	local folder = Instance.new("Folder")
	folder.Name = STATE_FOLDER_NAME
	local created = Instance.new("StringValue")
	created.Name = SNAPSHOT_VALUE_NAME
	created.Parent = folder
	folder.Parent = ReplicatedStorage
	snapshotValue = created
	return created
end

local function configuredOptions(): { string }?
	local available = MatchService.availableModes()
	return if #available > 0 then available else nil
end

-- The ballot advertises the target this roster would actually play to, not the
-- authored reference value. Projected rather than authoritative: the roster can
-- still move before the match starts, and MatchService resolves it again at the
-- boundary that counts.
local function projectedScoreTargets(options: { string }): { [string]: number }
	local playerCount = #playablePlayers()
	local targets = {}
	for _, modeId in options do
		local candidate = ModeRegistry.get(modeId)
		if candidate then
			local target = ScoreTarget.resolve(candidate.resolveRules(), playerCount)
			if target ~= math.huge then
				targets[modeId] = target
			end
		end
	end
	return targets
end

local function publish()
	local activeVote = vote
	local options = if activeVote then table.clone(activeVote.options) else configuredOptions() or {}
	local counts = if activeVote then ModeVote.counts(activeVote) else {}
	for _, modeId in options do
		counts[modeId] = counts[modeId] or 0
	end

	local mapOptions = if mapVote then table.clone(mapVote.options) else ArenaMapService.availableMaps()
	local mapCounts = if mapVote then ModeVote.counts(mapVote) else {}
	for _, mapId in mapOptions do
		mapCounts[mapId] = mapCounts[mapId] or 0
	end

	revision += 1
	ensureSnapshotValue().Value = HttpService:JSONEncode({
		schemaVersion = SNAPSHOT_SCHEMA_VERSION,
		open = activeVote ~= nil,
		startsAt = voteStartsAt,
		endsAt = voteEndsAt,
		durationSeconds = GameModes.VoteDurationSeconds,
		options = options,
		voteCounts = counts,
		scoreTargets = projectedScoreTargets(options),
		winnerModeId = winnerModeId,
		mapOptions = mapOptions,
		mapVoteCounts = mapCounts,
		winnerMapId = winnerMapId,
		currentMapId = ArenaMapService.currentMapId(),
		revision = revision,
	})
end

local function cancelVote()
	deadlineRevision += 1
	vote = nil
	mapVote = nil
	voteStartsAt = 0
	voteEndsAt = 0
	voteMaximumEndsAt = 0
	pendingWinner = nil
	winnerModeId = ""
	winnerMapId = ""
	for _, player in admittedPlayers() do
		player:SetAttribute(SELECTION_ATTRIBUTE, nil)
		player:SetAttribute(MAP_SELECTION_ATTRIBUTE, nil)
	end
	publish()
end

-- When no mode can run for the players still here (everyone else failed to load
-- or left), nothing will ever open a ballot and the loading overlay never
-- clears. After a short grace for a late arrival, send them back to the lobby
-- rather than leave them waiting on a match that cannot start.
local function loadingAdmittedCount(): number
	local count = 0
	for _, player in admittedPlayers() do
		if not ArenaSessionService.isReady(player) then
			count += 1
		end
	end
	return count
end

local function returnStrandedPlayers()
	if strandedReturnPending then
		return
	end
	strandedReturnPending = true
	local now = os.clock()
	local since = strandedSince or now
	strandedSince = since
	task.delay(GameModes.OpponentGraceSeconds, function()
		strandedReturnPending = false
		local phase = MatchService.phase()
		if vote ~= nil or pendingWinner ~= nil or (phase ~= "Idle" and phase ~= "Intermission") then
			strandedSince = nil
			return
		end
		if configuredOptions() ~= nil then
			strandedSince = nil
			beginVote()
			return
		end
		-- An admitted player who is still loading may yet make this a playable
		-- match; wait for them, bounded by the readiness deadline so a client
		-- that never readies cannot hold the others forever.
		if ModeVote.strandedAction(loadingAdmittedCount(), os.clock() - since, Loading.ArenaWaitSeconds) == "rearm" then
			returnStrandedPlayers()
			return
		end
		strandedSince = nil
		for _, player in playablePlayers() do
			ArenaReturnService.returnPlayer(player)
		end
	end)
end

local function startWinner()
	local winner = pendingWinner
	if winner == nil or MatchService.phase() ~= "Idle" then
		return
	end
	-- A map swap just resolved: every start path waits out the settle window,
	-- rescheduling once; the match always starts after it.
	local settleRemaining = settleUntil - os.clock()
	if settleRemaining > 0 then
		if not settleRescheduled then
			settleRescheduled = true
			task.delay(settleRemaining, function()
				settleRescheduled = false
				startWinner()
			end)
		end
		return
	end
	local accepted, reason = MatchService.beginMode(winner)
	if accepted then
		pendingWinner = nil
		return
	end
	if reason == "not_enough_players" then
		-- A fixed mode has no ballot to reopen; the pending winner simply waits
		-- for the roster, and the next ready or eligibility change retries.
		if ArenaSessionService.fixedModeId() then
			return
		end
		cancelVote()
		task.defer(beginVote)
		return
	end

	warn(`[ModeVoteService] Could not start mode "{winner}": {reason or "unknown"}`)
	if reason ~= "not_enough_players" and reason ~= "match_not_idle" then
		pendingWinner = nil
		task.defer(beginVote)
	end
end

local function finishVote(expectedRevision: number)
	if expectedRevision ~= deadlineRevision or vote == nil then
		return
	end
	local remaining = voteEndsAt - Workspace:GetServerTimeNow()
	if remaining > 0 then
		task.delay(remaining, function()
			finishVote(expectedRevision)
		end)
		return
	end

	local voters = playablePlayers()
	if #voters == 0 then
		cancelVote()
		return
	end

	local activeVote = assert(vote, "finishVote requires an active vote")
	local available = configuredOptions()
	if available == nil then
		cancelVote()
		returnStrandedPlayers()
		return
	end
	local eligibleOptions = {}
	for _, option in activeVote.options do
		if table.find(available, option) then
			table.insert(eligibleOptions, option)
		end
	end
	if #eligibleOptions == 0 then
		cancelVote()
		task.defer(beginVote)
		return
	end
	local eligibleVote = ModeVote.new(eligibleOptions)
	for userId, choice in activeVote.votesByUserId do
		ModeVote.cast(eligibleVote, userId, choice)
	end
	local winner = ModeVote.choose(eligibleVote, function(count)
		return random:NextInteger(1, count)
	end)
	winnerModeId = winner

	-- The map ballot resolves with the mode ballot. A failed or refused swap leaves
	-- the live map in place and the match starts on schedule regardless.
	local mapChanged = false
	local activeMapVote = mapVote
	if activeMapVote then
		local mapsNow = ArenaMapService.availableMaps()
		local eligibleMaps = {}
		for _, option in activeMapVote.options do
			if table.find(mapsNow, option) then
				table.insert(eligibleMaps, option)
			end
		end
		if #eligibleMaps > 0 then
			local eligibleMapVote = ModeVote.new(eligibleMaps)
			for userId, choice in activeMapVote.votesByUserId do
				ModeVote.cast(eligibleMapVote, userId, choice)
			end
			local winningMap = ModeVote.choose(eligibleMapVote, function(count)
				return random:NextInteger(1, count)
			end)
			local before = ArenaMapService.currentMapId()
			local called, swapped, swapReason = pcall(ArenaMapService.activate, winningMap)
			if not called or not swapped then
				warn(
					`[ModeVoteService] map "{winningMap}" not activated: {if called
						then swapReason or "unknown"
						else swapped}`
				)
			end
			mapChanged = ArenaMapService.currentMapId() ~= before
		end
	end
	winnerMapId = ArenaMapService.currentMapId()

	local counts = ModeVote.counts(activeVote)
	for _, player in voters do
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.ModeVoteResolved, 1, {
			modeId = winner,
			votedFor = player:GetAttribute(SELECTION_ATTRIBUTE),
			winnerVotes = counts[winner],
			voterCount = #voters,
		})
	end
	vote = nil
	mapVote = nil
	voteStartsAt = 0
	voteEndsAt = 0
	voteMaximumEndsAt = 0
	pendingWinner = winner
	publish()
	if MatchService.phase() == "Idle" then
		-- A fresh server resolves its first ballot in Idle and would start the
		-- match this frame; give a newly swapped map a moment to stream in.
		if mapChanged then
			settleUntil = os.clock() + ArenaMaps.SwapSettleSeconds
			startWinner()
		else
			startWinner()
		end
	end
end

beginVote = function()
	local phase = MatchService.phase()
	if
		vote ~= nil
		or pendingWinner ~= nil
		or not ArenaSessionService.canOpenVote()
		or (phase ~= "Idle" and phase ~= "Intermission")
		or #playablePlayers() == 0
	then
		return
	end
	local options = configuredOptions()
	if options == nil then
		returnStrandedPlayers()
		return
	end

	-- A fixed-mode session (Splashdown) never opens a ballot: its mode becomes
	-- the pending winner and starts the way a decided vote would, with the
	-- snapshot publishing the winner and open = false.
	local fixed = ArenaSessionService.fixedModeId()
	if fixed then
		if not table.find(options, fixed) then
			return
		end
		pendingWinner = fixed
		winnerModeId = fixed
		publish()
		startWinner()
		return
	end

	vote = ModeVote.new(options)
	deadlineRevision += 1
	local currentDeadlineRevision = deadlineRevision
	local now = Workspace:GetServerTimeNow()
	voteStartsAt = now
	voteEndsAt = now + GameModes.VoteDurationSeconds
	voteMaximumEndsAt = voteEndsAt + MAXIMUM_VOTE_EXTENSION_SECONDS
	winnerModeId = ""
	winnerMapId = ""
	local maps = ArenaMapService.availableMaps()
	mapVote = if #maps >= 2 then ModeVote.new(maps) else nil
	for _, player in admittedPlayers() do
		player:SetAttribute(SELECTION_ATTRIBUTE, nil)
		player:SetAttribute(MAP_SELECTION_ATTRIBUTE, nil)
	end
	publish()

	task.delay(GameModes.VoteDurationSeconds, function()
		finishVote(currentDeadlineRevision)
	end)
end

local function extendForLateReady()
	if vote == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now >= voteEndsAt then
		finishVote(deadlineRevision)
		return
	end
	local extendedEndsAt = ModeVote.extendForLateReady(voteEndsAt, voteMaximumEndsAt, now, LATE_READY_MINIMUM_SECONDS)
	if extendedEndsAt > voteEndsAt then
		voteEndsAt = extendedEndsAt
		publish()
	end
end

-- Nobody left to hear from, so the ballot closes instead of running out its
-- clock. Everyone has already picked; the remaining seconds are dead air between
-- two rounds that the whole server sits through.
local function finishIfEveryoneVoted()
	local activeVote = vote
	if activeVote == nil then
		return
	end
	local userIds = {}
	for _, player in playablePlayers() do
		table.insert(userIds, player.UserId)
	end
	if not ModeVote.allVoted(activeVote, userIds) or (mapVote and not ModeVote.allVoted(mapVote, userIds)) then
		return
	end
	voteEndsAt = Workspace:GetServerTimeNow()
	publish()
	finishVote(deadlineRevision)
end

local function submitVote(player: Player, modeId: string)
	local activeVote = vote
	if activeVote == nil or not ArenaSessionService.isRoundEligible(player) then
		return
	end
	if Workspace:GetServerTimeNow() >= voteEndsAt then
		finishVote(deadlineRevision)
		return
	end
	if not ModeVote.cast(activeVote, player.UserId, modeId) then
		return
	end
	player:SetAttribute(SELECTION_ATTRIBUTE, modeId)
	publish()
	AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.ModeVoteCast, 1, { modeId = modeId })
	finishIfEveryoneVoted()
end

local function submitMapVote(player: Player, mapId: string)
	local activeVote = mapVote
	if vote == nil or activeVote == nil or not ArenaSessionService.isRoundEligible(player) then
		return
	end
	if Workspace:GetServerTimeNow() >= voteEndsAt then
		finishVote(deadlineRevision)
		return
	end
	if not ModeVote.cast(activeVote, player.UserId, mapId) then
		return
	end
	player:SetAttribute(MAP_SELECTION_ATTRIBUTE, mapId)
	publish()
	finishIfEveryoneVoted()
end

function ModeVoteService.start()
	if started then
		return
	end
	started = true
	ensureSnapshotValue()
	publish()

	Network.handleProtected("SubmitModeVote", {
		rateLimit = 6,
		validate = function(_player, modeId)
			return typeof(modeId) == "string" and #modeId > 0 and #modeId <= 32, "invalid_mode_id"
		end,
	}, submitVote)

	Network.handleProtected("SubmitMapVote", {
		rateLimit = 6,
		validate = function(_player, mapId)
			return typeof(mapId) == "string" and #mapId > 0 and #mapId <= 32, "invalid_map_id"
		end,
	}, submitMapVote)

	ArenaSessionService.onGateReleased(function()
		task.defer(beginVote)
	end)
	ArenaSessionService.onReady(function()
		if vote then
			extendForLateReady()
		elseif pendingWinner then
			startWinner()
		else
			task.defer(beginVote)
		end
	end)
	ArenaSessionService.onRoundEligibilityChanged(function(player, eligible)
		local activeVote = vote
		if activeVote and not eligible then
			local removedMode = ModeVote.remove(activeVote, player.UserId)
			local removedMap = mapVote ~= nil and ModeVote.remove(mapVote, player.UserId)
			if removedMode or removedMap then
				player:SetAttribute(SELECTION_ATTRIBUTE, nil)
				player:SetAttribute(MAP_SELECTION_ATTRIBUTE, nil)
				publish()
			end
		end
		if eligible then
			if activeVote then
				extendForLateReady()
			else
				task.defer(beginVote)
			end
		elseif #playablePlayers() == 0 and (activeVote ~= nil or pendingWinner ~= nil) then
			cancelVote()
		else
			-- The player who left the round may have been the last one the ballot
			-- was still waiting on.
			finishIfEveryoneVoted()
		end
	end)
	Players.PlayerAdded:Connect(function()
		task.defer(function()
			publish()
			if pendingWinner then
				startWinner()
			else
				beginVote()
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local activeVote = vote
		if activeVote then
			local removedMode = ModeVote.remove(activeVote, player.UserId)
			local removedMap = mapVote ~= nil and ModeVote.remove(mapVote, player.UserId)
			if removedMode or removedMap then
				publish()
			end
		end
		task.defer(function()
			if #playablePlayers() == 0 and (vote == activeVote or pendingWinner ~= nil) then
				cancelVote()
			else
				finishIfEveryoneVoted()
			end
		end)
	end)
	MatchService.onEvent(function(event)
		if event.kind == "MatchReset" then
			task.defer(beginVote)
		elseif event.kind == "IntermissionEnded" then
			task.defer(function()
				if vote then
					finishVote(deadlineRevision)
				elseif pendingWinner then
					startWinner()
				else
					beginVote()
				end
			end)
		end
	end)
	task.defer(beginVote)
end

return ModeVoteService
