-- Name: QuestStore.luau
-- Author: Jack C.
-- Description: Client-side projection of quest state, exposing snapshot/subscribe for the splash screen quest panel and a claim action.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local QuestStore = {}

type QuestState = {
	dailyKey: string,
	resetAt: number,
	quests: { any },
}
type ChangedCallback = (state: QuestState) -> ()

local started = false
local state: QuestState? = nil
local callbacks: { ChangedCallback } = {}
local connection: any = nil

local function notify()
	local current = state
	if current == nil then
		return
	end
	for _, callback in callbacks do
		local ok, err = pcall(callback, current)
		if not ok then
			warn(`[QuestStore] changed callback failed: {err}`)
		end
	end
end

function QuestStore.start()
	if started then
		return
	end
	started = true

	connection = Network.on("QuestStateChanged", function(newState: any)
		state = newState
		notify()
	end)

	task.spawn(function()
		local result = Network.call("GetQuestState")
		if result ~= nil and state == nil then
			state = result
			notify()
		end
	end)
end

function QuestStore.claim(questId: string): (boolean, any)
	local ok, result = Network.call("ClaimQuest", questId)
	if ok and result ~= nil then
		state = result
		notify()
	end
	return ok, result
end

function QuestStore.snapshot(): QuestState?
	return state
end

function QuestStore.subscribe(callback: ChangedCallback): () -> ()
	table.insert(callbacks, callback)
	local connected = true
	local current = state
	if current then
		task.defer(callback, current)
	end
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(callbacks, callback)
		if index then
			table.remove(callbacks, index)
		end
	end
end

function QuestStore.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	started = false
	state = nil
	table.clear(callbacks)
end

return QuestStore
