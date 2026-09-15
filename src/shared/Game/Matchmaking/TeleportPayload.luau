-- Description: Builds and parses the teleport payload the lobby sends to the arena, carrying session, party, queue and mode selection data and rejecting malformed or obsolete versions.

--!strict

local TeleportPayload = {}

TeleportPayload.SchemaVersion = 3

export type ModeSelection =
	{
		strategy: "Vote",
		options: { string },
	}
	| {
		strategy: "Fixed",
		modeId: string,
	}

export type PartyContext = {
	leaderUserId: number,
	memberUserIds: { number },
}

export type Payload = {
	schemaVersion: number,
	matchId: string,
	partyId: string,
	queueId: string,
	expectedPlayerCount: number,
	modeSelection: ModeSelection,
	party: PartyContext?,
}

local function validId(value: any): boolean
	return typeof(value) == "string" and #value > 0 and #value <= 100
end

local function validKey(value: any): boolean
	return typeof(value) == "string" and #value > 0 and #value <= 32
end

local function copyOptions(value: any): ({ string }?, string?)
	if typeof(value) ~= "table" or #value == 0 or #value > 16 then
		return nil, "invalid_mode_options"
	end

	local options = {}
	local seen = {}
	for index, option in value do
		if
			typeof(index) ~= "number"
			or index % 1 ~= 0
			or index < 1
			or index > #value
			or typeof(option) ~= "string"
			or #option == 0
			or #option > 32
			or seen[option]
		then
			return nil, "invalid_mode_options"
		end
		seen[option] = true
		options[index] = option
	end
	if #options ~= #value then
		return nil, "invalid_mode_options"
	end
	return options, nil
end

local function copyModeSelection(value: any): (ModeSelection?, string?)
	if typeof(value) ~= "table" then
		return nil, "invalid_mode_selection"
	end
	if value.strategy == "Vote" then
		local options, optionsError = copyOptions(value.options)
		if not options then
			return nil, optionsError
		end
		return { strategy = "Vote" :: "Vote", options = options }, nil
	end
	if value.strategy == "Fixed" then
		if not validKey(value.modeId) then
			return nil, "invalid_mode_selection"
		end
		return { strategy = "Fixed" :: "Fixed", modeId = value.modeId }, nil
	end
	return nil, "invalid_mode_selection"
end

local function copyMembers(value: any): ({ number }?, string?)
	if typeof(value) ~= "table" or #value == 0 or #value > 16 then
		return nil, "invalid_party_members"
	end
	local result = {}
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
			return nil, "invalid_party_members"
		end
		seen[userId] = true
		result[index] = userId
	end
	if #result ~= #value then
		return nil, "invalid_party_members"
	end
	return result, nil
end

local function partyFor(matchRecord: any, partyId: string): PartyContext?
	for _, party in matchRecord.parties or {} do
		if party.partyId == partyId and typeof(party.leaderUserId) == "number" then
			return {
				leaderUserId = party.leaderUserId,
				memberUserIds = table.clone(party.memberUserIds),
			}
		end
	end
	return nil
end

function TeleportPayload.build(matchRecord: any, partyId: string): Payload
	local selection, selectionError = copyModeSelection(matchRecord.modeSelection)
	assert(selection, `[TeleportPayload] match record has an invalid mode selection ({selectionError})`)
	assert(validKey(matchRecord.queueId), "[TeleportPayload] match record must name its queue")
	return {
		schemaVersion = TeleportPayload.SchemaVersion,
		matchId = matchRecord.matchId,
		partyId = partyId,
		queueId = matchRecord.queueId,
		expectedPlayerCount = #matchRecord.expectedUserIds,
		modeSelection = selection,
		party = partyFor(matchRecord, partyId),
	}
end

function TeleportPayload.parse(value: any): (Payload?, string?)
	if typeof(value) ~= "table" then
		return nil, "missing_payload"
	end
	if value.schemaVersion ~= TeleportPayload.SchemaVersion then
		return nil, "unsupported_schema"
	end
	if not validId(value.matchId) or not validId(value.partyId) then
		return nil, "invalid_identity"
	end
	if not validKey(value.queueId) then
		return nil, "invalid_queue"
	end
	if
		typeof(value.expectedPlayerCount) ~= "number"
		or value.expectedPlayerCount % 1 ~= 0
		or value.expectedPlayerCount < 1
		or value.expectedPlayerCount > 100
	then
		return nil, "invalid_player_count"
	end

	local selection, selectionError = copyModeSelection(value.modeSelection)
	if not selection then
		return nil, selectionError
	end

	local party = nil
	if value.party ~= nil then
		if
			typeof(value.party) ~= "table"
			or typeof(value.party.leaderUserId) ~= "number"
			or value.party.leaderUserId % 1 ~= 0
			or value.party.leaderUserId <= 0
		then
			return nil, "invalid_party"
		end
		local members, membersError = copyMembers(value.party.memberUserIds)
		if not members or not table.find(members, value.party.leaderUserId) then
			return nil, membersError or "invalid_party_leader"
		end
		party = {
			leaderUserId = value.party.leaderUserId,
			memberUserIds = members,
		}
	end

	return {
		schemaVersion = TeleportPayload.SchemaVersion,
		matchId = value.matchId,
		partyId = value.partyId,
		queueId = value.queueId,
		expectedPlayerCount = value.expectedPlayerCount,
		modeSelection = selection,
		party = party,
	},
		nil
end

return table.freeze(TeleportPayload)
