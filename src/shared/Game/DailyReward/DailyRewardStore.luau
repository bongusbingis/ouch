-- Name: DailyRewardStore.luau
-- Author: Jack C.
-- Description: Client-side projection of daily reward state, exposing snapshot/subscribe for React and a claim action that round-trips to the server.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

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

local function notify()
	local current = state
	if current == nil then
		return
	end
	for _, callback in callbacks do
		local ok, err = pcall(callback, current)
		if not ok then
			warn(`[DailyRewardStore] changed callback failed: {err}`)
		end
	end
end

function DailyRewardStore.start()
	if started then
		return
	end
	started = true

	connection = Network.on("DailyRewardStateChanged", function(newState: any)
		state = newState
		notify()
	end)

	task.spawn(function()
		local result = Network.call("GetDailyRewardState")
		if result ~= nil and state == nil then
			state = result
			notify()
		end
	end)
end

function DailyRewardStore.claim(): (PublicState?, string?)
	local result, err = Network.call("ClaimDailyReward")
	if result ~= nil then
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

function DailyRewardStore.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	started = false
	state = nil
	table.clear(callbacks)
end

return DailyRewardStore
