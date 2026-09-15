-- Name: useReveal.luau
-- Author: Jack C.
-- Description: Returns whether a staged element should be showing yet: false until the given delay has elapsed since the key last changed, and immediately true when the caller asks for no motion, so result blocks can pop in one after another.
-- Created: 2026-09-15

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))

return function(key: any, delay: number, immediate: boolean): boolean
	local shown, setShown = React.useState(immediate or delay <= 0)
	React.useEffect(function()
		if immediate or delay <= 0 then
			setShown(true)
			return nil
		end
		setShown(false)
		local thread = task.delay(delay, function()
			setShown(true)
		end)
		return function()
			if coroutine.status(thread) ~= "dead" then
				task.cancel(thread)
			end
		end
	end, { key, delay, immediate })
	return shown
end
