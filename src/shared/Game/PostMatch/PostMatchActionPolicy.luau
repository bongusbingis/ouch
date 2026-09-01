-- Name: PostMatchActionPolicy.luau
-- Author: Jack C.
-- Description: Pure authorization policy for post-match actions: the reveal gate, leader-owned party decisions, and non-leader self-separation.
-- Created: 2026-08-31

--!strict

local PostMatchActionPolicy = {}

export type Action = "PlayAgain" | "CancelPlayAgain" | "ReturnToLobby" | "LeaveParty"

function PostMatchActionPolicy.validate(
	action: Action,
	userId: number,
	leaderUserId: number,
	partySize: number,
	now: number,
	interactiveAt: number
): (boolean, string?)
	if now < interactiveAt then
		return false, "reveal_in_progress"
	end
	if action == "LeaveParty" then
		if partySize <= 1 or userId == leaderUserId then
			return false, "leave_party_unavailable"
		end
		return true, nil
	end
	if userId ~= leaderUserId then
		return false, "not_party_leader"
	end
	return true, nil
end

return table.freeze(PostMatchActionPolicy)
