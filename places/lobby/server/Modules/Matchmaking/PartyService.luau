-- Description: Owns lobby party behavior end to end: request handling and validation, cross-server party state, member appearance, queue toggling, analytics funnels, teleport hand-off, and restoring parties returning from the arena.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))
local Loading = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Loading"))
local DevSoloPlay = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Matchmaking")
		:WaitForChild("DevSoloPlay")
)
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Protocol"))
local ReturnPayload = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Matchmaking")
		:WaitForChild("ReturnPayload")
)
local ReturnPartyPolicy = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Matchmaking")
		:WaitForChild("ReturnPartyPolicy")
)
local ReturnQueuePolicy = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Matchmaking")
		:WaitForChild("ReturnQueuePolicy")
)
local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local AnalyticsService = require(script.Parent.Parent.AnalyticsService)
local PartyModel = require(script.Parent.PartyModel)

local PartyService = {}
PartyService.__index = PartyService

local APPEARANCE_ATTRIBUTES = { "Equip_CharacterColor", "Equip_CostumeAssets" }

function PartyService.new(
	partyRepository,
	queueRepository,
	matchRepository,
	partyBus,
	teleportCoordinator,
	banRepository,
	runtime
)
	local self = setmetatable({
		_players = if runtime and runtime.players then runtime.players else Players,
		_lobbyGatherCoordinator = runtime and runtime.lobbyGatherCoordinator,
		_partyRepository = partyRepository,
		_queueRepository = queueRepository,
		_matchRepository = matchRepository,
		_partyBus = partyBus,
		_teleportCoordinator = teleportCoordinator,
		_banRepository = banRepository,
		_localPartyByUser = {},
		_localPlayersByParty = {},
		_cache = {},
		_busy = {},
		_initializing = {},
		_teleportDispatching = {},
		_teleportPresentationReady = {},
		_appearanceConnections = {},
		_appearanceRevisions = {},
		_joinCodeFailures = {},
		_queueChangedHandler = nil,
		_destroyed = false,
	}, PartyService)

	self._busCallback = function(message)
		self:_onBusMessage(message)
	end

	return self
end

function PartyService:SetQueueChangedHandler(handler)
	self._queueChangedHandler = handler
end

function PartyService:_sendSnapshot(player, party, reason)
	Network.fire("PartyPacket", player, {
		kind = "Snapshot",
		revision = party.revision,
		reason = reason,
		snapshot = PartyModel.toSnapshot(party),
		serverTime = os.time(),
	})
end

function PartyService:_sendError(player, errorCode)
	Network.fire("PartyPacket", player, {
		kind = "Error",
		error = errorCode,
	})
end

function PartyService:_getLocalPlayers(partyId)
	local partyPlayers = self._localPlayersByParty[partyId]
	local players = {}
	if not partyPlayers then
		return players
	end

	for _, player in partyPlayers do
		if player.Parent == self._players then
			table.insert(players, player)
		end
	end

	return players
end

function PartyService:_reportFunnel(partyId, stepKey, fields)
	local step = AnalyticsConfig.MatchmakingFunnelSteps[stepKey]
	for _, player in self:_getLocalPlayers(partyId) do
		AnalyticsService.logFunnelStep(player, AnalyticsConfig.Funnels.Matchmaking, step.step, step.name, fields)
	end
end

function PartyService:_reportEvent(partyId, eventName, fields)
	for _, player in self:_getLocalPlayers(partyId) do
		AnalyticsService.logCustomEvent(player, eventName, 1, fields)
	end
end

function PartyService:_maybeTeleport(party)
	if not party.matchId then
		return
	end

	if party.phase == "Assigned" then
		self:_reportFunnel(party.partyId, "Matched", { matchId = party.matchId })
		task.spawn(function()
			local updated = self._partyRepository:UpdateParty(party.partyId, function(current)
				if not current or current.phase ~= "Assigned" or current.matchId ~= party.matchId then
					return nil
				end

				local nextParty = PartyModel.clone(current)
				nextParty.phase = "Teleporting"
				return PartyModel.touch(nextParty, os.time())
			end)

			if updated then
				self:NotifyCommitted(updated, "Teleporting", 0)
			end
		end)
		return
	end

	if party.phase ~= "Teleporting" or self._teleportDispatching[party.partyId] then
		return
	end

	local partyPlayers = self:_getLocalPlayers(party.partyId)
	if #partyPlayers == 0 then
		return
	end

	self._teleportDispatching[party.partyId] = true
	task.spawn(function()
		local presentationDeadline = os.clock() + Loading.TeleportPresentationFallbackSeconds
		while not self._destroyed and os.clock() < presentationDeadline do
			local allPresented = true
			for _, player in self:_getLocalPlayers(party.partyId) do
				if not self._teleportPresentationReady[player.UserId] then
					allPresented = false
					break
				end
			end
			if allPresented then
				break
			end
			task.wait(0.1)
		end

		local current = self._cache[party.partyId]
		if self._destroyed or current == nil or current.phase ~= "Teleporting" or current.matchId ~= party.matchId then
			self._teleportDispatching[party.partyId] = nil
			return
		end

		local currentPlayers = {}
		for _, player in self:_getLocalPlayers(party.partyId) do
			-- An in-flight lobby transfer must finish/fail before starting the arena transfer.
			if not self._lobbyGatherCoordinator or not self._lobbyGatherCoordinator:IsGathering(player) then
				table.insert(currentPlayers, player)
			end
		end
		if #currentPlayers == 0 then
			self._teleportDispatching[party.partyId] = nil
			return
		end
		self:_reportFunnel(party.partyId, "Teleporting", { matchId = party.matchId })
		self._teleportCoordinator:TeleportParty(party.matchId, party.partyId, currentPlayers)
		self._teleportDispatching[party.partyId] = nil
	end)
end

