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
