-- Name: SeasonStore.luau
-- Author: Jack C.
-- Description: Client-side projection of the replicated season/battle pass state, exposing snapshot/subscribe for the splash screen season status card.
-- Created: 2026-09-01

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local SeasonStore = {}

type ChangedCallback = (state: any) -> ()

local started = false
local state: any = nil
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
			warn(`[SeasonStore] changed callback failed: {err}`)
		end
	end
end

function SeasonStore.start()
	if started then
		return
	end
	started = true

	connection = Network.on("SeasonPassStateChanged", function(newState: any)
		state = newState
		notify()
	end)

	task.spawn(function()
		local result = Network.call("GetSeasonPassState")
		if result ~= nil and state == nil then
			state = result
			notify()
		end
	end)
end

function SeasonStore.snapshot(): any
	return state
end

function SeasonStore.subscribe(callback: ChangedCallback): () -> ()
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

function SeasonStore.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	started = false
	state = nil
	table.clear(callbacks)
end

return SeasonStore
