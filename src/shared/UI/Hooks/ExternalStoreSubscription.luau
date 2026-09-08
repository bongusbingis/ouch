-- Description: Subscription helper that connects a store, re-checks the snapshot after subscribing so a mutation between render and subscribe is not missed, and returns the disconnect.

--!strict

return function<T>(
	getSnapshot: () -> T,
	subscribe: ((T) -> ()) -> () -> (),
	renderedSnapshot: T,
	onChange: () -> ()
): () -> ()
	local disconnect = subscribe(function()
		onChange()
	end)
	if getSnapshot() ~= renderedSnapshot then
		onChange()
	end
	return disconnect
end