function PartyService:HandleTeleportPresentationReady(player)
	if player.Parent == self._players then
		self._teleportPresentationReady[player.UserId] = true
		player:SetAttribute("TeleportPresentationReady", true)
	end
end

function PartyService:_maybeGatherLobby(party)
	if not self._lobbyGatherCoordinator or party.phase ~= "Lobby" or #party.members < 2 then
		return
	end
	for _, player in self:_getLocalPlayers(party.partyId) do
		task.spawn(function()
			self._lobbyGatherCoordinator:Consider(player, party.partyId, function()
				local current = self._cache[party.partyId]
				return not self._destroyed
					and self._localPartyByUser[player.UserId] == party.partyId
					and current ~= nil
					and current.phase == "Lobby"
			end, function()
				return self._teleportCoordinator:IsTeleporting(player)
			end)
		end)
	end
end

function PartyService:_applyParty(party, reason)
	local cached = self._cache[party.partyId]
	if cached and cached.revision >= party.revision then
		self:_maybeTeleport(party)
		self:_maybeGatherLobby(cached)
		return false
	end

	self._cache[party.partyId] = party
	for _, player in self:_getLocalPlayers(party.partyId) do
		local removalHandledLocally = reason == "MemberLeft" or reason == "ServerClosing"
		if not removalHandledLocally and not PartyModel.hasMember(party, player.UserId) then
			task.spawn(self._moveMemberToSoloParty, self, player, party.partyId)
		else
			self:_sendSnapshot(player, party, reason)
		end
	end
	self:_maybeTeleport(party)
	self:_maybeGatherLobby(party)
	return true
end

function PartyService:NotifyCommitted(party, reason, actorUserId)
	self:_applyParty(party, reason)
	task.spawn(function()
		self._partyBus:Publish(party, reason, actorUserId)
	end)
end

function PartyService:_detachFromLocalParty(player)
	local partyId = self._localPartyByUser[player.UserId]
	if not partyId then
		return
	end

	local partyPlayers = self._localPlayersByParty[partyId]
	if partyPlayers then
		partyPlayers[player.UserId] = nil
		if next(partyPlayers) == nil then
			self._localPlayersByParty[partyId] = nil
			self._cache[partyId] = nil
		end
	end

	self._localPartyByUser[player.UserId] = nil
	self._partyBus:Release(partyId)
end

function PartyService:_characterColorId(player)
	local itemId = player:GetAttribute("Equip_CharacterColor")
	return typeof(itemId) == "string" and itemId or ""
end

function PartyService:_costumeId(player)
	local itemId = player:GetAttribute("Equip_CostumeAssets")
	return typeof(itemId) == "string" and itemId or ""
end

function PartyService:_watchAppearance(player)
	local connections = {}
	for _, attribute in APPEARANCE_ATTRIBUTES do
		table.insert(
			connections,
			player:GetAttributeChangedSignal(attribute):Connect(function()
				self:_scheduleMemberAppearanceSync(player)
			end)
		)
	end
	return {
		Disconnect = function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end,
	}
end

function PartyService:_syncMemberAppearance(player, revision)
	if self._destroyed or player.Parent ~= self._players or self._appearanceRevisions[player.UserId] ~= revision then
		return
	end

	local partyId = self._localPartyByUser[player.UserId]
	if not partyId then
		return
	end
	local colorId, costumeId = self:_characterColorId(player), self:_costumeId(player)
	local updated = self._partyRepository:UpdateParty(partyId, function(current)
		if
			not current
			or self._localPartyByUser[player.UserId] ~= partyId
			or self._appearanceRevisions[player.UserId] ~= revision
		then
			return nil
		end

		local nextParty
		for index, member in current.members do
			if member.userId == player.UserId then
				if member.characterColorId == colorId and (member.costumeId or "") == costumeId then
					return nil
				end
				nextParty = PartyModel.clone(current)
				nextParty.members[index].characterColorId = colorId
				nextParty.members[index].costumeId = costumeId
				break
			end
		end
		if not nextParty then
			return nil
		end
		return PartyModel.touch(nextParty, os.time())
	end)

	if updated and self._appearanceRevisions[player.UserId] == revision then
		self:NotifyCommitted(updated, "MemberCosmeticChanged", player.UserId)
	end
end

function PartyService:_scheduleMemberAppearanceSync(player)
	local userId = player.UserId
	local revision = (self._appearanceRevisions[userId] or 0) + 1
	self._appearanceRevisions[userId] = revision
	task.spawn(function()
		self:_syncMemberAppearance(player, revision)
	end)
end

function PartyService:_attach(player, party, reason)
	local currentPartyId = self._localPartyByUser[player.UserId]
	if currentPartyId and currentPartyId ~= party.partyId then
		self:_detachFromLocalParty(player)
	elseif currentPartyId == party.partyId then
		self:_sendSnapshot(player, party, reason)
		self:_scheduleMemberAppearanceSync(player)
		return
	end

	self._localPartyByUser[player.UserId] = party.partyId
	self._localPlayersByParty[party.partyId] = self._localPlayersByParty[party.partyId] or {}
	self._localPlayersByParty[party.partyId][player.UserId] = player
	self._partyBus:Acquire(party.partyId, self._busCallback)

	local applied = self:_applyParty(party, reason)
	if not applied then
		self:_sendSnapshot(player, party, reason)
	end
	self:_scheduleMemberAppearanceSync(player)
end

