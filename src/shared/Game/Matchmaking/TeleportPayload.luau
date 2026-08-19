--!strict

local TeleportPayload = {}

TeleportPayload.SchemaVersion = 2

export type ModeSelection = {
	strategy: "Vote",
	options: { string },
}

export type Payload = {
	schemaVersion: number,
	matchId: string,
	partyId: string,
	expectedPlayerCount: number,
	modeSelection: ModeSelection,
}

local function validId(value: any): boolean
	return typeof(value) == "string" and #value > 0 and #value <= 100
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

function TeleportPayload.build(matchRecord: any, partyId: string): Payload
	return {
		schemaVersion = TeleportPayload.SchemaVersion,
		matchId = matchRecord.matchId,
		partyId = partyId,
		expectedPlayerCount = #matchRecord.expectedUserIds,
		modeSelection = {
			strategy = matchRecord.modeSelection.strategy,
			options = table.clone(matchRecord.modeSelection.options),
		},
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
	if
		typeof(value.expectedPlayerCount) ~= "number"
		or value.expectedPlayerCount % 1 ~= 0
		or value.expectedPlayerCount < 1
		or value.expectedPlayerCount > 100
	then
		return nil, "invalid_player_count"
	end
	if typeof(value.modeSelection) ~= "table" or value.modeSelection.strategy ~= "Vote" then
		return nil, "invalid_mode_selection"
	end

	local options, optionsError = copyOptions(value.modeSelection.options)
	if not options then
		return nil, optionsError
	end

	return {
		schemaVersion = TeleportPayload.SchemaVersion,
		matchId = value.matchId,
		partyId = value.partyId,
		expectedPlayerCount = value.expectedPlayerCount,
		modeSelection = {
			strategy = "Vote",
			options = options,
		},
	},
		nil
end

return table.freeze(TeleportPayload)
