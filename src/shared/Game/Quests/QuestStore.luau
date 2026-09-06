-- Name: QuestStore.luau
-- Author: Jack C.
-- Description: Client-side projection of quest state, exposing snapshot/subscribe for the splash screen quest panel and a claim action.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local activeNetwork = Network

local ClientRequest = require(script.Parent.Parent.Data.ClientRequest)
local RefreshLoop = require(script.Parent.Parent.Data.RefreshLoop)

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
local stopRefresh: (() -> ())? = nil
local revision = 0
local generation = 0

local function notify()
	local current = state
	if current == nil then
		return
	end
	for _, callback in table.clone(callbacks) do
		local ok, err = pcall(callback, current)
		if not ok then
			warn(`[QuestStore] changed callback failed: {err}`)
		end
	end
end

function QuestStore.start(options: { network: any? }?)
	if started then
		return
	end
	started = true
	activeNetwork = if options and options.network then options.network else Network
	local currentGeneration = generation

	connection = activeNetwork.on("QuestStateChanged", function(newState: any)
		if currentGeneration ~= generation then
			return
		end
		revision += 1
		state = newState
		notify()
	end)

	stopRefresh = RefreshLoop(function()
		local requestedRevision = revision
		local ok, result = ClientRequest(activeNetwork.call, "GetQuestState")
		if not ok or result == nil then
			return false
		end
		if requestedRevision == revision and currentGeneration == generation then
			state = result
			notify()
		end
		return true
	end)
end

function QuestStore.claim(questId: string): (boolean, any)
	local currentGeneration = generation
	local requestedRevision = revision
	local callOk, ok, result = ClientRequest(activeNetwork.call, "ClaimQuest", questId)
	if not callOk then
		return false, "connection_failed"
	end
	if currentGeneration ~= generation then
		return false, "cancelled"
	end
	if ok and result ~= nil and requestedRevision == revision then
		revision += 1
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
	local subscribedGeneration = generation
	if current then
		task.defer(function()
			if connected and subscribedGeneration == generation then
				callback(state)
			end
		end)
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
	generation += 1
	revision += 1
	if stopRefresh then
		stopRefresh()
		stopRefresh = nil
	end
	if connection then
		connection:Disconnect()
		connection = nil
	end
	started = false
	activeNetwork = Network
	state = nil
	table.clear(callbacks)
end

return QuestStore
