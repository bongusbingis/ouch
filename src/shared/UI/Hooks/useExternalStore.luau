--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local connect = require(script.Parent.ExternalStoreSubscription)

return function<T>(getSnapshot: () -> T, subscribe: ((T) -> ()) -> () -> ()): T
	local _, forceUpdate = React.useReducer(function(revision: number, _action: any)
		return revision + 1
	end, 0)
	local snapshot = getSnapshot()
	local renderedSnapshot = React.useRef(snapshot)
	renderedSnapshot.current = snapshot

	React.useEffect(function()
		return connect(getSnapshot, subscribe, renderedSnapshot.current, function()
			forceUpdate(nil)
		end)
	end, { getSnapshot, subscribe })

	return snapshot
end
