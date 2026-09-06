-- Records earned match progress in PlayerData's journal and presents committed match summaries.
--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataConfig = require(ReplicatedStorage.Config.Progression.Data)
local AnalyticsConfig = require(ReplicatedStorage.Config.Infra.Analytics)
local PlayerIds = require(ReplicatedStorage.Shared.Game.Adapters.PlayerIds)
local EventDedup = require(ReplicatedStorage.Shared.Game.Adapters.EventDedup)
local Network = require(ReplicatedStorage.Shared.Network)
local PlayerData = require(script.Parent.PlayerData)
local MatchAwardService = require(script.Parent.MatchAwardService)
local BattlePassService = require(script.Parent.BattlePassService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)
local AnalyticsService = require(script.Parent.AnalyticsService)

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
local started = false
local awardId: string? = nil
local currentResultId: string? = nil
local summaryByPlayerId: { [string]: MatchSummary } = {}
local summaryListeners: { (Player, MatchSummary, string) -> () } = {}
local seenEvents = EventDedup.new()
local activeMatchService: any = nil

local function ensureRecord(player: Player): any
	if awardId == nil then
		return nil
	end
	local journal = PlayerData.matchAwards(player)
	if journal and journal.Pending[awardId] then
		return journal.Pending[awardId]
	end
	local season = BattlePassService.stateFor(player)
	local record = PlayerData.beginMatchAward(player, awardId, if season then season.seasonId else "")
	if record == nil then
		player:SetAttribute("RewardsRecoveryPending", true)
		ArenaSessionService.setRoundEligible(player, false)
	end
	return record
end

local function add(player: Player?, delta: any)
	if player == nil or awardId == nil or not ArenaSessionService.isRoundEligible(player) then
		return
	end
	if ensureRecord(player) then
		PlayerData.addMatchProgress(player, awardId, delta)
	end
end

local function rewards(key: string): any
	return { XP = DataConfig.ProgressionXP[key] or 0, Bonks = DataConfig.ProgressionBonks[key] or 0 }
end

local function publish(player: Player, summary: MatchSummary, resultId: string)
	if resultId ~= currentResultId then
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

local function committed(player: Player, record: any, before: any, after: any)
	local progress, awarded, multipliers = record.Progress, record.Awarded, record.Multipliers
	if awarded.Bonks > 0 then
		local data = PlayerData.get(player)
		pcall(
			AnalyticsService.logEconomyEvent,
			player,
			"Source",
			"Bonks",
			awarded.Bonks,
			if data then data.Bonks else 0,
			AnalyticsConfig.EconomyTransactionTypes.Gameplay,
			"MatchRewards"
		)
	end
	if record.ResultId == nil then
		return
	end
	publish(player, {
		firstMatch = record.FirstMatch,
		rewardsPending = false,
		won = record.Won == true,
		elims = progress.Elims,
		deaths = progress.Deaths,
		catches = progress.Catches,
		baseXp = progress.XP,
		baseBonks = progress.Bonks,
		xpMultiplier = multipliers.Xp,
		bonksMultiplier = multipliers.Bonks,
		xp = awarded.XP,
		bonks = awarded.Bonks,
		seasonXp = if before
				and after
				and before.seasonId == after.seasonId
			then math.max((after.xp or 0) - (before.xp or 0), 0)
			else nil,
		seasonBefore = before,
		seasonAfter = after,
	}, record.ResultId)
end

local function commitMatch()
	local result = activeMatchService.resultSnapshot()
	if result == nil or result.resultId == currentResultId or awardId == nil then
		return
	end
	currentResultId = result.resultId
	for _, contestant in result.contestants do
		local player = Players:GetPlayerByUserId(contestant.userId)
		if player == nil then
			continue
		end
		local record = ensureRecord(player)
		if record == nil or record.Ready then
			continue
		end
		local winner = result.winnerId
		local won = winner ~= nil and winner ~= "" and (contestant.playerId == winner or contestant.teamId == winner)
		local completed = result.reason ~= "NoContest"
		local delta = if completed then rewards("MatchComplete") else { XP = 0, Bonks = 0 }
		delta.MatchesPlayed = if completed then 1 else 0
		if winner ~= nil and winner ~= "" then
			if won then
				delta.Wins = 1
				delta.XP += DataConfig.ProgressionXP.Win
				delta.Bonks += DataConfig.ProgressionBonks.Win
			else
				delta.Losses = 1
			end
		end
		PlayerData.addMatchProgress(player, awardId, delta)
		PlayerData.finishMatchAward(player, awardId, result.resultId, won)
		publish(player, {
			rewardsPending = true,
			won = won,
			elims = record.Progress.Elims,
			deaths = record.Progress.Deaths,
			catches = record.Progress.Catches,
		}, result.resultId)
		MatchAwardService.flush(player)
	end
	awardId = nil
end

local function handleEvent(event: any)
	if event.kind == "MatchStarted" then
		awardId = HttpService:GenerateGUID(false)
		currentResultId = nil
		table.clear(summaryByPlayerId)
		seenEvents.clear()
		for _, player in Players:GetPlayers() do
			if ArenaSessionService.isRoundEligible(player) then
				ensureRecord(player)
			end
		end
	elseif event.kind == "Elim" and seenEvents.markSeen(event) then
		local source = PlayerIds.fromId(event.sourceId)
		local target = PlayerIds.fromId(event.targetId)
		if source and source ~= target then
			local delta = rewards("Elim")
			delta.Elims = 1
			add(source, delta)
		end
		add(target, { Deaths = 1 })
	elseif event.kind == "BallCaught" and seenEvents.markSeen(event) then
		local delta = rewards("Catch")
		delta.Catches = 1
		add(PlayerIds.fromEvent(event), delta)
	elseif event.kind == "MatchEnded" then
		commitMatch()
	end
end

function ProgressionService.awaitCommitted(players: { Player }, resultId: string, timeoutSeconds: number): boolean
	local deadline = os.clock() + math.max(timeoutSeconds, 0)
	repeat
		local waiting = false
		for _, player in players do
			local journal = PlayerData.matchAwards(player)
			if journal == nil and player.Parent == Players then
				waiting = true
			elseif journal then
				for _, record in journal.Pending do
					if record.ResultId == resultId then
						waiting = true
						MatchAwardService.flush(player)
						break
					end
				end
			end
		end
		if not waiting then
			return true
		end
		if os.clock() >= deadline then
			return false
		end
		task.wait(DataConfig.Persistence.SavePollSeconds)
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
	return function()
		local index = table.find(summaryListeners, listener)
		if index then
			table.remove(summaryListeners, index)
		end
	end
end

function ProgressionService.start(matchService: any)
	if started then
		return
	end
	started = true
	activeMatchService = matchService
	matchService.onEvent(handleEvent)
	MatchAwardService.onCommitted(committed)
end

return ProgressionService
