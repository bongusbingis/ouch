-- Name: DailyRewardStore.luau
-- Author: Jack C.
-- Description: Client-side projection of daily reward state, exposing snapshot/subscribe for React and a claim action that round-trips to the server.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local activeNetwork = Network

local ClientRequest = require(script.Parent.Parent.Data.ClientRequest)
local RefreshLoop = require(script.Parent.Parent.Data.RefreshLoop)

local DailyRewardStore = {}

type PublicState = {
	canClaim: boolean,
	currentDay: number,
	nextDay: number,
	days: { any },
	totalClaimed: number,
}
type ChangedCallback = (state: PublicState) -> ()

local started = false
local state: PublicState? = nil
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
			warn(`[DailyRewardStore] changed callback failed: {err}`)
		end
	end
end

function DailyRewardStore.start(options: { network: any? }?)
	if started then
		return
	end
	started = true
	activeNetwork = if options and options.network then options.network else Network
	local currentGeneration = generation

	connection = activeNetwork.on("DailyRewardStateChanged", function(newState: any)
		if currentGeneration ~= generation then
			return
		end
		revision += 1
		state = newState
		notify()
	end)

	stopRefresh = RefreshLoop(function()
		local requestedRevision = revision
		local ok, result = ClientRequest(activeNetwork.call, "GetDailyRewardState")
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

function DailyRewardStore.claim(): (PublicState?, string?)
	local currentGeneration = generation
	local requestedRevision = revision
	local ok, result, err = ClientRequest(activeNetwork.call, "ClaimDailyReward")
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

function DailyRewardStore.snapshot(): PublicState?
	return state
end

function DailyRewardStore.subscribe(callback: ChangedCallback): () -> ()
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

function DailyRewardStore.stop()
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

return DailyRewardStore
