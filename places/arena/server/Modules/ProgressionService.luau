-- Name: ProgressionService.luau
-- Author: Jack C.
-- Description: Accumulates per-match progress from deduplicated match and combat events (eliminations, deaths, catches, wins) and commits the resulting XP, Bonks, and stat deltas to each player's profile.
-- Created: 2026-07-13

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Data"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local AnalyticsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Analytics"))
local Boosts = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("Boosts")
)
local PlayerData = require(script.Parent.PlayerData)
local AnalyticsService = require(script.Parent.AnalyticsService)
local EntitlementService = require(script.Parent.EntitlementService)
local BattlePassService = require(script.Parent.BattlePassService)

type MatchEvent = { [string]: any }

type MatchProgress = {
	Elims: number,
	Deaths: number,
	Catches: number,
	Wins: number,
	Losses: number,
	MatchesPlayed: number,
	XP: number,
	Bonks: number,
}

type PendingCommit = {
	resultId: string,
	userId: number,
	progress: MatchProgress,
	won: boolean,
	firstMatch: boolean?,
	committing: boolean,
	applied: boolean,
}

export type MatchSummary = {
	firstMatch: boolean?,
	rewardsPending: boolean?,
	won: boolean,
	elims: number,
	deaths: number,
	catches: number,
	baseXp: number?,
	baseBonks: number?,
	xpMultiplier: number?,
	bonksMultiplier: number?,
	xp: number?,
	bonks: number?,
	seasonXp: number?,
	seasonBefore: { [string]: any }?,
	seasonAfter: { [string]: any }?,
}

local ProgressionService = {}

local progressByPlayerId: { [string]: MatchProgress } = {}
local summaryByPlayerId: { [string]: MatchSummary } = {}
local pendingByUserId: { [number]: { [string]: PendingCommit } } = {}
local summaryListeners: { (Player, MatchSummary, string) -> () } = {}
local seenEvents = EventDedup.new()
local started = false
local activeEntitlementService: any = EntitlementService
local activeBattlePassService: any = BattlePassService
local activeMatchService: any = nil
local currentResultId: string? = nil

local function blank(): MatchProgress
	return {
		Elims = 0,
		Deaths = 0,
		Catches = 0,
		Wins = 0,
		Losses = 0,
		MatchesPlayed = 0,
		XP = 0,
		Bonks = 0,
	}
end

local function progressFor(id: string): MatchProgress
	local progress = progressByPlayerId[id]
	if progress == nil then
		progress = blank()
		progressByPlayerId[id] = progress
	end
	return progress
end

local function resetMatch()
	table.clear(progressByPlayerId)
	table.clear(summaryByPlayerId)
	currentResultId = nil
	seenEvents.clear()
end

local function addRewards(progress: MatchProgress, rewardKey: string)
	progress.XP += DataConfig.ProgressionXP[rewardKey] or 0
	progress.Bonks += DataConfig.ProgressionBonks[rewardKey] or 0
end

local function trackElim(event: MatchEvent)
	if not seenEvents.markSeen(event) then
		return
	end

	local sourceId = event.sourceId :: string?
	local targetId = event.targetId :: string?
	if sourceId == nil or targetId == nil or sourceId == targetId then
		return
	end

	local source = progressFor(sourceId)
	source.Elims += 1
	addRewards(source, "Elim")

	local target = progressFor(targetId)
	target.Deaths += 1
end

local function trackCatch(event: MatchEvent)
	if not seenEvents.markSeen(event) then
		return
	end

	local catcherId = (event.playerId or event.sourceId) :: string?
	if catcherId == nil then
		return
	end

	local progress = progressFor(catcherId)
	progress.Catches += 1
	addRewards(progress, "Catch")
end

local function publishSummary(player: Player, summary: MatchSummary, resultId: string)
	if currentResultId ~= resultId then
		return
	end
	summaryByPlayerId[PlayerIds.toId(player)] = summary
	if player.Parent ~= Players then
		return
	end
	Network.fire("MatchSummary", player, summary)
	for _, listener in table.clone(summaryListeners) do
		local ok, err = pcall(listener, player, summary, resultId)
		if not ok then
			warn(`[ProgressionService] summary listener failed: {err}`)
		end
	end
