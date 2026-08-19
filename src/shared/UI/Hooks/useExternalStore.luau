--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))

return function<T>(getSnapshot: () -> T, subscribe: ((T) -> ()) -> () -> ()): T
	local _, forceUpdate = React.useReducer(function(revision: number, _action: any)
		return revision + 1
	end, 0)

	React.useEffect(function()
		return subscribe(function()
			forceUpdate(nil)
		end)
	end, { getSnapshot, subscribe })

	return getSnapshot()
end
