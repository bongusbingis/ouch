-- Name: QuestService.luau
-- Author: Jack C.
-- Description: Server owner of daily quest state: assigns the deterministic daily set, advances progress from deduplicated match and combat events, handles claims, and grants rewards through the reward service.
-- Created: 2026-07-13

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Quests"))
local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local QuestLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Quests"):WaitForChild("QuestLogic")
)
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local PlayerData = require(script.Parent.PlayerData)
local RewardService = require(script.Parent.RewardService)
local AnalyticsService = require(script.Parent.AnalyticsService)

type QuestEntry = QuestLogic.QuestEntry
type QuestDefinition = QuestLogic.QuestDefinition
type EventContext = QuestLogic.EventContext

local QuestService = {}

local definitions = QuestsConfig.Definitions :: { QuestDefinition }
local definitionsById = QuestLogic.definitionsById(definitions)
local seenEvents = EventDedup.new(4096)
local started = false
local PROFILE_WAIT_SECONDS = 15

local function activeEntries(data: any): { QuestEntry }
	if data.Quests == nil or data.Quests.Active == nil then
		return {}
	end
	return QuestLogic.copyEntries(data.Quests.Active)
end

local function grantCompletedUnclaimed(data: any, player: Player)
	for _, entry in ipairs(activeEntries(data)) do
		if entry.claimed then
			continue
		end
		local definition = definitionsById[entry.id]
		if definition and entry.progress >= definition.goal then
			RewardService.grant(player, definition.reward)
		end
	end
end

local function assignDaily(data: any, player: Player, now: number)
	grantCompletedUnclaimed(data, player)
	local state = QuestLogic.createDailyEntries(player.UserId, now, definitions, QuestsConfig.DailyCount)
	data.Quests.DailyKey = state.dailyKey
	data.Quests.ResetAt = state.resetAt
	data.Quests.Active = state.active
end

local function waitForData(player: Player): any?
	local deadline = os.clock() + PROFILE_WAIT_SECONDS
	local data = PlayerData.get(player)
	while data == nil and player.Parent ~= nil and os.clock() < deadline do
		task.wait()
		data = PlayerData.get(player)
	end
	return data
end

local function ensureData(player: Player, now: number?, shouldWait: boolean?): any?
	local data = PlayerData.get(player)
	if data == nil and shouldWait then
		data = waitForData(player)
	end
	if data == nil then
		return nil
	end

	local currentTime = now or os.time()
	if data.Quests == nil then
		data.Quests = QuestLogic.blankState(currentTime)
	end

	local dailyKey = QuestLogic.dailyKey(currentTime)
	if
		data.Quests.DailyKey ~= dailyKey
		or tonumber(data.Quests.ResetAt) == nil
		or currentTime >= data.Quests.ResetAt
	then
		assignDaily(data, player, currentTime)
	end

	return data
end

local function stateFor(player: Player, shouldWait: boolean?): { [string]: any }?
	local data = ensureData(player, nil, shouldWait)
	if data == nil then
		return nil
	end

	local quests = {}
	local entries = activeEntries(data)
	for index, entry in ipairs(entries) do
		local definition = definitionsById[entry.id]
		if definition then
			table.insert(quests, QuestLogic.publicQuest(definition, entry, index))
		end
	end

	return {
		dailyKey = data.Quests.DailyKey,
		resetAt = data.Quests.ResetAt,
		quests = quests,
	}
end

local function fireState(player: Player)
	local state = stateFor(player)
	if state then
		Network.fire("QuestStateChanged", player, state)
	end
end

local function applyEventToPlayer(player: Player, event: { [string]: any }, context: EventContext): boolean
	local data = ensureData(player)
	if data == nil then
		return false
	end

	local changed = false
	local entries = activeEntries(data)
	for _, entry in ipairs(entries) do
		local definition = definitionsById[entry.id]
		if definition and entry.progress < definition.goal then
			local amount = QuestLogic.progressForEvent(definition, event, context)
			if amount > 0 then
				entry.progress = math.min(definition.goal, entry.progress + amount)
				changed = true
			end
		end
	end

	if changed then
		data.Quests.Active = entries
	end
	return changed
end

local function modeId(): string?
	local matchState = ReplicatedStorage:WaitForChild("MatchState")
	assert(matchState:IsA("Folder"), "[QuestService] ReplicatedStorage.MatchState must be a Folder")
	return matchState:GetAttribute("modeId") :: string?
end