function PartyService:_moveMemberToSoloParty(player, previousPartyId, reason)
	local userId = player.UserId
	if
		player.Parent ~= self._players
		or self._localPartyByUser[userId] ~= previousPartyId
		or self._initializing[userId]
	then
		return
	end

	self._initializing[userId] = true
	local success, message = xpcall(function()
		self:_detachFromLocalParty(player)
		self._partyRepository:RemoveUserParty(userId, previousPartyId)

		local party, createError =
			self._partyRepository:CreateParty(userId, self:_characterColorId(player), self:_costumeId(player))
		if not party then
			error(("Could not create replacement party for %d: %s"):format(userId, tostring(createError)))
		end

		if player.Parent ~= self._players then
			self:_removeMemberFromParty(userId, party.partyId, "MemberLeft", true)
			return
		end

		self:_attach(player, party, reason or "MemberKicked")
	end, debug.traceback)
	self._initializing[userId] = nil

	if not success then
		warn(("[PartyService] %s"):format(message))
		if player.Parent == self._players then
			self:_sendError(player, Protocol.Errors.Internal)
		end
	end
end

function PartyService:_onBusMessage(message)
	local cached = self._cache[message.partyId]
	if cached and cached.revision >= message.revision then
		return
	end

	task.spawn(function()
		local party = self._partyRepository:GetParty(message.partyId)
		if party then
			self:_applyParty(party, message.data.reason or message.kind)
		elseif message.kind == "PartyDeleted" then
			self:_recoverMissingParty(message.partyId)
		end
	end)
end

function PartyService:_removeMemberFromParty(userId, partyId, reason, removeIndex)
	local removedTicket
	local updated = self._partyRepository:UpdateParty(partyId, function(current)
		if not current or not PartyModel.hasMember(current, userId) then
			return nil
		end
		if current.phase == "Claimed" or current.phase == "Assigned" or current.phase == "Teleporting" then
			return nil
		end

		local nextParty = PartyModel.clone(current)
		removedTicket = nextParty.queueTicket and table.clone(nextParty.queueTicket) or nil
		PartyModel.removeMember(nextParty, userId)
		if nextParty.phase == "Queued" then
			PartyModel.returnToLobby(nextParty)
		end

		return PartyModel.touch(nextParty, os.time())
	end)

	if not updated then
		return nil
	end
	if removeIndex then
		self._partyRepository:RemoveUserParty(userId, partyId)
	end

	if removedTicket then
		self._queueRepository:Remove(partyId)
	end

	if #updated.members == 0 then
		self._partyRepository:DeleteParty(updated)
		self._partyBus:PublishDeleted(updated.partyId, updated.revision, userId)
		return updated
	end

	self:NotifyCommitted(updated, reason, userId)
	return updated
end

function PartyService:_rollbackJoinedMember(partyId, userId)
	local updated = self._partyRepository:UpdateParty(partyId, function(current)
		if not current or not PartyModel.hasMember(current, userId) then
			return nil
		end

		local nextParty = PartyModel.clone(current)
		PartyModel.removeMember(nextParty, userId)
		return PartyModel.touch(nextParty, os.time())
	end)

	if updated then
		self:NotifyCommitted(updated, "JoinRolledBack", userId)
	end
end

function PartyService:_joinTarget(player, target, requireFriendAccess)
	local userId = player.UserId
	local alreadyMember = false
	local updated = self._partyRepository:UpdateParty(target.partyId, function(current)
		if
			not current
			or current.leaderUserId == 0
			or current.phase ~= "Lobby"
			or not current.leaseUntil
			or current.leaseUntil <= os.time()
		then
			return nil
		end
		if requireFriendAccess and not current.allowFriendJoins then
			return nil
		end
		if PartyModel.hasMember(current, userId) then
			alreadyMember = true
			return current
		end
		if #current.members >= Config.PartyMaxPlayers then
			return nil
		end

		local nextParty = PartyModel.clone(current)
		table.insert(nextParty.members, {
			userId = userId,
			joinedAt = os.time(),
			characterColorId = self:_characterColorId(player),
			costumeId = self:_costumeId(player),
		})
		return PartyModel.touch(nextParty, os.time())
	end)
	if not updated then
		return nil, #target.members >= Config.PartyMaxPlayers and Protocol.Errors.PartyFull or Protocol.Errors.NotFound
	end

	local previousPartyId = self._localPartyByUser[userId]
	if not previousPartyId then
		previousPartyId = self._partyRepository:GetUserPartyId(userId)
	end

	local indexed, indexError = self._partyRepository:SetUserParty(userId, updated.partyId)
	if not indexed then
		if not alreadyMember then
			self:_rollbackJoinedMember(updated.partyId, userId)
		end
		return nil, indexError
	end
	if player.Parent ~= self._players then
		if not alreadyMember then
			self:_rollbackJoinedMember(updated.partyId, userId)
		end
		self._partyRepository:RemoveUserParty(userId, updated.partyId)
		return nil, Protocol.Errors.NotReady
	end

	self:_detachFromLocalParty(player)
	self:_attach(player, updated, alreadyMember and "PartyRestored" or "MemberJoined")

	if previousPartyId and previousPartyId ~= updated.partyId then
		self:_removeMemberFromParty(userId, previousPartyId, "MemberLeft", false)
	end
	if not alreadyMember then
		self:NotifyCommitted(updated, "MemberJoined", userId)
	end

	return updated
end

function PartyService:_restoreReturningParty(player, returning)
	return self._partyRepository:UpdateParty(returning.partyId, function(current)
		local action = ReturnPartyPolicy.resolve(current, returning, player.UserId)
		if action == nil then
			return nil
		end
		if action == "Keep" then
			return current
		end

		local nextParty = PartyModel.clone(current)
		PartyModel.returnToLobby(nextParty)
		for _, member in current.members do
			if not table.find(returning.memberUserIds, member.userId) then
				PartyModel.removeMember(nextParty, member.userId)
			end
		end
		ReturnQueuePolicy.arm(nextParty, returning, os.time(), Config.ReturnQueueWaitSeconds)
		return PartyModel.touch(nextParty, os.time())
	end)
end

