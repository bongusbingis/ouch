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

local function cloneModeSelection(selection)
	if selection.strategy == "Vote" then
		return { strategy = "Vote", options = table.clone(selection.options) }
	end
	return { strategy = "Fixed", modeId = selection.modeId }
end

function MatchmakerService.new(
	queueId,
	partyRepository,
	queueRepository,
	matchRepository,
	teleportCoordinator,
	onChanged
)
	local queueConfig = Config.Queues[queueId]
	assert(queueConfig, ("[MatchmakerService] unknown queue %q"):format(tostring(queueId)))

	return setmetatable({
		_queueId = queueId,
		_queueConfig = queueConfig,
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
			or ticket.queueId ~= self._queueId
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
		if totalPlayers + memberCount <= self._queueConfig.MatchTargetPlayers then
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

function MatchmakerService:_claimCandidates(candidates, matchId, deadline)
	local claimed = {}
	local totalPlayers = 0
	local oldestEnqueuedAt

	for index, candidate in candidates do
		if
			index > Config.QueueCandidateLimit
			or totalPlayers >= self._queueConfig.MatchTargetPlayers
			or os.clock() >= deadline
		then
			break
		end
		local remainingPlayers = self._queueConfig.MatchTargetPlayers - totalPlayers
		if candidate.ticket.partySize > remainingPlayers then
			continue
		end

		local ticketId = candidate.ticket.ticketId
		local party = self._partyRepository:UpdateParty(candidate.partyId, function(current)
			local now = os.time()
			if
				os.clock() >= deadline
				or not current
				or current.phase ~= "Queued"
				or not current.queueTicket
				or current.queueTicket.ticketId ~= ticketId
				or current.queueTicket.partySize ~= candidate.ticket.partySize
				or current.queueTicket.partySize ~= #current.members
				or #current.members > remainingPlayers
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
			oldestEnqueuedAt = math.min(oldestEnqueuedAt or party.queueTicket.enqueuedAt, party.queueTicket.enqueuedAt)
		elseif os.clock() < deadline then
			self:_reconcileUnclaimedCandidate(candidate)
		end
	end

	local oldestWait = if oldestEnqueuedAt
		then math.max(0, DateTime.now().UnixTimestampMillis / 1000 - oldestEnqueuedAt)
		else 0
	return claimed, totalPlayers, oldestWait
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
		queueId = self._queueId,
		modeSelection = cloneModeSelection(self._queueConfig.ModeSelection),
		arenaPlaceId = Config.ArenaPlaceId,
		targetPlayers = self._queueConfig.MatchTargetPlayers,
		parties = matchParties,
		expectedUserIds = expectedUserIds,
		reservedServerAccessCode = accessCode,
		status = "Ready",
		createdAt = os.time(),
	}
end

function MatchmakerService:_process(deadline)
	if os.clock() >= deadline then
		return
	end
	local candidates = self:_readCandidates()
	local _, selectedPlayers, oldestWait = self:_selectCandidates(candidates)
	local requiredPlayers = PopulationPolicy.requiredPlayers(
		self._queueConfig.MatchPopulationExpansion,
		oldestWait,
		self._queueConfig.MatchTargetPlayers,
		self._queueConfig.MatchMinPlayers,
		self._queueConfig.MatchMaxWaitSeconds
	)
	if selectedPlayers < requiredPlayers then
		return
	end

	local matchId = HttpService:GenerateGUID(false)
	local claimed, claimedPlayers, oldestClaimedWait = self:_claimCandidates(candidates, matchId, deadline)
	if #claimed == 0 then
		return
	end
	-- A stale or already claimed ticket must not relax the minimum for younger viable parties.
	requiredPlayers = PopulationPolicy.requiredPlayers(
		self._queueConfig.MatchPopulationExpansion,
		oldestClaimedWait,
		self._queueConfig.MatchTargetPlayers,
		self._queueConfig.MatchMinPlayers,
		self._queueConfig.MatchMaxWaitSeconds
	)
	if claimedPlayers < requiredPlayers or os.clock() >= deadline then
		for _, party in claimed do
			self:_releaseClaim(party, "ClaimReleased")
		end
		return
	end

	local accessCode = self._teleportCoordinator:ReserveServer()
	-- Reservation can outlive our worker lease. Do not publish a Ready record
	-- from that stale result; release only claims still carrying our token.
	local reservationExpired = os.clock() >= deadline
	if not accessCode or reservationExpired then
		for _, party in claimed do
			self:_releaseClaim(party, if reservationExpired then "ClaimReleased" else "ReservationFailed")
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
		-- Start before the yielding acquisition and allow for the lease's whole-second clock.
		-- This bounds new claim work; it is not a fence for a later yielding match-record write.
		local deadline = os.clock() + math.max(0, Config.WorkerLeaseLifetime - 1)
		if not self._matchRepository:AcquireLease(self._queueId) then
			self._nextLeaseAttempt = os.clock() + random:NextNumber(3, 6)
			return
		end
		leaseAcquired = true
		self._nextLeaseAttempt = 0
		self:_process(deadline)
	end, debug.traceback)
	if leaseAcquired then
		self._matchRepository:ReleaseLease(self._queueId)
	end
	self._running = false

	if not success then
		warn(("[MatchmakerService] %s"):format(message))
	end
end

return MatchmakerService