end

local function isPending(pending: PendingCommit): boolean
	local resultRecords = pendingByUserId[pending.userId]
	return resultRecords ~= nil and resultRecords[pending.resultId] == pending
end

local function clearPending(pending: PendingCommit)
	local resultRecords = pendingByUserId[pending.userId]
	if resultRecords == nil or resultRecords[pending.resultId] ~= pending then
		return
	end
	resultRecords[pending.resultId] = nil
	if next(resultRecords) == nil then
		pendingByUserId[pending.userId] = nil
	end
end

local function commitPlayer(player: Player, pending: PendingCommit): boolean
	activeEntitlementService.awaitReady(player, 2)
	if not isPending(pending) or PlayerData.get(player) == nil then
		return false
	end

	local progress = pending.progress
	local firstMatch = pending.firstMatch
	if firstMatch == nil then
		local data = PlayerData.get(player)
		firstMatch = data ~= nil and (data.Progression.MatchesPlayed or 0) == 0
		pending.firstMatch = firstMatch
	end
	local multipliers = activeEntitlementService.multipliers(player)
	local awarded = {
		Elims = progress.Elims,
		Deaths = progress.Deaths,
		Catches = progress.Catches,
		Wins = progress.Wins,
		Losses = progress.Losses,
		MatchesPlayed = progress.MatchesPlayed,
		XP = Boosts.apply(progress.XP, multipliers.Xp),
		Bonks = Boosts.apply(progress.Bonks, multipliers.Bonks),
	}

	local seasonBefore = activeBattlePassService.stateFor(player)
	if not PlayerData.applyProgression(player, awarded) then
		return false
	end
	pending.applied = true
	activeBattlePassService.addSeasonXp(player, awarded.XP)
	local seasonAfter = activeBattlePassService.stateFor(player)
	PlayerData.completeTutorial(player)
	if awarded.Bonks > 0 then
		local data = PlayerData.get(player)
		local ok, err = pcall(
			AnalyticsService.logEconomyEvent,
			player,
			"Source",
			"Bonks",
			awarded.Bonks,
			if data then data.Bonks else 0,
			AnalyticsConfig.EconomyTransactionTypes.Gameplay,
			"MatchRewards"
		)
		if not ok then
			warn(`[ProgressionService] reward analytics failed: {err}`)
		end
	end
	local summary = {
		firstMatch = firstMatch,
		rewardsPending = false,
		won = pending.won,
		elims = progress.Elims,
		deaths = progress.Deaths,
		catches = progress.Catches,
		baseXp = progress.XP,
		baseBonks = progress.Bonks,
		xpMultiplier = multipliers.Xp,
		bonksMultiplier = multipliers.Bonks,
		xp = awarded.XP,
		bonks = awarded.Bonks,
		seasonXp = if seasonBefore and seasonAfter
			then math.max((seasonAfter.xp or 0) - (seasonBefore.xp or 0), 0)
			else nil,
		seasonBefore = seasonBefore,
		seasonAfter = seasonAfter,
	}
	clearPending(pending)
	publishSummary(player, summary, pending.resultId)
	return true
end

local function startCommit(player: Player, pending: PendingCommit)
	if pending.committing or not isPending(pending) or not PlayerData.isLoaded(player) then
		return
	end
	local releaseLease = PlayerData.acquireWriteLease(player)
	if releaseLease == nil then
		return
	end
	pending.committing = true
	task.spawn(function()
		local ok, committed = xpcall(function()
			return commitPlayer(player, pending)
		end, debug.traceback)
		releaseLease()
		if not ok then
			warn(`[ProgressionService] reward commit failed for user {pending.userId}: {committed}`)
			if pending.applied then
				clearPending(pending)
			end
		end
		if isPending(pending) then
			pending.committing = false
		end
	end)
end

