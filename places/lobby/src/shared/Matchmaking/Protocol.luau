local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)

local Protocol = {}

Protocol.Actions = table.freeze({
	GetSnapshot = "GetSnapshot",
	JoinByCode = "JoinByCode",
	KickMember = "KickMember",
	LeaveParty = "LeaveParty",
	SetMode = "SetMode",
	StartMatchmaking = "StartMatchmaking",
	CancelMatchmaking = "CancelMatchmaking",
})

Protocol.Errors = table.freeze({
	ArenaNotConfigured = "arena_not_configured",
	Busy = "busy",
	Internal = "internal_error",
	InvalidCode = "invalid_code",
	InvalidRequest = "invalid_request",
	MatchForming = "match_forming",
	NotFound = "party_not_found",
	NotLeader = "not_party_leader",
	NotReady = "party_not_ready",
	PartyFull = "party_full",
	RateLimited = "rate_limited",
	TeleportFailed = "teleport_failed",
})

local validModes = {}
for _, mode in Config.GameModes do
	validModes[mode] = true
end

function Protocol.isMode(value)
	return typeof(value) == "string" and validModes[value] == true
end

function Protocol.normalizeCode(value)
	if typeof(value) ~= "string" or #value > 16 then
		return nil
	end

	local normalized = string.gsub(value, "[%s%-]", "")
	if string.match(normalized, "^%d%d%d%d%d%d$") == nil then
		return nil
	end

	return normalized
end

function Protocol.validateRequest(_player, action, payload)
	if typeof(action) ~= "string" then
		return false, Protocol.Errors.InvalidRequest
	end

	if
		action == Protocol.Actions.GetSnapshot
		or action == Protocol.Actions.LeaveParty
		or action == Protocol.Actions.StartMatchmaking
		or action == Protocol.Actions.CancelMatchmaking
	then
		return payload == nil, Protocol.Errors.InvalidRequest
	end

	if action == Protocol.Actions.JoinByCode then
		return typeof(payload) == "table" and Protocol.normalizeCode(payload.code) ~= nil, Protocol.Errors.InvalidCode
	end

	if action == Protocol.Actions.KickMember then
		return typeof(payload) == "table"
			and typeof(payload.targetUserId) == "number"
			and payload.targetUserId ~= 0
			and payload.targetUserId % 1 == 0,
			Protocol.Errors.InvalidRequest
	end

	if action == Protocol.Actions.SetMode then
		return typeof(payload) == "table" and Protocol.isMode(payload.mode), Protocol.Errors.InvalidRequest
	end

	return false, Protocol.Errors.InvalidRequest
end

function Protocol.success(snapshot)
	return {
		ok = true,
		snapshot = snapshot,
	}
end

function Protocol.failure(code)
	return {
		ok = false,
		error = code,
	}
end

function Protocol.partyMessage(party, reason, actorUserId)
	return {
		protocolVersion = Config.ProtocolVersion,
		messageId = HttpService:GenerateGUID(false),
		partyId = party.partyId,
		revision = party.revision,
		kind = "StateChanged",
		actorUserId = actorUserId,
		sentAt = os.time(),
		data = {
			reason = reason,
		},
	}
end

function Protocol.deletedMessage(partyId, revision, actorUserId)
	return {
		protocolVersion = Config.ProtocolVersion,
		messageId = HttpService:GenerateGUID(false),
		partyId = partyId,
		revision = revision,
		kind = "PartyDeleted",
		actorUserId = actorUserId,
		sentAt = os.time(),
		data = {},
	}
end

function Protocol.isPartyMessage(value, partyId)
	return typeof(value) == "table"
		and value.protocolVersion == Config.ProtocolVersion
		and value.partyId == partyId
		and typeof(value.revision) == "number"
		and (value.kind == "StateChanged" or value.kind == "PartyDeleted")
end

function Protocol.inviteData(partyId, inviterUserId)
	return HttpService:JSONEncode({
		version = Config.ProtocolVersion,
		partyId = partyId,
		inviterUserId = inviterUserId,
	})
end

function Protocol.decodeInviteData(value)
	if typeof(value) ~= "string" or value == "" or #value > 200 then
		return nil
	end

	local success, decoded = pcall(HttpService.JSONDecode, HttpService, value)
	if
		not success
		or typeof(decoded) ~= "table"
		or decoded.version ~= Config.ProtocolVersion
		or typeof(decoded.partyId) ~= "string"
		or typeof(decoded.inviterUserId) ~= "number"
	then
		return nil
	end

	return decoded
end

return table.freeze(Protocol)