function PartyService:_separateReturningMember(player, returning)
	local separated = false
	local updated = self._partyRepository:UpdateParty(returning.partyId, function(current)
		if ReturnPartyPolicy.resolve(current, returning, player.UserId) ~= "Separate" then
			return nil
		end

		local nextParty = PartyModel.clone(current)
		PartyModel.removeMember(nextParty, player.UserId)
		separated = true
		return PartyModel.touch(nextParty, os.time())
	end)
	if not updated or not separated then
		return false
	end

	self._partyRepository:RemoveUserParty(player.UserId, returning.partyId)
	if #updated.members == 0 then
		self._partyRepository:DeleteParty(updated)
		self._partyBus:PublishDeleted(updated.partyId, updated.revision, player.UserId)
	else
		self:NotifyCommitted(updated, "MemberLeft", player.UserId)
	end
	return true
end

function PartyService:_resolveArrivalTarget(player)
	local function isFriend(userId)
		local success, result = pcall(player.IsFriendsWith, player, userId)
		return success and result
	end

	local joinData = player:GetJoinData()

	local returning = if joinData.SourcePlaceId == Config.ArenaPlaceId and joinData.SourceGameId == game.GameId
		then ReturnPayload.parse(joinData.TeleportData)
		else nil
	if returning and table.find(returning.memberUserIds, player.UserId) then
		if returning.returnMode == "Separate" then
			if not self:_separateReturningMember(player, returning) then
				warn(
					("[PartyService] Could not separate returning member %d from %s"):format(
						player.UserId,
						returning.partyId
					)
				)
			end
			return nil
		end
		local party = self:_restoreReturningParty(player, returning)
		if party then
			return party, false
		end
		for _, userId in returning.memberUserIds do
			if userId ~= player.UserId then
				local partyId = self._partyRepository:GetUserPartyId(userId)
				local rebuilt = partyId and self._partyRepository:GetParty(partyId)
				if
					rebuilt
					and rebuilt.lastReturnMatchId == returning.matchId
					and rebuilt.returnSourcePartyId == returning.partyId
				then
					return rebuilt, false
				end
			end
		end
		return nil, false, returning
	end

	local invite = Protocol.decodeInviteData(joinData.LaunchData)
	if invite and isFriend(invite.inviterUserId) then
		local party = self._partyRepository:GetParty(invite.partyId)
		if party and party.allowFriendJoins and PartyModel.hasMember(party, invite.inviterUserId) then
			return party, true
		end
	end

	if player.FollowUserId ~= 0 and isFriend(player.FollowUserId) then
		local partyId = self._partyRepository:GetUserPartyId(player.FollowUserId)
		if partyId then
			local party = self._partyRepository:GetParty(partyId)
			if party and party.allowFriendJoins and PartyModel.hasMember(party, player.FollowUserId) then
				return party, true
			end
		end
	end

	return nil
end

function PartyService:_initializePlayerUnlocked(player)
	if player.Parent ~= self._players then
		return
	end

	if self._lobbyGatherCoordinator then
		local handled, arrivalError = self._lobbyGatherCoordinator:RestoreArrival(player, function(party)
			self:_attach(player, party, "PartyRestored")
		end)
		if handled then
			if arrivalError then
				self:_sendError(player, Protocol.Errors.NotReady)
			end
			return
		end
	end

	local target, requireFriendAccess, returning = self:_resolveArrivalTarget(player)
	if target then
		local joined = self:_joinTarget(player, target, requireFriendAccess)
		if joined then
			return
		end
	end

	local previousPartyId = self._partyRepository:GetUserPartyId(player.UserId)
	if previousPartyId then
		self:_removeMemberFromParty(player.UserId, previousPartyId, "MemberLeft", true)
	end

	local party, partyError =
		self._partyRepository:CreateParty(player.UserId, self:_characterColorId(player), self:_costumeId(player))
	if not party then
		warn(("[PartyService] Failed to initialize %s: %s"):format(player.Name, tostring(partyError)))
		self:_sendError(player, Protocol.Errors.Internal)
		return
	end
	if player.Parent ~= self._players then
		self:_removeMemberFromParty(player.UserId, party.partyId, "MemberLeft", true)
		return
	end

	if returning and table.find(returning.memberUserIds, player.UserId) then
		local restored = self._partyRepository:UpdateParty(party.partyId, function(current)
			if not current or current.phase ~= "Lobby" then
				return nil
			end
			local nextParty = PartyModel.clone(current)
			ReturnQueuePolicy.arm(nextParty, returning, os.time(), Config.ReturnQueueWaitSeconds)
			return PartyModel.touch(nextParty, os.time())
		end)
		party = restored or party
	end
	self:_attach(player, party, "PartyCreated")
end

function PartyService:_initializePlayer(player)
	if self._initializing[player.UserId] or self._localPartyByUser[player.UserId] then
		return
	end

	self._initializing[player.UserId] = true
	local success, message = xpcall(function()
		self:_initializePlayerUnlocked(player)
	end, debug.traceback)
	self._initializing[player.UserId] = nil

	if not success then
		warn(("[PartyService] %s"):format(message))
		self:_sendError(player, Protocol.Errors.Internal)
	end
end

function PartyService:_partyForPlayer(player)
	local partyId = self._localPartyByUser[player.UserId]
	if not partyId then
		if player.Parent == self._players then
			task.spawn(function()
				self:_initializePlayer(player)
			end)
		end
		return nil
	end

	local party = self._cache[partyId]
	if party then
		return party
	end

	party = self._partyRepository:GetParty(partyId)
	if party then
		self:_applyParty(party, "Reconciled")
	end
	return party
end

function PartyService:_checkJoinCodeLockout(userId)
	local entry = self._joinCodeFailures[userId]
	if entry == nil then
		return true
	end
	if os.clock() < entry.lockedUntil then
		return false
	end
	if os.clock() >= entry.windowExpiresAt then
		self._joinCodeFailures[userId] = nil
	end
	return true
