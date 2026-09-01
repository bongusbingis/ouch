-- Name: PartyModel.luau
-- Author: Jack C.
-- Description: Pure party record operations, including cloning, membership changes, timestamp refresh, return-to-lobby transitions, and projection to the snapshot the client renders.
-- Created: 2026-08-15

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Matchmaking.Config)

local PartyModel = {}

function PartyModel.clone(party)
	local copy = table.clone(party)
	copy.members = {}

	for index, member in party.members do
		copy.members[index] = table.clone(member)
	end

	if party.queueTicket then
		copy.queueTicket = table.clone(party.queueTicket)
	end

	if party.claim then
		copy.claim = table.clone(party.claim)
	end

	return copy
end

function PartyModel.hasMember(party, userId)
	for _, member in party.members do
		if member.userId == userId then
			return true
		end
	end

	return false
end

function PartyModel.removeMember(party, userId)
	local members = {}
	local removed = false

	for _, member in party.members do
		if member.userId == userId then
			removed = true
		else
			table.insert(members, member)
		end
	end

	party.members = members
	if removed and party.leaderUserId == userId then
		party.leaderUserId = members[1] and members[1].userId or 0
	end

	return removed
end

function PartyModel.touch(party, now)
	party.revision += 1
	party.updatedAt = now
	party.leaseUntil = now + Config.PresenceLifetime
	return party
end

function PartyModel.returnToLobby(party)
	party.phase = "Lobby"
	party.queueTicket = nil
	party.claim = nil
	party.matchId = nil
	return party
end

function PartyModel.toSnapshot(party)
	local members = {}
	for index, member in party.members do
		members[index] = table.clone(member)
	end

	return {
		schemaVersion = party.schemaVersion,
		partyId = party.partyId,
		joinCode = party.joinCode,
		revision = party.revision,
		leaderUserId = party.leaderUserId,
		members = members,
		allowFriendJoins = party.allowFriendJoins,
		phase = party.phase,
		matchId = party.matchId,
		createdAt = party.createdAt,
		updatedAt = party.updatedAt,
	}
end

return PartyModel
