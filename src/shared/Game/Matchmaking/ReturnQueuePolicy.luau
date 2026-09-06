--!strict

-- Bounded return intent belongs to the party record. Arrivals cannot re-arm a
-- consumed intent; automatic queueing requires every expected member locally.

local ReturnQueuePolicy = {}

function ReturnQueuePolicy.arm(party: any, payload: any, now: number, timeout: number)
	if party.lastReturnMatchId == payload.matchId then
		return
	end
	party.lastReturnMatchId = payload.matchId
	party.returnSourcePartyId = payload.partyId
	party.returnQueue = if payload.queueOnArrival == true
		then {
			matchId = payload.matchId,
			memberUserIds = table.clone(payload.memberUserIds),
			expiresAt = now + timeout,
		}
		else nil
end

function ReturnQueuePolicy.evaluate(party: any, present: { [number]: boolean }, now: number): string
	local pending = party.returnQueue
	if party.phase ~= "Lobby" or pending == nil then
		return "None"
	end
	if now >= pending.expiresAt then
		return "Expired"
	end
	local members = {}
	for _, member in party.members do
		members[member.userId] = true
		if not present[member.userId] then
			return "Waiting"
		end
	end
	for _, userId in pending.memberUserIds do
		if not members[userId] or not present[userId] then
			return "Waiting"
		end
	end
	return if present[party.leaderUserId] then "Ready" else "Waiting"
end

return table.freeze(ReturnQueuePolicy)