local function commitMatch(_event: MatchEvent)
	local result = activeMatchService and activeMatchService.resultSnapshot()
	if result == nil then
		warn("[ProgressionService] MatchEnded without an authoritative result")
		return
	end
	local resultId = result.resultId
	if currentResultId == resultId then
		return
	end
	currentResultId = resultId
	table.clear(summaryByPlayerId)
	local winnerId = result.winnerId :: string?
	for _, contestant in result.contestants do
		local id = contestant.playerId
		local playerWon = winnerId ~= nil and winnerId ~= "" and (id == winnerId or contestant.teamId == winnerId)

		local committedProgress = table.clone(progressByPlayerId[id] or blank())
		committedProgress.MatchesPlayed += 1
		addRewards(committedProgress, "MatchComplete")

		if winnerId ~= nil and winnerId ~= "" then
			if playerWon then
				committedProgress.Wins += 1
				addRewards(committedProgress, "Win")
			else
				committedProgress.Losses += 1
			end
		end

		local player = Players:GetPlayerByUserId(contestant.userId)
		local beforeData = if player then PlayerData.get(player) else nil
		local firstMatch = if beforeData then (beforeData.Progression.MatchesPlayed or 0) == 0 else nil
		local pending = {
			resultId = resultId,
			userId = contestant.userId,
			progress = committedProgress,
			won = playerWon,
			firstMatch = firstMatch,
			committing = false,
			applied = false,
		}
		local resultRecords = pendingByUserId[contestant.userId]
		if resultRecords == nil then
			resultRecords = {}
			pendingByUserId[contestant.userId] = resultRecords
		end
		resultRecords[resultId] = pending
		summaryByPlayerId[id] = {
			firstMatch = firstMatch,
			rewardsPending = true,
			won = playerWon,
			elims = committedProgress.Elims,
			deaths = committedProgress.Deaths,
			catches = committedProgress.Catches,
		}
		if player then
			startCommit(player, pending)
		end
	end
end

function ProgressionService.awaitCommitted(players: { Player }, resultId: string, timeoutSeconds: number): boolean
	local deadline = os.clock() + math.max(timeoutSeconds, 0)
	repeat
		local waiting = false
		for _, player in players do
			if player.Parent == Players then
				local resultRecords = pendingByUserId[player.UserId]
				local pending = if resultRecords then resultRecords[resultId] else nil
				if pending then
					waiting = true
					startCommit(player, pending)
				end
			end
		end
		if not waiting then
			return true
		end
		if os.clock() >= deadline then
			return false
		end
		task.wait(0.05)
	until false
end

function ProgressionService.summaryFor(player: Player, resultId: string?): MatchSummary?
	if resultId ~= nil and resultId ~= currentResultId then
		return nil
	end
	return summaryByPlayerId[PlayerIds.toId(player)]
end

function ProgressionService.onSummary(listener: (Player, MatchSummary, string) -> ()): () -> ()
	table.insert(summaryListeners, listener)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(summaryListeners, listener)
		if index then
			table.remove(summaryListeners, index)
		end
	end
end

local function handleEvent(event: MatchEvent)
	if event.kind == "MatchStarted" then
		resetMatch()
	elseif event.kind == "Elim" then
		trackElim(event)
	elseif event.kind == "BallCaught" then
		trackCatch(event)
	elseif event.kind == "MatchEnded" then
		commitMatch(event)
	end
end

function ProgressionService.start(matchService: any, options: { entitlementService: any?, battlePassService: any? }?)
	if started then
		return
	end
	started = true
	activeEntitlementService = if options and options.entitlementService
		then options.entitlementService
		else EntitlementService
	activeBattlePassService = if options and options.battlePassService
		then options.battlePassService
		else BattlePassService
	activeMatchService = matchService
	resetMatch()
	matchService.onEvent(handleEvent)
	PlayerData.onLoaded(function(player)
		local resultRecords = pendingByUserId[player.UserId]
		if resultRecords then
			for _, pending in resultRecords do
				startCommit(player, pending)
			end
		end
	end)
end

return ProgressionService
