-- Description: Pure quest rules: deterministic daily selection, UTC daily keys and reset times, mapping match and combat events to progress, and building clamped payloads for the client.

--!strict

export type Reward = {
	kind: string,
	amount: number?,
	itemId: string?,
}

export type QuestTrack = {
	kind: string,
	modeId: string?,
}

export type QuestDefinition = {
	id: string,
	title: string,
	goal: number,
	steps: number,
	reward: Reward,
	track: QuestTrack,
}

export type QuestEntry = {
	id: string,
	progress: number,
	claimed: boolean,
}

export type QuestState = {
	dailyKey: string,
	resetAt: number,
	active: { QuestEntry },
}

export type EventContext = {
	playerId: string,
	modeId: string?,
	playerWon: boolean?,
}

local QuestLogic = {}

local UINT32 = 4294967296
local SECONDS_PER_DAY = 86400

local function cloneReward(reward: Reward): Reward
	return {
		kind = reward.kind,
		amount = reward.amount,
		itemId = reward.itemId,
	}
end

local function hash(input: string): number
	local value = 2166136261
	for index = 1, #input do
		value = (bit32.bxor(value, string.byte(input, index)) * 16777619) % UINT32
	end
	return value
end

local function nextRandom(seed: number): number
	return (seed * 1664525 + 1013904223) % UINT32
end

function QuestLogic.dailyKey(now: number): string
	return os.date("!%Y-%m-%d", now)
end

-- A missing first snapshot establishes the current cycle; only a later UTC
-- key change represents newly assigned quests for an already-mounted client.
function QuestLogic.isNewDailyCycle(previousKey: string?, currentKey: string?): boolean
	return previousKey ~= nil and currentKey ~= nil and currentKey ~= "" and previousKey ~= currentKey
end

-- Plain timestamp arithmetic: building a calendar date from day + 1 throws on
-- the last UTC day of every month in Roblox DateTime.
function QuestLogic.nextResetAt(now: number): number
	return now - (now % SECONDS_PER_DAY) + SECONDS_PER_DAY
end

-- True when the stored daily key or reset time no longer covers `now`.
function QuestLogic.needsDailyReset(dailyKey: any, resetAt: any, now: number): boolean
	local resetTime = tonumber(resetAt)
	return dailyKey ~= QuestLogic.dailyKey(now) or resetTime == nil or now >= resetTime
end

function QuestLogic.blankState(now: number): QuestState
	return {
		dailyKey = QuestLogic.dailyKey(now),
		resetAt = QuestLogic.nextResetAt(now),
		active = {},
	}
end

function QuestLogic.definitionsById(definitions: { QuestDefinition }): { [string]: QuestDefinition }
	local byId = {}
	for _, definition in definitions do
		byId[definition.id] = definition
	end
	return byId
end

function QuestLogic.selectDailyQuestIds(
	userId: number,
	dailyKey: string,
	definitions: { QuestDefinition },
	count: number
): { string }
	local pool = table.clone(definitions)
	table.sort(pool, function(left, right)
		return left.id < right.id
	end)

	local selected = {}
	local seed = hash(`{userId}:{dailyKey}`)
	while #selected < count and #pool > 0 do
		seed = nextRandom(seed)
		local index = (seed % #pool) + 1
		table.insert(selected, pool[index].id)
		table.remove(pool, index)
	end
	return selected
end

function QuestLogic.createDailyEntries(
	userId: number,
	now: number,
	definitions: { QuestDefinition },
	count: number
): QuestState
	local dailyKey = QuestLogic.dailyKey(now)
	local active = {}
	for _, id in QuestLogic.selectDailyQuestIds(userId, dailyKey, definitions, count) do
		table.insert(active, {
			id = id,
			progress = 0,
			claimed = false,
		})
	end
	return {
		dailyKey = dailyKey,
		resetAt = QuestLogic.nextResetAt(now),
		active = active,
	}
end

function QuestLogic.copyEntries(entries: { any }): { QuestEntry }
	local copied = {}
	if entries == nil then
		return copied
	end

	for index = 1, #entries do
		local entry = entries[index]
		table.insert(copied, {
			id = entry.id or entry.Id,
			progress = tonumber(entry.progress or entry.Progress) or 0,
			claimed = entry.claimed == true or entry.Claimed == true,
		})
	end
	return copied
end

-- Entries whose reward is still owed when the daily set is replaced.
function QuestLogic.completedUnclaimed(entries: { QuestEntry }, byId: { [string]: QuestDefinition }): { QuestEntry }
	local owed = {}
	for _, entry in entries do
		local definition = byId[entry.id]
		if not entry.claimed and definition ~= nil and entry.progress >= definition.goal then
			table.insert(owed, entry)
		end
	end
	return owed
end

local function sourceMatches(event: { [string]: any }, playerId: string): boolean
	return event.sourceId == playerId or event.playerId == playerId
end

function QuestLogic.progressForEvent(
	definition: QuestDefinition,
	event: { [string]: any },
	context: EventContext
): number
	local playerId = context.playerId
	local track = definition.track
	local kind = track.kind

	if kind == "Elim" then
		return if event.kind == "Elim" and sourceMatches(event, playerId) then 1 else 0
	elseif kind == "DodgeballElim" then
		return if event.kind == "Elim" and event.projectileId ~= nil and sourceMatches(event, playerId) then 1 else 0
	elseif kind == "HammerElim" then
		return if event.kind == "Elim" and event.projectileId == nil and sourceMatches(event, playerId) then 1 else 0
	elseif kind == "HammerHit" then
		return if event.kind == "HammerHit" and sourceMatches(event, playerId) then 1 else 0
	elseif kind == "BallThrow" then
		return if event.kind == "BallReleased" and sourceMatches(event, playerId) then 1 else 0
	elseif kind == "Catch" then
		return if event.kind == "BallCaught" and sourceMatches(event, playerId) then 1 else 0
	elseif kind == "MatchPlayed" then
		return if event.kind == "MatchEnded" and event.reason ~= "NoContest" then 1 else 0
	elseif kind == "Win" then
		return if event.kind == "MatchEnded" and context.playerWon == true then 1 else 0
	elseif kind == "ModeWin" then
		return if event.kind == "MatchEnded"
				and context.playerWon == true
				and context.modeId == track.modeId
			then 1
			else 0
	end

	return 0
end

function QuestLogic.publicQuest(definition: QuestDefinition, entry: QuestEntry, slot: number): { [string]: any }
	local progress = math.clamp(entry.progress, 0, definition.goal)
	return {
		slot = slot,
		questId = definition.id,
		title = definition.title,
		progress = progress,
		goal = definition.goal,
		steps = definition.steps,
		claimed = entry.claimed,
		completed = progress >= definition.goal,
		reward = cloneReward(definition.reward),
	}
end

return QuestLogic
