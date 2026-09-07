-- Drains PlayerData's persisted award journal in either place after entitlements resolve.
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataConfig = require(ReplicatedStorage.Config.Progression.Data)
local Boosts = require(ReplicatedStorage.Shared.Game.Economy.Boosts)
local PlayerData = require(script.Parent.PlayerData)
local EntitlementService = require(script.Parent.EntitlementService)
local BattlePassService = require(script.Parent.BattlePassService)

local MatchAwardService = {}
local AnalyticsService = require(script.Parent.AnalyticsService)
local started = false
local workers: { [Player]: boolean } = {}
local listeners: { (Player, any, any, any) -> () } = {}

local function commit(player: Player, id: string): boolean
	local data = PlayerData.get(player)
	if data == nil or not EntitlementService.awaitReady(player, 2) or PlayerData.get(player) ~= data then
		return false
	end
	local record = PlayerData.matchAwards(player).Pending[id]
	if record == nil or not record.Ready then
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
	record = PlayerData.resolveMatchAward(player, id, awarded, multipliers)
	local before = BattlePassService.stateFor(player)
	if not PlayerData.applyMatchAward(player, id) then
		return false
	end
	if not record.SeasonApplied then
		if not BattlePassService.addSeasonXp(player, record.Awarded.XP, record.SeasonId) then
			return false
		end
		PlayerData.markMatchSeasonApplied(player, id)
	end
	if record.Progress.MatchesPlayed > 0 then
		PlayerData.completeTutorial(player)
	end
	local after = BattlePassService.stateFor(player)
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
				if not record.Ready then
					continue
				end
				local release = PlayerData.acquireWriteLease(player)
				if release == nil then
					waiting = true
					break
				end
				local ok, committed = xpcall(function()
					return commit(player, id)
				end, debug.traceback)
				release()
				if not ok then
					warn(`[MatchAwardService] commit failed: {committed}`)
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
