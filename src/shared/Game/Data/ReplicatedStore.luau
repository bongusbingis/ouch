-- Owns remote-backed client projections; generation and revision guards reject stale lifecycle and request results.
--!strict

local Network = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Network"))
local ClientRequest = require(script.Parent.ClientRequest)
local RefreshLoop = require(script.Parent.RefreshLoop)
local Listeners = require(script.Parent.Parent.Util.Listeners)

export type Store<T> = {
	start: (options: { network: any? }?) -> (),
	stop: () -> (),
	snapshot: () -> T?,
	subscribe: (callback: (T) -> ()) -> () -> (),
	request: (remote: string, selectState: (any, any) -> T?, ...any) -> (boolean, any, any),
}

local ReplicatedStore = {}

function ReplicatedStore.new<T>(config: { tag: string, changedRemote: string, fetchRemote: string }): Store<T>
	local started = false
	local state: T? = nil
	local activeNetwork = Network
	local connection: any = nil
	local stopRefresh: (() -> ())? = nil
	local revision = 0
	local generation = 0
	local listeners: Listeners.Collection<T> = Listeners.new(config.tag, true)
	local store = {}

	local function notify()
		local current = state
		if current ~= nil then
			listeners.emit(current)
		end
	end

	function store.start(options: { network: any? }?)
		if started then
			return
		end
		started = true
		activeNetwork = if options and options.network then options.network else Network
		local currentGeneration = generation
		connection = activeNetwork.on(config.changedRemote, function(newState: T)
			if currentGeneration ~= generation then
				return
			end
			revision += 1
			state = newState
			notify()
		end)
		stopRefresh = RefreshLoop(function()
			local requestedRevision = revision
			local ok, result = ClientRequest(activeNetwork.call, config.fetchRemote)
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

	function store.request(remote: string, selectState: (any, any) -> T?, ...: any): (boolean, any, any)
		local currentGeneration = generation
		local requestedRevision = revision
		local ok, result, detail = ClientRequest(activeNetwork.call, remote, ...)
		if not ok then
			return false, "connection_failed", nil
		end
		if currentGeneration ~= generation then
			return false, "cancelled", nil
		end
		if requestedRevision == revision then
			local nextState = selectState(result, detail)
			if nextState ~= nil then
				revision += 1
				state = nextState
				notify()
			end
		end
		return true, result, detail
	end

	function store.snapshot(): T?
		return state
	end

	function store.subscribe(callback: (T) -> ()): () -> ()
		local unsubscribe = listeners.add(callback)
		local connected = true
		local subscribedGeneration = generation
		if state then
			task.defer(function()
				if connected and subscribedGeneration == generation then
					callback(state :: T)
				end
			end)
		end
		return function()
			connected = false
			unsubscribe()
		end
	end

	function store.stop()
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
		listeners.clear()
	end

	return store
end

return table.freeze(ReplicatedStore)
