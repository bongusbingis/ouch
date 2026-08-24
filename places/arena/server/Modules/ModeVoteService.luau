--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("GameModes"))
local Loading = require(Config:WaitForChild("Loading"))
local Game = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local ModeOptions = require(Game:WaitForChild("Modes"):WaitForChild("ModeOptions"))
local ModeVote = require(Game:WaitForChild("Modes"):WaitForChild("ModeVote"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local AnalyticsConfig = require(Config:WaitForChild("Analytics"))
local AnalyticsService = require(script.Parent.AnalyticsService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local MatchService = require(script.Parent.MatchService)

local ModeVoteService = {}

local STATE_FOLDER_NAME = "ModeVoteState"
local SNAPSHOT_VALUE_NAME = "Snapshot"
local SNAPSHOT_SCHEMA_VERSION = 1
local SELECTION_ATTRIBUTE = "ModeVoteSelection"
local LATE_READY_MINIMUM_SECONDS = Loading.LateVoteMinimumSeconds
local MAXIMUM_VOTE_EXTENSION_SECONDS = Loading.LateVoteMaximumExtensionSeconds

local snapshotValue: StringValue? = nil
local vote: ModeVote.State? = nil
local voteStartsAt = 0
local voteEndsAt = 0
local voteMaximumEndsAt = 0
local pendingWinner: string? = nil
local winnerModeId = ""
local revision = 0
local deadlineRevision = 0
local started = false
local random = Random.new()
local beginVote: () -> ()

local function playablePlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if ArenaSessionService.isPlayable(player) then
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
	local available = ModeOptions.resolve(ArenaSessionService.modeOptions())
	return if #available > 0 then available else nil
end

local function publish()
	local activeVote = vote
	local options = if activeVote then table.clone(activeVote.options) else configuredOptions() or {}
	local counts = if activeVote then ModeVote.counts(activeVote) else {}
	for _, modeId in options do
		counts[modeId] = counts[modeId] or 0
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
		winnerModeId = winnerModeId,
		revision = revision,
	})
end

local function cancelVote()
	deadlineRevision += 1
	vote = nil
	voteStartsAt = 0
	voteEndsAt = 0
	voteMaximumEndsAt = 0
	pendingWinner = nil
	winnerModeId = ""
	for _, player in admittedPlayers() do
		player:SetAttribute(SELECTION_ATTRIBUTE, nil)
	end
	publish()
end

local function startWinner()
	local winner = pendingWinner
	if winner == nil or MatchService.phase() ~= "Idle" then
		return
	end
	local accepted, reason = MatchService.beginMode(winner)
	if accepted then
		pendingWinner = nil
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
	local winner = ModeVote.choose(activeVote, function(count)
		return random:NextInteger(1, count)
	end)
	winnerModeId = winner

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
	voteStartsAt = 0
	voteEndsAt = 0
	voteMaximumEndsAt = 0
	pendingWinner = winner
	publish()
	if MatchService.phase() == "Idle" then
		startWinner()
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
	for _, player in admittedPlayers() do
		player:SetAttribute(SELECTION_ATTRIBUTE, nil)
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

local function submitVote(player: Player, modeId: string)
	local activeVote = vote
	if activeVote == nil or not ArenaSessionService.isPlayable(player) then
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
		if activeVote and ModeVote.remove(activeVote, player.UserId) then
			publish()
		end
		task.defer(function()
			if #playablePlayers() == 0 and (vote == activeVote or pendingWinner ~= nil) then
				cancelVote()
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
