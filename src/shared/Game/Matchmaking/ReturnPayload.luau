-- Description: Builds and parses the teleport payload the arena sends back to the lobby, validating the party identity, match id, and member list against the schema.

--!strict

local ReturnPayload = {}

ReturnPayload.SchemaVersion = 1

local MAX_MEMBERS = 16

export type Payload = {
	schemaVersion: number,
	partyId: string,
	matchId: string,
	memberUserIds: { number },
	returnMode: "Party" | "Separate",
	queueOnArrival: boolean?,
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

function ReturnPayload.build(
	partyId: string,
	matchId: string,
	memberUserIds: { number },
	returnMode: ("Party" | "Separate")?,
	queueOnArrival: boolean?
): Payload
	return {
		schemaVersion = ReturnPayload.SchemaVersion,
		partyId = partyId,
		matchId = matchId,
		memberUserIds = table.clone(memberUserIds),
		returnMode = returnMode or "Party",
		queueOnArrival = if returnMode ~= "Separate" and queueOnArrival == true then true else nil,
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
	local returnMode = value.returnMode or "Party"
	if returnMode ~= "Party" and returnMode ~= "Separate" then
		return nil, "invalid_return_mode"
	end
	if value.queueOnArrival ~= nil and typeof(value.queueOnArrival) ~= "boolean" then
		return nil, "invalid_queue_intent"
	end
	if returnMode == "Separate" and value.queueOnArrival == true then
		return nil, "invalid_queue_intent"
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
		returnMode = returnMode,
		queueOnArrival = if value.queueOnArrival == true then true else nil,
	},
		nil
end

return table.freeze(ReturnPayload)
