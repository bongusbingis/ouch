local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Matchmaking.Config)
local PartyModel = require(script.Parent.PartyModel)

local MatchmakerService = {}
MatchmakerService.__index = MatchmakerService
local random = Random.new()

local function memberIds(party)
	local ids = {}
	for _, member in party.members do
		table.insert(ids, member.userId)
	end

	return ids
end

local function brDistanceLimit(waitTime)
	local progress = math.clamp(waitTime / Config.MatchMaximumWait, 0, 1)
	return math.min(Config.PartyMaxPlayers - 1, math.floor(progress * Config.PartyMaxPlayers))
end

function MatchmakerService.new(partyRepository, queueRepository, matchRepository, teleportCoordinator, onChanged)
	return setmetatable({
		_partyRepository = partyRepository,
		_queueRepository = queueRepository,
		_matchRepository = matchRepository,
		_teleportCoordinator = teleportCoordinator,
		_onChanged = onChanged,
		_running = {},
		_nextLeaseAttempt = {},
	}, MatchmakerService)
end

function MatchmakerService:_releaseClaim(party, reason)
	local released = self._partyRepository:UpdateParty(party.partyId, function(current)
		if
			not current
			or current.phase ~= "Claimed"
			or not current.claim
			or current.claim.claimId ~= party.claim.claimId
		then
			return nil
		end

		local nextParty = PartyModel.clone(current)
		nextParty.phase = "Queued"
		nextParty.claim = nil
		nextParty.matchId = nil
		return PartyModel.touch(nextParty, os.time())
	end)

	if released then
		self._onChanged(released, reason, 0)
	end
	return released
end

function MatchmakerService:_assignClaim(party, matchId)
	return self._partyRepository:UpdateParty(party.partyId, function(current)
		if not current or current.phase ~= "Claimed" or not current.claim or current.claim.claimId ~= matchId then
			return nil
		end

		local nextParty = PartyModel.clone(current)
		nextParty.phase = "Assigned"
		nextParty.claim = nil
		nextParty.matchId = matchId
		return PartyModel.touch(nextParty, os.time())
	end)
end

function MatchmakerService:_recoverClaim(party)
	local matchRecord, matchError = self._matchRepository:GetMatch(party.claim.claimId)
	if matchError then
		return
	end
	if matchRecord and self._matchRepository:ContainsParty(matchRecord, party.partyId) then
		local assigned = self:_assignClaim(party, matchRecord.matchId)
		if assigned then
			self._queueRepository:Remove(assigned.queueTicket.mode, assigned.partyId)
			self._onChanged(assigned, "MatchAssigned", 0)
		end
		return
	end

	if party.claim.expiresAt <= os.time() then
		self:_releaseClaim(party, "ClaimExpired")
	end
end

function MatchmakerService:_readValidCandidates(mode)
	local items = self._queueRepository:GetCandidates(mode)
	if not items then
		return {}
	end

	local candidates = {}
	for _, item in items do
		local ticket = item.value
		local party, partyError = self._partyRepository:GetParty(item.key)

		if partyError then
			continue
		elseif
			not party
			or not party.queueTicket
			or party.queueTicket.ticketId ~= ticket.ticketId
			or not party.leaseUntil
			or party.leaseUntil <= os.time()
			or (party.phase ~= "Claimed" and party.phase ~= "Queued")
			or party.selection.mode ~= mode
		then
			self._queueRepository:Remove(mode, item.key)
		elseif party.phase == "Claimed" and party.claim then
			self:_recoverClaim(party)
		else
			table.insert(candidates, {
				party = party,
				ticket = ticket,
			})
		end
	end

	return candidates
end

function MatchmakerService:_selectCandidates(mode, candidates)
	local seed = candidates[1]
	if not seed then
		return {}, 0, 0
	end

	local now = os.time()
	local oldestWait = math.max(0, now - seed.ticket.enqueuedAt)
	local allowedDistance = mode == "BR" and brDistanceLimit(oldestWait) or Config.PartyMaxPlayers
	local selected = {}
	local totalPlayers = 0

	for _, candidate in candidates do
		local compatible = mode ~= "BR"
			or math.abs(candidate.ticket.partySize - seed.ticket.partySize) <= allowedDistance
		local memberCount = #candidate.party.members

		if compatible and totalPlayers + memberCount <= Config.MatchTargetPlayers then
			table.insert(selected, candidate)
			totalPlayers += memberCount
		end
	end

	return selected, totalPlayers, oldestWait
