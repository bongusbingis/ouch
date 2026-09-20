-- Use the character collision mask for support rays so they see native seesaws.
--!strict
local PhysicsService = game:GetService("PhysicsService")

local Query = {}

function Query.groupFor(root: BasePart): string
	local group = root.CollisionGroup
	if string.sub(group, 1, #"SeesawCharacter_") == "SeesawCharacter_" then
		return group
	end
	local fallback = "SeesawCharacter_Default"
	return if PhysicsService:IsCollisionGroupRegistered(fallback) then fallback else group
end

return Query