local function playerWon(player: Player, winnerId: string?): boolean
	if winnerId == nil or winnerId == "" then
		return false
	end
	return winnerId == PlayerIds.toId(player) or player:GetAttribute("TeamId") == winnerId
end

local function handleMatchEnded(event: { [string]: any })
	local currentModeId = modeId()
	local winnerId = event.winnerId :: string?
	for _, player in Players:GetPlayers() do
		local changed = applyEventToPlayer(player, event, {
			playerId = PlayerIds.toId(player),
			modeId = currentModeId,
			playerWon = playerWon(player, winnerId),
		})
		if changed then
			fireState(player)
		end
	end
end

function QuestService.handleCombatEvent(event: { [string]: any })
	if not seenEvents.markSeen(event) then
		return
	end

	local sourceId = (event.sourceId or event.playerId) :: string?
	if sourceId == nil then
		return
	end

	local source = PlayerIds.fromId(sourceId)
	if source == nil then
		return
	end

	local changed = applyEventToPlayer(source, event, {
		playerId = PlayerIds.toId(source),
	})
	if changed then
		fireState(source)
	end
end

function QuestService.handleMatchEvent(event: { [string]: any })
	if event.kind == "MatchEnded" then
		handleMatchEnded(event)
	end
end

function QuestService.claim(player: Player, questId: string): (boolean, any)
	local data = ensureData(player, nil, true)
	if data == nil then
		return false, "profile_not_ready"
	end

	local entries = activeEntries(data)
	for _, entry in ipairs(entries) do
		if entry.id == questId then
			local definition = definitionsById[entry.id]
			if definition == nil then
				return false, "unknown_quest"
			end
			if entry.claimed then
				return false, "already_claimed"
			end
			if entry.progress < definition.goal then
				return false, "incomplete"
			end

			local ok, reason = RewardService.grant(player, definition.reward)
			if not ok then
				return false, reason or "grant_failed"
			end

			entry.claimed = true
			data.Quests.Active = entries

			AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.QuestClaimed, 1, { questId = questId })
			if definition.reward.kind == "Bonks" then
				AnalyticsService.logEconomyEvent(
					player,
					"Source",
					"Bonks",
					definition.reward.amount or 0,
					data.Bonks,
					AnalyticsConfig.EconomyTransactionTypes.Gameplay,
					questId
				)
			end

			local state = stateFor(player)
			if state then
				Network.fire("QuestStateChanged", player, state)
			end
			return true, state
		end
	end

	return false, "not_active"
end

function QuestService.stateForTesting(player: Player): { [string]: any }?
	return stateFor(player, true)
end

function QuestService.resetForTesting(player: Player): boolean
	local data = ensureData(player, nil, true)
	if data == nil then
		return false
	end
	assignDaily(data, player, os.time())
	fireState(player)
	return true
end

function QuestService.setProgressForTesting(player: Player, questId: string, progress: number): (boolean, string?)
	if progress ~= progress or math.abs(progress) == math.huge then
		return false, "invalid_progress"
	end
	local data = ensureData(player, nil, true)
	if data == nil then
		return false, "profile_not_ready"
	end
	local definition = definitionsById[questId]
	if definition == nil then
		return false, "unknown_quest"
	end

	local entries = activeEntries(data)
	for _, entry in entries do
		if entry.id == questId then
			entry.progress = math.clamp(math.floor(progress), 0, definition.goal)
			entry.claimed = false
			data.Quests.Active = entries
			fireState(player)
			return true
		end
	end
	return false, "not_active"
end

function QuestService.completeForTesting(player: Player, questId: string): (boolean, string?)
	local definition = definitionsById[questId]
	if definition == nil then
		return false, "unknown_quest"
	end
	return QuestService.setProgressForTesting(player, questId, definition.goal)
end

local function waitForProfile(player: Player)
	while player.Parent ~= nil and PlayerData.get(player) == nil do
		task.wait()
	end
	if player.Parent ~= nil then
		ensureData(player)
		fireState(player)
	end
end

function QuestService.start(matchService: any)
	if started then
		return
	end
	started = true

	Network.handleProtected("GetQuestState", {
		rateLimit = 4,
	}, function(player)
		return stateFor(player, true)
	end)
	Network.handleProtected("ClaimQuest", {
		rateLimit = 6,
		validate = function(_player, questId)
			return typeof(questId) == "string", "quest_id_required"
		end,
	}, function(player, questId: string)
		return QuestService.claim(player, questId)
	end)

	matchService.onEvent(QuestService.handleMatchEvent)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(waitForProfile, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(waitForProfile, player)
	end
end

return QuestService