end

function PartyService:_recordJoinCodeFailure(userId)
	local entry = self._joinCodeFailures[userId]
	local now = os.clock()
	if entry == nil or now >= entry.windowExpiresAt then
		entry = { count = 0, windowExpiresAt = now + Config.JoinCodeLockoutSeconds, lockedUntil = 0 }
		self._joinCodeFailures[userId] = entry
	end
	entry.count += 1
	if entry.count >= Config.JoinCodeMaxFailures then
		entry.lockedUntil = now + Config.JoinCodeLockoutSeconds
		entry.windowExpiresAt = entry.lockedUntil
		entry.count = 0
	end
end

function PartyService:_joinByCode(player, payload)
	if not self:_checkJoinCodeLockout(player.UserId) then
		return Protocol.failure(Protocol.Errors.TooManyCodeAttempts)
	end

	local code = Protocol.normalizeCode(payload.code)
	local target = self._partyRepository:GetPartyByCode(code)
	if not target then
		self:_recordJoinCodeFailure(player.UserId)
		return Protocol.failure(Protocol.Errors.InvalidCode)
	end

	local party, joinError = self:_joinTarget(player, target, false)
	if not party then
		return Protocol.failure(joinError or Protocol.Errors.NotFound)
	end

	self._joinCodeFailures[player.UserId] = nil
	return Protocol.success(PartyModel.toSnapshot(party))
end

function PartyService:_leaveParty(player)
	local party = self:_partyForPlayer(player)
	if not party then
		return Protocol.failure(Protocol.Errors.NotReady)
	end
	if party.phase == "Claimed" or party.phase == "Assigned" or party.phase == "Teleporting" then
		return Protocol.failure(Protocol.Errors.MatchForming)
	end

	local removed = self:_removeMemberFromParty(player.UserId, party.partyId, "MemberLeft", true)
	if not removed then
		return Protocol.failure(Protocol.Errors.MatchForming)
	end
	self:_detachFromLocalParty(player)

	local newParty, createError =
		self._partyRepository:CreateParty(player.UserId, self:_characterColorId(player), self:_costumeId(player))
	if not newParty then
		return Protocol.failure(createError or Protocol.Errors.Internal)
	end

	self:_attach(player, newParty, "PartyCreated")
	return Protocol.success(PartyModel.toSnapshot(newParty))
end

function PartyService:_kickMember(player, payload)
	local party = self:_partyForPlayer(player)
	if not party then
		return Protocol.failure(Protocol.Errors.NotReady)
	end

	local targetUserId = payload.targetUserId
	local denial
	local removedTicket
	local updated = self._partyRepository:UpdateParty(party.partyId, function(current)
		if not current or not PartyModel.hasMember(current, player.UserId) then
			denial = Protocol.Errors.NotFound
			return nil
		end
		if current.leaderUserId ~= player.UserId then
			denial = Protocol.Errors.NotLeader
			return nil
		end
		if targetUserId == player.UserId or targetUserId == current.leaderUserId then
			denial = Protocol.Errors.InvalidRequest
			return nil
		end
		if not PartyModel.hasMember(current, targetUserId) then
			denial = Protocol.Errors.NotFound
			return nil
		end
		if current.phase == "Claimed" or current.phase == "Assigned" or current.phase == "Teleporting" then
			denial = Protocol.Errors.MatchForming
			return nil
		end

		local nextParty = PartyModel.clone(current)
		removedTicket = nextParty.queueTicket and table.clone(nextParty.queueTicket) or nil
		PartyModel.removeMember(nextParty, targetUserId)
		if nextParty.phase == "Queued" then
			PartyModel.returnToLobby(nextParty)
		end

		return PartyModel.touch(nextParty, os.time())
	end)
	if not updated then
		return Protocol.failure(denial or Protocol.Errors.Internal)
	end

	self._partyRepository:RemoveUserParty(targetUserId, updated.partyId)
	if removedTicket then
		self._queueRepository:Remove(updated.partyId)
	end

	self:NotifyCommitted(updated, "MemberKicked", player.UserId)
	return Protocol.success(PartyModel.toSnapshot(updated))
end

function PartyService:_localMemberPresence(partyId)
	local present = {}
	for _, member in self._localPlayersByParty[partyId] or {} do
		if member.Parent == self._players then
			present[member.UserId] = true
		end
	end
	return present
end

