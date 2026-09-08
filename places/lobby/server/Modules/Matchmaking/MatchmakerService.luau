-- Description: Runs the matchmaking tick: reads queued candidates, selects and claims a viable set under the population policy, reconciles stale claims, and creates the match record the teleport coordinator acts on.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))
local PopulationPolicy = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Matchmaking")
		:WaitForChild("PopulationPolicy")
)
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

function MatchmakerService.new(partyRepository, queueRepository, matchRepository, teleportCoordinator, onChanged)
	return setmetatable({
		_partyRepository = partyRepository,
		_queueRepository = queueRepository,
		_matchRepository = matchRepository,
		_teleportCoordinator = teleportCoordinator,
		_onChanged = onChanged,
		_running = false,
		_nextLeaseAttempt = 0,
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
			self._queueRepository:Remove(assigned.partyId)
			self._onChanged(assigned, "MatchAssigned", 0)
		end
		return
	end

	if party.claim.expiresAt <= os.time() then
		self:_releaseClaim(party, "ClaimExpired")
	end
end

function MatchmakerService:_readCandidates()
	local items = self._queueRepository:GetCandidates()
	if not items then
		return {}
	end

	local candidates = {}
	for _, item in items do
		local ticket = item.value
		if
			typeof(ticket) ~= "table"
			or ticket.partyId ~= item.key
			or typeof(ticket.ticketId) ~= "string"
			or typeof(ticket.partySize) ~= "number"
			or ticket.partySize % 1 ~= 0
			or ticket.partySize < Config.PartyMinPlayers
			or ticket.partySize > Config.PartyMaxPlayers
			or typeof(ticket.enqueuedAt) ~= "number"
		then
			self._queueRepository:Remove(item.key)
		else
			table.insert(candidates, {
				partyId = item.key,
				ticket = ticket,
			})
		end
	end

	return candidates
end

function MatchmakerService:_selectCandidates(candidates)
	local seed = candidates[1]
	if not seed then
		return {}, 0, 0
	end

	local now = DateTime.now().UnixTimestampMillis / 1000
	local oldestWait = math.max(0, now - seed.ticket.enqueuedAt)
	local selected = {}
	local totalPlayers = 0

	for _, candidate in candidates do
		local memberCount = candidate.ticket.partySize
		if totalPlayers + memberCount <= Config.MatchTargetPlayers then
			table.insert(selected, candidate)
			totalPlayers += memberCount
		end
	end

	return selected, totalPlayers, oldestWait
end

function MatchmakerService:_reconcileUnclaimedCandidate(candidate)
	local party, partyError = self._partyRepository:GetParty(candidate.partyId)
	if partyError then
		return
	end
	if
		not party
		or not party.queueTicket
		or party.queueTicket.ticketId ~= candidate.ticket.ticketId
		or not party.leaseUntil
		or party.leaseUntil <= os.time()
		or (party.phase ~= "Queued" and party.phase ~= "Claimed")
	then
		self._queueRepository:Remove(candidate.partyId)
	elseif party.phase == "Claimed" and party.claim then
		self:_recoverClaim(party)
	end
end

function MatchmakerService:_claimCandidates(selected, matchId)
	local claimed = {}
	local totalPlayers = 0
	local now = os.time()

	for _, candidate in selected do
		local ticketId = candidate.ticket.ticketId
		local party = self._partyRepository:UpdateParty(candidate.partyId, function(current)
			if
				not current
				or current.phase ~= "Queued"
				or not current.queueTicket
				or current.queueTicket.ticketId ~= ticketId
				or current.queueTicket.partySize ~= #current.members
				or not current.leaseUntil
				or current.leaseUntil <= now
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
		else
			self:_reconcileUnclaimedCandidate(candidate)
		end
	end

	return claimed, totalPlayers
end

function MatchmakerService:_createMatch(parties, accessCode, matchId)
	local matchParties = {}
	local expectedUserIds = {}

	for _, party in parties do
		local ids = memberIds(party)
		table.insert(matchParties, {
			partyId = party.partyId,
			leaderUserId = party.leaderUserId,
			memberUserIds = ids,
		})
		for _, userId in ids do
			table.insert(expectedUserIds, userId)
		end
	end

	return {
		schemaVersion = Config.ProtocolVersion,
		matchId = matchId,
		modeSelection = {
			strategy = "Vote",
			options = table.clone(Config.ModeVoteOptions),
		},
		arenaPlaceId = Config.ArenaPlaceId,
		targetPlayers = Config.MatchTargetPlayers,
		parties = matchParties,
		expectedUserIds = expectedUserIds,
		reservedServerAccessCode = accessCode,
		status = "Ready",
		createdAt = os.time(),
	}
end

function MatchmakerService:_process()
	local candidates = self:_readCandidates()
	local selected, selectedPlayers, oldestWait = self:_selectCandidates(candidates)
	local requiredPlayers =
		PopulationPolicy.requiredPlayers(Config.MatchPopulationExpansion, oldestWait, Config.MatchTargetPlayers)
	if selectedPlayers < requiredPlayers then
		return
	end

	local matchId = HttpService:GenerateGUID(false)
	local claimed, claimedPlayers = self:_claimCandidates(selected, matchId)
	if #claimed == 0 then
		return
	end
	if claimedPlayers < requiredPlayers then
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

	local matchRecord = self:_createMatch(claimed, accessCode, matchId)
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
			self._queueRepository:Remove(assigned.partyId)
			self._onChanged(assigned, "MatchAssigned", 0)
		end
	end
end

function MatchmakerService:Tick()
	if self._running or os.clock() < self._nextLeaseAttempt then
		return
	end

	self._running = true
	local leaseAcquired = false
	local success, message = xpcall(function()
		if not self._matchRepository:AcquireLease() then
			self._nextLeaseAttempt = os.clock() + random:NextNumber(3, 6)
			return
		end
		leaseAcquired = true
		self._nextLeaseAttempt = 0
		self:_process()
	end, debug.traceback)
	if leaseAcquired then
		self._matchRepository:ReleaseLease()
	end
	self._running = false

	if not success then
		warn(("[MatchmakerService] %s"):format(message))
	end
end

return MatchmakerService
