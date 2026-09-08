-- Description: Returns a spring that replays from zero to one whenever the given key changes, for content that should pop in each time it is replaced rather than cross-fade in place.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))

return function(key: any, config: any, immediate: boolean?): any
	local settled, setSettled = React.useState(false)

	React.useEffect(function()
		setSettled(false)
		local cancelled = false
		task.defer(function()
			if not cancelled then
				setSettled(true)
			end
		end)
		return function()
			cancelled = true
		end
	end, { key })

	return ReactSpring.useSpring({
		Alpha = if settled then 1 else 0,
		config = config,
		immediate = immediate,
	})
end