end

function MatchmakerService:_claimCandidates(selected, matchId)
	local claimed = {}
	local totalPlayers = 0
	local now = os.time()

	for _, candidate in selected do
		local ticketId = candidate.ticket.ticketId
		local party = self._partyRepository:UpdateParty(candidate.party.partyId, function(current)
			if
				not current
				or current.phase ~= "Queued"
				or not current.queueTicket
				or current.queueTicket.ticketId ~= ticketId
			then
				return nil
			end

			local nextParty = PartyModel.clone(current)
			nextParty.phase = "Claimed"
			nextParty.claim = {
				claimId = matchId,
				expiresAt = now + Config.ClaimLifetime,
			}
			return PartyModel.touch(nextParty, now)
		end)

		if party then
			table.insert(claimed, party)
			totalPlayers += #party.members
		end
	end

	return claimed, totalPlayers
end

function MatchmakerService:_createMatch(mode, parties, accessCode, matchId)
	local matchParties = {}
	local expectedUserIds = {}

	for _, party in parties do
		local ids = memberIds(party)
		table.insert(matchParties, {
			partyId = party.partyId,
			memberUserIds = ids,
		})
		for _, userId in ids do
			table.insert(expectedUserIds, userId)
		end
	end

	return {
		schemaVersion = Config.ProtocolVersion,
		matchId = matchId,
		mode = mode,
		mapKey = Config.DefaultMapKey,
		arenaPlaceId = Config.ArenaPlaceId,
		targetPlayers = Config.MatchTargetPlayers,
		parties = matchParties,
		expectedUserIds = expectedUserIds,
		reservedServerAccessCode = accessCode,
		status = "Ready",
		createdAt = os.time(),
	}
end

function MatchmakerService:_process(mode)
	if os.clock() < (self._nextLeaseAttempt[mode] or 0) then
		return
	end
	if not self._matchRepository:AcquireLease(mode) then
		self._nextLeaseAttempt[mode] = os.clock() + random:NextNumber(3, 6)
		return
	end
	self._nextLeaseAttempt[mode] = 0

	local candidates = self:_readValidCandidates(mode)
	local selected, selectedPlayers, oldestWait = self:_selectCandidates(mode, candidates)
	if selectedPlayers < Config.MatchTargetPlayers and oldestWait < Config.MatchMaximumWait then
		return
	end

	local matchId = HttpService:GenerateGUID(false)
	local claimed, claimedPlayers = self:_claimCandidates(selected, matchId)
	if #claimed == 0 then
		return
	end
	if claimedPlayers < Config.MatchTargetPlayers and oldestWait < Config.MatchMaximumWait then
		for _, party in claimed do
			self:_releaseClaim(party, "ClaimReleased")
		end
		return
	end

	local accessCode = self._teleportCoordinator:ReserveServer()
	if not accessCode then
		for _, party in claimed do
			self:_releaseClaim(party, "ReservationFailed")
		end
		return
	end

	local matchRecord = self:_createMatch(mode, claimed, accessCode, matchId)
	local stored = self._matchRepository:SetMatch(matchRecord)
	if not stored then
		for _, party in claimed do
			self:_releaseClaim(party, "MatchStoreFailed")
		end
		return
	end

	for _, party in claimed do
		local assigned = self:_assignClaim(party, matchId)
		if assigned then
			self._queueRepository:Remove(mode, assigned.partyId)
			self._onChanged(assigned, "MatchAssigned", 0)
		end
	end
end

function MatchmakerService:Tick(mode)
	if self._running[mode] then
		return
	end

	self._running[mode] = true
	local success, message = xpcall(function()
		self:_process(mode)
	end, debug.traceback)
	self._running[mode] = nil

	if not success then
		warn(("[MatchmakerService] %s"):format(message))
	end
end

return MatchmakerService
