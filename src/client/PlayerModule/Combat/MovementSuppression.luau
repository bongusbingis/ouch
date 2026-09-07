--!strict

-- Named local presentation requests suppress controls without changing the
-- character's movement settings or re-enabling another owner's disabled controls.

local requests: { [string]: boolean } = {}
local MovementSuppression = {}

function MovementSuppression.request(reason: string)
	requests[reason] = true
end

function MovementSuppression.release(reason: string)
	requests[reason] = nil
end

function MovementSuppression.isActive(): boolean
	return next(requests) ~= nil
end

return MovementSuppression
