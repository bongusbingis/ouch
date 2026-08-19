--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local GameModes = require(Config:WaitForChild("GameModes"))
local Game = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local ModeRegistry = require(Game:WaitForChild("Modes"):WaitForChild("ModeRegistry"))
local ModeVote = require(Game:WaitForChild("Modes"):WaitForChild("ModeVote"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local AnalyticsConfig = require(Config:WaitForChild("Analytics"))
local AnalyticsService = require(script.Parent.AnalyticsService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local MatchService = require(script.Parent.MatchService)

local ModeVoteService = {}

local STATE_FOLDER_NAME = "ModeVoteState"
local SELECTION_ATTRIBUTE = "ModeVoteSelection"

local stateFolder: Folder? = nil
local vote: ModeVote.State? = nil
local voteEndsAt = 0
local pendingWinner: string? = nil
local revision = 0
local deadlineRevision = 0
local started = false
local random = Random.new()
local readyWaitScheduled = false
local readyWaitExpired = false
local beginVote: () -> ()

local function admittedPlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if ArenaSessionService.isAdmitted(player) then
			table.insert(result, player)
		end
	end
	return result
end

local function allAdmittedReady(): boolean
	for _, player in admittedPlayers() do
		if not ArenaSessionService.isReady(player) then
			return false
		end
	end
	return true
end

-- Holds the ballot until arriving clients report their UI ready, so it is not
-- spent before anyone can see it. The wait is capped and armed at most once per
-- ballot, so a client that never reports delays the match by that cap and no
-- more.
local function readyToOpen(): boolean
	if readyWaitExpired or allAdmittedReady() then
		return true
	end
	if not readyWaitScheduled then
		readyWaitScheduled = true
		task.delay(GameModes.ClientReadyWaitSeconds, function()
			readyWaitExpired = true
			beginVote()
		end)
	end
	return false
end

local function ensureStateFolder(): Folder
	if stateFolder then
		return stateFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = STATE_FOLDER_NAME
	folder:SetAttribute("open", false)
	folder:SetAttribute("startsAt", 0)
	folder:SetAttribute("endsAt", 0)
	folder:SetAttribute("durationSeconds", GameModes.VoteDurationSeconds)
	folder:SetAttribute("optionCount", 0)
	folder:SetAttribute("winnerModeId", "")
	folder:SetAttribute("revision", revision)
	folder.Parent = ReplicatedStorage
	stateFolder = folder
	return folder
end

local function publish()
	local folder = ensureStateFolder()
	local activeVote = vote
	local counts = if activeVote then ModeVote.counts(activeVote) else {}
	local optionCount = if activeVote then #activeVote.options else 0
	local previousCount = (folder:GetAttribute("optionCount") :: number?) or 0
	for index = 1, math.max(optionCount, previousCount) do
		local modeId = if activeVote then activeVote.options[index] else nil
		folder:SetAttribute(`Option{index}Id`, modeId)
		folder:SetAttribute(`Option{index}Count`, if modeId then counts[modeId] or 0 else nil)
	end
	folder:SetAttribute("optionCount", optionCount)
	revision += 1
	folder:SetAttribute("revision", revision)
end

local function configuredOptions(): { string }?
	local session = ArenaSessionService.getSnapshot()
	local options = if session then session.modeOptions else GameModes.VoteOptions
	local available = {}
	for _, modeId in options do
		local definition = GameModes.Modes[modeId]
		if definition == nil or not definition.Enabled or ModeRegistry.get(modeId) == nil then
			warn(`[ModeVoteService] Ignored unavailable matchmaking mode "{modeId}"`)
		else
			table.insert(available, modeId)
		end
	end
	return if #available > 0 then available else nil
end

local function cancelVote()
	deadlineRevision += 1
	vote = nil
	voteEndsAt = 0
	pendingWinner = nil
	local folder = ensureStateFolder()
	folder:SetAttribute("open", false)
	folder:SetAttribute("startsAt", 0)
	folder:SetAttribute("endsAt", 0)
	folder:SetAttribute("winnerModeId", "")
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

-- force skips the remaining-time reschedule, for the case where every loaded
-- player has already voted and there is nothing left to wait for.
local function finishVote(expectedRevision: number, force: boolean?)
	if expectedRevision ~= deadlineRevision or vote == nil then
		return
	end
	if not force then
		local remaining = voteEndsAt - Workspace:GetServerTimeNow()
		if remaining > 0 then
			task.delay(remaining, function()
				finishVote(expectedRevision)
			end)
			return
		end
	end
	if #admittedPlayers() == 0 then
		cancelVote()
		return
	end

	local winner = ModeVote.choose(vote, function(count)
		return random:NextInteger(1, count)
	end)
	local folder = ensureStateFolder()
	folder:SetAttribute("open", false)
	folder:SetAttribute("winnerModeId", winner)
	publish()

	-- Logged per voter with their own pick alongside the outcome, so mode
	-- popularity can be read separately from what actually got played.
	local counts = ModeVote.counts(vote)
	for _, player in admittedPlayers() do
		AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.ModeVoteResolved, 1, {
			modeId = winner,
			votedFor = player:GetAttribute(SELECTION_ATTRIBUTE),
			winnerVotes = counts[winner],
			voterCount = #admittedPlayers(),
		})
	end
	vote = nil
	voteEndsAt = 0
	pendingWinner = winner
	if MatchService.phase() == "Idle" then
		startWinner()
	end
end

beginVote = function()
	local phase = MatchService.phase()
	if
		vote ~= nil
		or pendingWinner ~= nil
		or (phase ~= "Idle" and phase ~= "Intermission")
		or #admittedPlayers() == 0
	then
		return
	end
	local options = configuredOptions()
	if options == nil or #options == 0 then
		return
	end
	if not readyToOpen() then
		return
	end

	readyWaitScheduled = false
	readyWaitExpired = false
	vote = ModeVote.new(options)
	deadlineRevision += 1
	local currentDeadlineRevision = deadlineRevision
	local now = Workspace:GetServerTimeNow()
	voteEndsAt = now + GameModes.VoteDurationSeconds
	local folder = ensureStateFolder()
	folder:SetAttribute("startsAt", now)
	folder:SetAttribute("endsAt", voteEndsAt)
	folder:SetAttribute("durationSeconds", GameModes.VoteDurationSeconds)
	folder:SetAttribute("winnerModeId", "")
	folder:SetAttribute("open", true)
	for _, player in admittedPlayers() do
		player:SetAttribute(SELECTION_ATTRIBUTE, nil)
	end
	publish()

	task.delay(GameModes.VoteDurationSeconds, function()
		finishVote(currentDeadlineRevision)
	end)
end

-- Only players whose client is loaded are expected to vote: an admitted player
-- who never reported ready cannot see the ballot, so waiting on them would hold
-- it open for its full duration for no reason.
local function loadedUserIds(): { number }
	local userIds = {}
	for _, player in admittedPlayers() do
		if ArenaSessionService.isReady(player) then
			table.insert(userIds, player.UserId)
		end
	end
	return userIds
end

local function closeIfEveryoneVoted()
	local activeVote = vote
	if activeVote ~= nil and ModeVote.allVoted(activeVote, loadedUserIds()) then
		finishVote(deadlineRevision, true)
	end
end

local function submitVote(player: Player, modeId: string)
	local activeVote = vote
	if activeVote == nil or not ArenaSessionService.isAdmitted(player) then
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
	closeIfEveryoneVoted()
end

function ModeVoteService.start()
	if started then
		return
	end
	started = true
	ensureStateFolder()

	Network.handleProtected("SubmitModeVote", {
		rateLimit = 6,
		validate = function(_player, modeId)
			return typeof(modeId) == "string" and #modeId > 0 and #modeId <= 32, "invalid_mode_id"
		end,
	}, submitVote)

	ArenaSessionService.onReady(function()
		task.defer(beginVote)
	end)
	Players.PlayerAdded:Connect(function()
		task.defer(function()
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
		closeIfEveryoneVoted()
		task.defer(function()
			if #admittedPlayers() == 0 and (vote == activeVote or pendingWinner ~= nil) then
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
