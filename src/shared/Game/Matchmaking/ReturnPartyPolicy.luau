-- Name: ReturnPartyPolicy.luau
-- Author: Jack C.
-- Description: Pure rule for restoring a party returning from the arena, deciding whether to revive the surviving record or accept one an earlier arrival already restored.
-- Created: 2026-08-24

--!strict

local ReturnPartyPolicy = {}

export type Action = "Keep" | "Restore"

function ReturnPartyPolicy.resolve(party: any, payload: any, userId: number): Action?
	if party == nil or not table.find(payload.memberUserIds, userId) then
		return nil
	end

	local isMember = false
	for _, member in party.members do
		if member.userId == userId then
			isMember = true
			break
		end
	end
	if not isMember then
		return nil
	end

	if party.phase == "Lobby" then
		return "Keep"
	end
	if (party.phase == "Assigned" or party.phase == "Teleporting") and party.matchId == payload.matchId then
		return "Restore"
	end
	return nil
end

return table.freeze(ReturnPartyPolicy)
