-- Name: SeasonStore.luau
-- Author: Jack C.
-- Description: Client-side projection of the replicated season/battle pass state, exposing snapshot/subscribe for the splash screen season status card.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local activeNetwork = Network

local ClientRequest = require(script.Parent.Parent.Data.ClientRequest)
local RefreshLoop = require(script.Parent.Parent.Data.RefreshLoop)

local SeasonStore = {}

type ChangedCallback = (state: any) -> ()

local started = false
local state: any = nil
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
			warn(`[SeasonStore] changed callback failed: {err}`)
		end
	end
end

function SeasonStore.start(options: { network: any? }?)
	if started then
		return
	end
	started = true
	activeNetwork = if options and options.network then options.network else Network
	local currentGeneration = generation

	connection = activeNetwork.on("SeasonPassStateChanged", function(newState: any)
		if currentGeneration ~= generation then
			return
		end
		revision += 1
		state = newState
		notify()
	end)

	stopRefresh = RefreshLoop(function()
		local requestedRevision = revision
		local ok, result = ClientRequest(activeNetwork.call, "GetSeasonPassState")
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

function SeasonStore.claimAll(): (any?, string?)
	local currentGeneration = generation
	local requestedRevision = revision
	local ok, result, err = ClientRequest(activeNetwork.call, "ClaimAllSeasonTiers")
	if not ok then
		return nil, "connection_failed"
	end
	if currentGeneration ~= generation then
		return nil, "cancelled"
	end
	if result ~= nil and requestedRevision == revision then
		revision += 1
		state = result
		notify()
	end
	return result, err
end

function SeasonStore.snapshot(): any
	return state
end

function SeasonStore.subscribe(callback: ChangedCallback): () -> ()
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

function SeasonStore.stop()
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

return SeasonStore
