-- Name: useLoopPhase.luau
-- Author: Jack C.
-- Description: Returns a binding that cycles from 0 to 1 over a fixed period, for looping demonstration animations that should not re-render the tree each frame. Holds at zero when the player has reduced motion enabled.
-- Created: 2026-08-26

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))

return function(periodSeconds: number, paused: boolean?): any
	local phase, setPhase = React.useBinding(0)

	React.useEffect(function()
		if paused or periodSeconds <= 0 then
			setPhase(0)
			return
		end
		local elapsed = 0
		local connection = RunService.RenderStepped:Connect(function(delta: number)
			elapsed = (elapsed + delta) % periodSeconds
			setPhase(elapsed / periodSeconds)
		end)
		return function()
			connection:Disconnect()
		end
	end, { periodSeconds, paused })

	return phase
end