function PartyService:_startMatchmaking(player, returnMatchId)
	if Config.ArenaPlaceId <= 0 then
		return Protocol.failure(Protocol.Errors.ArenaNotConfigured)
	end

	local party = self:_partyForPlayer(player)
	if not party then
		return Protocol.failure(Protocol.Errors.NotReady)
	end
	if not PartyModel.hasMember(party, player.UserId) then
		return Protocol.failure(Protocol.Errors.NotFound)
	end
	if party.leaderUserId ~= player.UserId then
		return Protocol.failure(Protocol.Errors.NotLeader)
	end
	if party.phase ~= "Lobby" then
		return Protocol.failure(Protocol.Errors.MatchForming)
	end

	local checkedParty = self._partyRepository:GetParty(party.partyId)
	if not checkedParty then
		return Protocol.failure(Protocol.Errors.MatchmakingUnavailable)
	end
	if not PartyModel.hasMember(checkedParty, player.UserId) then
		return Protocol.failure(Protocol.Errors.NotFound)
	end
	if checkedParty.leaderUserId ~= player.UserId then
		return Protocol.failure(Protocol.Errors.NotLeader)
	end
	if checkedParty.phase ~= "Lobby" then
		return Protocol.failure(Protocol.Errors.MatchForming)
	end

	local checkedMemberIds = {}
	local checkedMemberSet = {}
	for _, member in checkedParty.members do
		table.insert(checkedMemberIds, member.userId)
		checkedMemberSet[member.userId] = true
	end

	local hasBannedMember = self._banRepository:HasBannedMember(checkedMemberIds, os.time())
	if hasBannedMember == true then
		return Protocol.failure(Protocol.Errors.Banned)
	elseif hasBannedMember ~= false then
		return Protocol.failure(Protocol.Errors.MatchmakingUnavailable)
	end

	local denial
	local updated = self._partyRepository:UpdateParty(party.partyId, function(current)
		if not current or not PartyModel.hasMember(current, player.UserId) then
			denial = Protocol.Errors.NotFound
			return nil
		end
		if current.leaderUserId ~= player.UserId then
			denial = Protocol.Errors.NotLeader
			return nil
		end
		if current.phase ~= "Lobby" then
			denial = Protocol.Errors.MatchForming
			return nil
		end
		if
			returnMatchId
			and (
				not current.returnQueue
				or current.returnQueue.matchId ~= returnMatchId
				or ReturnQueuePolicy.evaluate(current, self:_localMemberPresence(current.partyId), os.time())
					~= "Ready"
			)
		then
			denial = Protocol.Errors.NotReady
			return nil
		end
		if #current.members ~= #checkedMemberIds then
			denial = Protocol.Errors.MatchmakingUnavailable
			return nil
		end
		for _, member in current.members do
			if not checkedMemberSet[member.userId] then
				denial = Protocol.Errors.MatchmakingUnavailable
				return nil
			end
		end

		local now = os.time()
		local nextParty = PartyModel.clone(current)
		nextParty.phase = "Queued"
		nextParty.returnQueue = nil
		nextParty.queueTicket = {
			ticketId = HttpService:GenerateGUID(false),
			partyId = current.partyId,
			partySize = #current.members,
			enqueuedAt = DateTime.now().UnixTimestampMillis / 1000,
		}
		return PartyModel.touch(nextParty, now)
	end)
	if not updated then
		return Protocol.failure(denial or Protocol.Errors.Internal)
	end

	local enqueued = self._queueRepository:Enqueue(updated.queueTicket)
	if not enqueued then
		local rolledBack = self._partyRepository:UpdateParty(updated.partyId, function(current)
			if
				not current
				or current.phase ~= "Queued"
				or not current.queueTicket
				or current.queueTicket.ticketId ~= updated.queueTicket.ticketId
			then
				return nil
			end

			local nextParty = PartyModel.clone(current)
			PartyModel.returnToLobby(nextParty)
			return PartyModel.touch(nextParty, os.time())
		end)
		if rolledBack then
			self:NotifyCommitted(rolledBack, "QueueFailed", player.UserId)
		end
		return Protocol.failure(Protocol.Errors.Internal)
	end

	self:NotifyCommitted(updated, "MatchmakingStarted", player.UserId)
	self:_reportFunnel(updated.partyId, "Queued", { partySize = #updated.members })
	if self._queueChangedHandler then
		task.spawn(self._queueChangedHandler)
	end
	return Protocol.success(PartyModel.toSnapshot(updated))
end

function PartyService:_startDevSoloPlay(player)
	if Config.ArenaPlaceId <= 0 then
		return Protocol.failure(Protocol.Errors.ArenaNotConfigured)
	end
	if not DevSoloPlay.canUse(player) then
		return Protocol.failure(Protocol.Errors.NotDeveloper)
	end

	local party = self:_partyForPlayer(player)
	if not party then
		return Protocol.failure(Protocol.Errors.NotReady)
	end
	if not PartyModel.hasMember(party, player.UserId) then
		return Protocol.failure(Protocol.Errors.NotFound)
	end
	if party.leaderUserId ~= player.UserId then
		return Protocol.failure(Protocol.Errors.NotLeader)
	end
	if party.phase ~= "Lobby" or #party.members ~= 1 then
		return Protocol.failure(Protocol.Errors.MatchForming)
	end

	local checkedParty = self._partyRepository:GetParty(party.partyId)
	if not checkedParty then
		return Protocol.failure(Protocol.Errors.MatchmakingUnavailable)
	end
	if not DevSoloPlay.canUse(player) then
		return Protocol.failure(Protocol.Errors.NotDeveloper)
	end
	if not PartyModel.hasMember(checkedParty, player.UserId) then
		return Protocol.failure(Protocol.Errors.NotFound)
	end
	if checkedParty.leaderUserId ~= player.UserId then
		return Protocol.failure(Protocol.Errors.NotLeader)
	end
	if checkedParty.phase ~= "Lobby" or #checkedParty.members ~= 1 then
		return Protocol.failure(Protocol.Errors.MatchForming)
	end

	local accessCode, reserveError = self._teleportCoordinator:ReserveServer()
	if not accessCode then
		return Protocol.failure(reserveError or Protocol.Errors.Internal)
	end

	local matchId = HttpService:GenerateGUID(false)
	local matchRecord = {
		schemaVersion = Config.ProtocolVersion,
		matchId = matchId,
		modeSelection = {
			strategy = "Vote",
			options = table.clone(Config.ModeVoteOptions),
		},
		arenaPlaceId = Config.ArenaPlaceId,
		targetPlayers = 1,
		parties = {
			{
				partyId = party.partyId,
				leaderUserId = player.UserId,
				memberUserIds = { player.UserId },
			},
		},
		expectedUserIds = { player.UserId },
		reservedServerAccessCode = accessCode,
		status = "Ready",
		createdAt = os.time(),
	}

	local stored = self._matchRepository:SetMatch(matchRecord)
	if not stored then
		return Protocol.failure(Protocol.Errors.Internal)
	end

	local denial
	local updated = self._partyRepository:UpdateParty(party.partyId, function(current)
		if not current or not PartyModel.hasMember(current, player.UserId) then
			denial = Protocol.Errors.NotFound
			return nil
		end
		if current.leaderUserId ~= player.UserId then
			denial = Protocol.Errors.NotLeader
			return nil
		end
		if current.phase ~= "Lobby" or #current.members ~= 1 then
			denial = Protocol.Errors.MatchForming
			return nil
		end

		local nextParty = PartyModel.clone(current)
		nextParty.phase = "Assigned"
		nextParty.matchId = matchId
		return PartyModel.touch(nextParty, os.time())
	end)
	if not updated then
		self._matchRepository:RemoveMatch(matchId)
		return Protocol.failure(denial or Protocol.Errors.Internal)
	end

	self:NotifyCommitted(updated, "DevSoloPlayStarted", player.UserId)
	return Protocol.success(PartyModel.toSnapshot(updated))
end

function PartyService:_cancelMatchmaking(player)
	local party = self:_partyForPlayer(player)
	if not party then
		return Protocol.failure(Protocol.Errors.NotReady)
	end

	local denial
	local updated = self._partyRepository:UpdateParty(party.partyId, function(current)
		if not current or not PartyModel.hasMember(current, player.UserId) then
			denial = Protocol.Errors.NotFound
			return nil
		end
		if current.leaderUserId ~= player.UserId then
			denial = Protocol.Errors.NotLeader
			return nil
		end
		if current.phase == "Claimed" then
			denial = Protocol.Errors.MatchForming
			return nil
		end
		if current.phase == "Lobby" and current.returnQueue then
			local nextParty = PartyModel.clone(current)
			nextParty.returnQueue = nil
			return PartyModel.touch(nextParty, os.time())
		end
		if current.phase ~= "Queued" or not current.queueTicket then
			denial = Protocol.Errors.NotReady
			return nil
		end

		local nextParty = PartyModel.clone(current)
		PartyModel.returnToLobby(nextParty)
		return PartyModel.touch(nextParty, os.time())
	end)
	if not updated then
		return Protocol.failure(denial or Protocol.Errors.Internal)
	end

	self._queueRepository:Remove(updated.partyId)
	self:NotifyCommitted(updated, "MatchmakingCancelled", player.UserId)
	self:_reportEvent(updated.partyId, AnalyticsConfig.CustomEvents.MatchmakingCancelled, {
		partySize = #updated.members,
	})
	return Protocol.success(PartyModel.toSnapshot(updated))
end

function PartyService:_dispatchRequest(player, action, payload)
	if action == Protocol.Actions.GetSnapshot then
		local party = self:_partyForPlayer(player)
		return party and Protocol.success(PartyModel.toSnapshot(party)) or Protocol.failure(Protocol.Errors.NotReady)
	elseif action == Protocol.Actions.JoinByCode then
		return self:_joinByCode(player, payload)
	elseif action == Protocol.Actions.DevSoloPlay then
		return self:_startDevSoloPlay(player)
	elseif action == Protocol.Actions.KickMember then
		return self:_kickMember(player, payload)
	elseif action == Protocol.Actions.LeaveParty then
		return self:_leaveParty(player)
	elseif action == Protocol.Actions.StartMatchmaking then
		return self:_startMatchmaking(player)
	elseif action == Protocol.Actions.CancelMatchmaking then
		return self:_cancelMatchmaking(player)
	end

	return Protocol.failure(Protocol.Errors.InvalidRequest)
end

function PartyService:HandleRequest(player, action, payload)
	if
		action ~= Protocol.Actions.GetSnapshot
		and self._lobbyGatherCoordinator
		and self._lobbyGatherCoordinator:IsGathering(player)
	then
		return Protocol.failure(Protocol.Errors.Busy)
	end
	if self._busy[player.UserId] then
		return Protocol.failure(Protocol.Errors.Busy)
	end

	self._busy[player.UserId] = true
	local success, result = xpcall(function()
		return self:_dispatchRequest(player, action, payload)
	end, debug.traceback)
	self._busy[player.UserId] = nil

	if not success then
		warn(("[PartyService] %s"):format(result))
		return Protocol.failure(Protocol.Errors.Internal)
	end

	return result
end

function PartyService:HandleTeleportFailure(player)
	self:_sendError(player, Protocol.Errors.TeleportFailed)
	AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.MatchmakingTeleportFailed, 1)
	local partyId = self._localPartyByUser[player.UserId]
	if partyId then
		task.spawn(self._moveMemberToSoloParty, self, player, partyId, "TeleportFailed")
	end
end

function PartyService:HasLocalQueuedParty()
	for partyId in self._localPlayersByParty do
		local party = self._cache[partyId]
		if party and (party.phase == "Queued" or party.phase == "Claimed") and party.queueTicket then
			return true
		end
	end

	return false
end

function PartyService:_recoverMissingParty(partyId)
	local players = self:_getLocalPlayers(partyId)
	for _, player in players do
		self:_detachFromLocalParty(player)
		self._partyRepository:RemoveUserParty(player.UserId, partyId)
		local party =
			self._partyRepository:CreateParty(player.UserId, self:_characterColorId(player), self:_costumeId(player))
		if party then
			self:_attach(player, party, "PartyRecovered")
		else
			self:_sendError(player, Protocol.Errors.Internal)
		end
	end
end

function PartyService:_reconcile()
	for partyId in self._localPlayersByParty do
		self._partyBus:Ensure(partyId)
		local party, partyError = self._partyRepository:GetParty(partyId)
		if party then
			self:_applyParty(party, "Reconciled")
		elseif not partyError then
			self:_recoverMissingParty(partyId)
		end
	end
end

function PartyService:_heartbeat()
	for userId, partyId in self._localPartyByUser do
		self._partyRepository:SetUserParty(userId, partyId)
	end
end

function PartyService:_refreshParties()
	for partyId in self._localPlayersByParty do
		local party = self._partyRepository:RefreshParty(partyId)
		if party and party.phase == "Queued" and party.queueTicket then
			self._queueRepository:Refresh(party.queueTicket)
		end
	end
end

function PartyService:_sweepStaleMembers()
	for partyId in self._localPlayersByParty do
		local party, partyError = self._partyRepository:GetParty(partyId)
		if
			not partyError
			and party
			and party.phase ~= "Claimed"
			and party.phase ~= "Assigned"
			and party.phase ~= "Teleporting"
		then
			for _, member in party.members do
				local indexedPartyId, readError = self._partyRepository:GetUserPartyId(member.userId)
				if not readError and indexedPartyId ~= partyId then
					self:_removeMemberFromParty(member.userId, partyId, "MemberExpired", false)
				end
			end
		end
	end
end

function PartyService:_runLoop(interval, callback)
	task.spawn(function()
		while not self._destroyed do
			task.wait(interval)
			if not self._destroyed then
				local success, message = xpcall(callback, debug.traceback)
				if not success then
					warn(("[PartyService] %s"):format(message))
				end
			end
		end
	end)
end

function PartyService:_queueReturningParties()
	for partyId in self._localPlayersByParty do
		local party = self._cache[partyId]
		if not party or not party.returnQueue then
			continue
		end
		local decision = ReturnQueuePolicy.evaluate(party, self:_localMemberPresence(partyId), os.time())
		local leader = self._players:GetPlayerByUserId(party.leaderUserId)
		if decision == "Ready" and leader and not self._busy[leader.UserId] then
			self._busy[leader.UserId] = true
			local ok, response = xpcall(function()
				return self:_startMatchmaking(leader, party.returnQueue.matchId)
			end, debug.traceback)
			self._busy[leader.UserId] = nil
			if not ok or not response.ok then
				self:_sendError(leader, if ok then response.error else Protocol.Errors.Internal)
				decision = "Expired"
				if not ok then
					warn(("[PartyService] Return queue failed: %s"):format(response))
				end
			end
		end
		if decision == "Expired" then
			local updated = self._partyRepository:UpdateParty(partyId, function(current)
				if
					not current
					or not current.returnQueue
					or current.returnQueue.matchId ~= party.returnQueue.matchId
				then
					return nil
				end
				local nextParty = PartyModel.clone(current)
				nextParty.returnQueue = nil
				return PartyModel.touch(nextParty, os.time())
			end)
			if updated then
				self:NotifyCommitted(updated, "ReturnQueueInterrupted")
				for _, member in self._localPlayersByParty[partyId] or {} do
					self:_sendError(member, Protocol.Errors.MatchmakingUnavailable)
				end
			end
		end
	end
end

function PartyService:Start()
	self._players.PlayerAdded:Connect(function(player)
		self._appearanceConnections[player] = self:_watchAppearance(player)
		task.spawn(function()
			self:_initializePlayer(player)
		end)
	end)

	self._players.PlayerRemoving:Connect(function(player)
		self._teleportPresentationReady[player.UserId] = nil
		self._joinCodeFailures[player.UserId] = nil
		self._appearanceRevisions[player.UserId] = (self._appearanceRevisions[player.UserId] or 0) + 1
		local appearanceConnection = self._appearanceConnections[player]
		if appearanceConnection then
			appearanceConnection:Disconnect()
			self._appearanceConnections[player] = nil
		end
		local party = self:_partyForPlayer(player)
		local inMatchTransition = party
			and (party.phase == "Claimed" or party.phase == "Assigned" or party.phase == "Teleporting")
		local gathering = self._lobbyGatherCoordinator
			and self._lobbyGatherCoordinator:IsGathering(player, party and party.partyId)
		if
			not gathering
			and not self._teleportCoordinator:IsTeleporting(player)
			and not inMatchTransition
			and party
		then
			self:_removeMemberFromParty(player.UserId, party.partyId, "MemberLeft", true)
		end
		self:_detachFromLocalParty(player)
		self._teleportCoordinator:Clear(player)
		if self._lobbyGatherCoordinator then
			self._lobbyGatherCoordinator:Clear(player)
		end
	end)

	for _, player in self._players:GetPlayers() do
		self._appearanceConnections[player] = self:_watchAppearance(player)
		task.spawn(function()
			self:_initializePlayer(player)
		end)
	end

	self:_runLoop(Config.PartyReconcileInterval, function()
		self:_reconcile()
	end)
	self:_runLoop(Config.ReturnQueuePollSeconds, function()
		self:_queueReturningParties()
	end)
	self:_runLoop(Config.PresenceHeartbeatInterval, function()
		self:_heartbeat()
	end)
	self:_runLoop(Config.PartyRefreshInterval, function()
		self:_refreshParties()
	end)
	self:_runLoop(Config.StaleMemberSweepInterval, function()
		self:_sweepStaleMembers()
	end)
end

function PartyService:Shutdown()
	self._destroyed = true
	for player, connection in self._appearanceConnections do
		self._appearanceRevisions[player.UserId] = (self._appearanceRevisions[player.UserId] or 0) + 1
		connection:Disconnect()
	end
	table.clear(self._appearanceConnections)
	for _, player in self._players:GetPlayers() do
		local party = self:_partyForPlayer(player)
		local gathering = self._lobbyGatherCoordinator
			and self._lobbyGatherCoordinator:IsGathering(player, party and party.partyId)
		if party and not gathering and party.phase ~= "Assigned" and party.phase ~= "Teleporting" then
			self:_removeMemberFromParty(player.UserId, party.partyId, "ServerClosing", true)
		end
	end
	self._partyBus:Destroy()
	self._teleportCoordinator:Destroy()
	if self._lobbyGatherCoordinator then
		self._lobbyGatherCoordinator:Destroy()
	end
end

return PartyService
