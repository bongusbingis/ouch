-- Drains PlayerData's persisted award journal in either place after entitlements resolve.
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Data"))
local Boosts = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("Boosts")
)
local MatchAwards = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Progression"):WaitForChild("MatchAwards")
)
local PlayerData = require(script.Parent.PlayerData)
local EntitlementService = require(script.Parent.EntitlementService)
local BattlePassService = require(script.Parent.BattlePassService)

local MatchAwardService = {}
local AnalyticsService = require(script.Parent.AnalyticsService)
local started = false
local workers: { [Player]: boolean } = {}
local rejected: { [Player]: { [string]: string } } = {}
local listeners: { (Player, any, any, any) -> () } = {}

local function reportRejected(player: Player, id: string, reason: string)
	local byId = rejected[player]
	if byId == nil then
		byId = {}
		rejected[player] = byId
	end
	if byId[id] ~= reason then
		byId[id] = reason
		warn(`[MatchAwardService] user {player.UserId} award {id}: {reason}`)
	end
end

local function reportRecovered(player: Player, id: string)
	local byId = rejected[player]
	if byId ~= nil and byId[id] ~= nil then
		warn(`[MatchAwardService] user {player.UserId} award {id}: persisted award validation recovered`)
		byId[id] = nil
	end
end

local function commit(player: Player, id: string): (boolean, string?)
	local data = PlayerData.get(player)
	if data == nil or not EntitlementService.awaitReady(player, 2) or PlayerData.get(player) ~= data then
		return false
	end
	local record = PlayerData.matchAwards(player).Pending[id]
	if record == nil then
		return true
	end
	local valid, reason = MatchAwards.validatePending(record, id)
	if not valid then
		return false, assert(reason, "MatchAwards.validatePending rejected without a path diagnostic")
	end
	if not record.Ready then
		return true
	end
	local multipliers = EntitlementService.multipliers(player)
	local progress = record.Progress
	local awarded = {
		Elims = progress.Elims,
		Deaths = progress.Deaths,
		Catches = progress.Catches,
		Wins = progress.Wins,
		Losses = progress.Losses,
		MatchesPlayed = progress.MatchesPlayed,
		XP = progress.XP,
		Bonks = progress.Bonks,
	}
	awarded.XP = Boosts.apply(awarded.XP, multipliers.Xp)
	awarded.Bonks = Boosts.apply(awarded.Bonks, multipliers.Bonks)
	valid, reason = MatchAwards.validateDelta(awarded, `MatchAwards.Pending.{id}.Awarded`)
	if not valid then
		return false, assert(reason, "MatchAwards.validateDelta rejected without a path diagnostic")
	end
	record, reason = PlayerData.resolveMatchAward(player, id, awarded, multipliers)
	if record == nil then
		return false, reason
	end
	local before = BattlePassService.stateFor(player)
	if before == nil then
		warn(`[MatchAwardService] award {id} season {tostring(record.SeasonId)}: season state unavailable before payout`)
		return false
	end
	local applied, applyReason = PlayerData.applyMatchAward(player, id)
	if not applied then
		return false, applyReason
	end
	local credited, creditReason = PlayerData.creditMatchSeasonXp(player, id)
	if not credited then
		warn(`[MatchAwardService] {creditReason}`)
		return false
	end
	local settled, settlementReason = BattlePassService.settleArchivedSeason(player, record.SeasonId, id)
	if not settled then
		warn(`[MatchAwardService] {settlementReason}`)
		return false
	end
	if (record.Progress.MatchesPlayed or 0) > 0 then
		PlayerData.completeTutorial(player)
	end
	local after = BattlePassService.stateFor(player)
	if after == nil then
		warn(`[MatchAwardService] award {id} season {tostring(record.SeasonId)}: season state unavailable after payout`)
		return false
	end
	BattlePassService.fireState(player)
	if not PlayerData.completeMatchAward(player, id) then
		return false
	end
	if record.Awarded.Bonks > 0 then
		pcall(
			AnalyticsService.logEconomyEvent,
			player,
			"Source",
			"Bonks",
			record.Awarded.Bonks,
			data.Bonks,
			"Gameplay",
			"MatchRewards",
			{ source = "MatchRewards" }
		)
	end
	for _, listener in table.clone(listeners) do
		local ok, err = pcall(listener, player, record, before, after)
		if not ok then
			warn(`[MatchAwardService] listener failed: {err}`)
		end
	end
	return true
end

function MatchAwardService.flush(player: Player)
	if workers[player] or not PlayerData.isLoaded(player) then
		return
	end
	workers[player] = true
	task.defer(function()
		while player.Parent == Players and PlayerData.isLoaded(player) do
			local journal = PlayerData.matchAwards(player)
			if journal == nil then
				break
			end
			local waiting = false
			for id, record in journal.Pending do
				local valid, reason = MatchAwards.validatePending(record, id)
				if not valid then
					reportRejected(player, id, assert(reason, "MatchAwards.validatePending rejected without a path diagnostic"))
					waiting = true
					continue
				end
				if not record.Ready then
					reportRecovered(player, id)
					continue
				end
				local release = PlayerData.acquireWriteLease(player)
				if release == nil then
					waiting = true
					break
				end
				local ok, committed, commitReason = xpcall(function()
					return commit(player, id)
				end, debug.traceback)
				release()
				if not ok then
					warn(`[MatchAwardService] award {id} season {tostring(record.SeasonId)} commit failed: {committed}`)
				elseif not committed and commitReason ~= nil then
					reportRejected(player, id, commitReason)
				elseif committed then
					reportRecovered(player, id)
				end
				if not ok or not committed then
					waiting = true
				end
			end
			if not waiting then
				break
			end
			task.wait(DataConfig.Persistence.ProgressionRetrySeconds)
		end
		if player.Parent == Players and PlayerData.canQueueMatchAward(player) then
			player:SetAttribute("RewardsRecoveryPending", nil)
		end
		workers[player] = nil
		rejected[player] = nil
	end)
end

function MatchAwardService.onCommitted(callback: (Player, any, any, any) -> ()): () -> ()
	table.insert(listeners, callback)
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

function MatchAwardService.start()
	if started then
		return
	end
	started = true
	PlayerData.onLoaded(MatchAwardService.flush)
	for _, player in Players:GetPlayers() do
		MatchAwardService.flush(player)
	end
end

return MatchAwardService
