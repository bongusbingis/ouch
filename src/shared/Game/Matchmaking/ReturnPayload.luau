-- Name: ReturnPayload.luau
-- Author: Jack C.
-- Description: Builds and parses the teleport payload the arena sends back to the lobby, validating the party identity, match id, and member list against the schema.
-- Created: 2026-08-18

--!strict

local ReturnPayload = {}

ReturnPayload.SchemaVersion = 1

local MAX_MEMBERS = 16

export type Payload = {
	schemaVersion: number,
	partyId: string,
	matchId: string,
	memberUserIds: { number },
}

local function validId(value: any): boolean
	return typeof(value) == "string" and #value > 0 and #value <= 100
end

local function copyMembers(value: any): ({ number }?, string?)
	if typeof(value) ~= "table" or #value == 0 or #value > MAX_MEMBERS then
		return nil, "invalid_members"
	end

	local members = {}
	local seen = {}
	for index, userId in value do
		if
			typeof(index) ~= "number"
			or index % 1 ~= 0
			or index < 1
			or index > #value
			or typeof(userId) ~= "number"
			or userId % 1 ~= 0
			or userId <= 0
			or seen[userId]
		then
			return nil, "invalid_members"
		end
		seen[userId] = true
		members[index] = userId
	end
	if #members ~= #value then
		return nil, "invalid_members"
	end
	return members, nil
end

function ReturnPayload.build(partyId: string, matchId: string, memberUserIds: { number }): Payload
	return {
		schemaVersion = ReturnPayload.SchemaVersion,
		partyId = partyId,
		matchId = matchId,
		memberUserIds = table.clone(memberUserIds),
	}
end

function ReturnPayload.parse(value: any): (Payload?, string?)
	if typeof(value) ~= "table" then
		return nil, "missing_payload"
	end
	if value.schemaVersion ~= ReturnPayload.SchemaVersion then
		return nil, "unsupported_schema"
	end
	if not validId(value.partyId) or not validId(value.matchId) then
		return nil, "invalid_identity"
	end

	local members, membersError = copyMembers(value.memberUserIds)
	if not members then
		return nil, membersError
	end

	return {
		schemaVersion = ReturnPayload.SchemaVersion,
		partyId = value.partyId,
		matchId = value.matchId,
		memberUserIds = members,
	},
		nil
end

return table.freeze(ReturnPayload)
