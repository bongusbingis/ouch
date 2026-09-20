-- Records earned match progress in PlayerData's journal and presents committed match summaries.
--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Data"))
local Participation = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("Participation")
)
local PlayerIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("PlayerIds")
)
local EventDedup = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("EventDedup")
)
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local GoodSignal = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("goodsignal"))
local PlayerData = require(script.Parent.PlayerData)
local MatchAwardService = require(script.Parent.MatchAwardService)
local BattlePassService = require(script.Parent.BattlePassService)
local ArenaSessionService = require(script.Parent.ArenaSessionService)

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
local awardCommittedSignal = GoodSignal.new()
local seenEvents = EventDedup.new()
local activeMatchService: any = nil
local participation: { [Player]: any } = {}
local function activity(player: Player): any
	if not participation[player] then
		participation[player] = Participation.new()
	end
	return participation[player]
end

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
	awardCommittedSignal:Fire(player, record.ResultId)
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
		local eligible = Participation.eligible(activity(player), record.Progress, DataConfig.Participation)
		local delta = if completed and eligible then rewards("MatchComplete") else { XP = 0, Bonks = 0 }
		delta.MatchesPlayed = if completed then 1 else 0
		if winner ~= nil and winner ~= "" then
			if won then
				delta.Wins = 1
				if eligible then
					delta.XP += DataConfig.ProgressionXP.Win
					delta.Bonks += DataConfig.ProgressionBonks.Win
				end
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
		table.clear(participation)
		for _, player in Players:GetPlayers() do
			if ArenaSessionService.isRoundEligible(player) then
				ensureRecord(player)
			end
		end
	elseif event.kind == "Elim" and seenEvents.markSeen(event) then
		local source = PlayerIds.fromId(event.sourceId)
		local target = PlayerIds.fromId(event.targetId)
		if source and source ~= target then
			local delta = if Participation.payout(activity(source), "Elim", event.targetId, DataConfig.Participation)
				then rewards("Elim")
				else { XP = 0, Bonks = 0 }
			delta.Elims = 1
			add(source, delta)
		end
		add(target, { Deaths = 1 })
	elseif event.kind == "BallCaught" and seenEvents.markSeen(event) then
		local player = PlayerIds.fromEvent(event)
		if player then
			local delta = if Participation.payout(activity(player), "Catch", event.targetId, DataConfig.Participation)
				then rewards("Catch")
				else { XP = 0, Bonks = 0 }
			delta.Catches = 1
			Participation.action(activity(player), os.clock())
			add(player, delta)
		end
	elseif event.kind == "BallWindup" or event.kind == "HammerSwing" then
		local player = PlayerIds.fromEvent(event)
		if player and awardId ~= nil then
			Participation.action(activity(player), os.clock())
		end
	elseif event.kind == "MatchEnded" then
		commitMatch()
	end
end

local function isPending(player: Player, resultId: string): boolean
	if player.Parent ~= Players then
		return false
	end
	local journal = PlayerData.matchAwards(player)
	if journal == nil then
		return true
	end
	for _, record in journal.Pending do
		if record.ResultId == resultId then
			return true
		end
	end
	return false
end

local function anyPending(players: { Player }, resultId: string): boolean
	for _, player in players do
		if isPending(player, resultId) then
			return true
		end
	end
	return false
end

function ProgressionService.awaitCommitted(players: { Player }, resultId: string, timeoutSeconds: number): boolean
	if not anyPending(players, resultId) then
		return true
	end
	local remaining = math.max(timeoutSeconds, 0)
	if remaining == 0 then
		return false
	end

	for _, player in players do
		if isPending(player, resultId) then
			MatchAwardService.flush(player)
		end
	end

	local thread = coroutine.running()
	local conn: any = nil
	local removingConn: any = nil
	local timer: thread? = nil

	local function check()
		if not anyPending(players, resultId) then
			if conn then
				conn:Disconnect()
				conn = nil
			end
			if removingConn then
				removingConn:Disconnect()
				removingConn = nil
			end
			if timer then
				task.cancel(timer)
				timer = nil
			end
			task.spawn(thread, true)
		end
	end

	timer = task.delay(remaining, function()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if removingConn then
			removingConn:Disconnect()
			removingConn = nil
		end
		task.spawn(thread, not anyPending(players, resultId))
	end)

	conn = awardCommittedSignal:Connect(function(_player: Player, committedResultId: string)
		if committedResultId == resultId then
			check()
		end
	end)

	removingConn = Players.PlayerRemoving:Connect(function()
		check()
	end)

	return coroutine.yield()
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
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < DataConfig.Participation.SampleSeconds then
			return
		end
		local interval = elapsed
		elapsed = 0
		if awardId == nil then
			return
		end
		for _, player in Players:GetPlayers() do
			if not ArenaSessionService.isRoundEligible(player) then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local position = if root
					and root:IsA("BasePart")
					and character:GetAttribute("CombatAlive") ~= false
				then root.Position
				else nil
			Participation.sample(activity(player), position, os.clock(), interval, DataConfig.Participation)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		participation[player] = nil
	end)
end

return ProgressionService
