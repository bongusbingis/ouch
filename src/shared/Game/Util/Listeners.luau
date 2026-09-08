-- Owns ordered subscriptions and protected synchronous dispatch; callers choose whether emission snapshots the list.
--!strict

export type Collection<T...> = {
	add: (callback: (T...) -> ()) -> () -> (),
	emit: (T...) -> (),
	emitWith: (invoke: ((T...) -> ()) -> ()) -> (),
	clear: () -> (),
}

local Listeners = {}

function Listeners.new<T...>(tag: string, snapshotDispatch: boolean?, errorLabel: string?): Collection<T...>
	local callbacks: { (T...) -> () } = {}
	return {
		add = function(callback: (T...) -> ()): () -> ()
			table.insert(callbacks, callback)
			local connected = true
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
		end,
		emit = function(...: T...)
			for _, callback in if snapshotDispatch then table.clone(callbacks) else callbacks do
				local ok, err = pcall(callback, ...)
				if not ok then
					warn(`[{tag}] {errorLabel or "changed callback failed"}: {err}`)
				end
			end
		end,
		emitWith = function(invoke: ((T...) -> ()) -> ())
			for _, callback in if snapshotDispatch then table.clone(callbacks) else callbacks do
				local ok, err = pcall(invoke, callback)
				if not ok then
					warn(`[{tag}] {errorLabel or "changed callback failed"}: {err}`)
				end
			end
		end,
		clear = function()
			table.clear(callbacks)
		end,
	}
end

return table.freeze(Listeners)
