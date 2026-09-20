--!strict

local PartyVisibilityPolicy = {}

function PartyVisibilityPolicy.shouldShowCharacter(
	userId: number,
	localUserId: number,
	backpackActive: boolean
): boolean
	return not backpackActive or userId == localUserId
end

return PartyVisibilityPolicy
