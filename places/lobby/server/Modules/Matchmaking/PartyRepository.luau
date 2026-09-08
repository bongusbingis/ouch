-- Description: Persistence for parties in the shared memory store: creation with a claimed join code, atomic updates, code and user lookups, refresh, and deletion.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))
local CloudRetry = require(script.Parent.CloudRetry)

local PartyRepository = {}
PartyRepository.__index = PartyRepository

local random = Random.new()

local function mapName(suffix)
	return Config.MemoryStoreNamespace .. ":" .. suffix
end

function PartyRepository.new()
	return setmetatable({
		_partyMap = MemoryStoreService:GetHashMap(mapName("PartyById")),
		_codeMap = MemoryStoreService:GetHashMap(mapName("PartyByCode")),
		_userMap = MemoryStoreService:GetHashMap(mapName("PartyByUser")),
	}, PartyRepository)
end

function PartyRepository:GetParty(partyId)
	local success, value = CloudRetry.call("PartyRepository.GetParty", function()
		return self._partyMap:GetAsync(partyId)
	end)
	if not success then
		return nil, value
	end

	return value
end

function PartyRepository:UpdateParty(partyId, transform)
	local success, value = CloudRetry.call("PartyRepository.UpdateParty", function()
		return self._partyMap:UpdateAsync(partyId, transform, Config.PartyRecordLifetime)
	end)
	if not success then
		return nil, value
	end

	return value
end

function PartyRepository:_claimCode(partyId)
	for _ = 1, 50 do
		local code = string.format("%06d", random:NextInteger(0, 999999))
		local success, value = CloudRetry.call("PartyRepository.ClaimCode", function()
			return self._codeMap:UpdateAsync(code, function(current)
				if current ~= nil then
					return nil
				end

				return {
					partyId = partyId,
				}
			end, Config.PartyRecordLifetime)
		end)

		if success and value and value.partyId == partyId then
			return code
		end
	end

	return nil, "code_space_unavailable"
end

function PartyRepository:CreateParty(userId, characterColorId, costumeId)
	local partyId = HttpService:GenerateGUID(false)
	local joinCode, codeError = self:_claimCode(partyId)
	if not joinCode then
		return nil, codeError
	end

	local now = os.time()
	local party = {
		schemaVersion = Config.ProtocolVersion,
		partyId = partyId,
		joinCode = joinCode,
		revision = 1,
		leaderUserId = userId,
		members = {
			{
				userId = userId,
				joinedAt = now,
				characterColorId = characterColorId or "",
				costumeId = costumeId or "",
			},
		},
		allowFriendJoins = true,
		phase = "Lobby",
		queueTicket = nil,
		claim = nil,
		matchId = nil,
		leaseUntil = now + Config.PresenceLifetime,
		createdAt = now,
		updatedAt = now,
	}

	local success, value = CloudRetry.call("PartyRepository.CreateParty", function()
		return self._partyMap:SetAsync(partyId, party, Config.PartyRecordLifetime)
	end)
	if not success then
		CloudRetry.call("PartyRepository.ReleaseCode", function()
			return self._codeMap:RemoveAsync(joinCode)
		end)
		return nil, value
	end

	local indexed, indexError = self:SetUserParty(userId, partyId)
	if not indexed then
		self:DeleteParty(party)
		return nil, indexError
	end

	return party
end

function PartyRepository:GetPartyByCode(code)
	local success, index = CloudRetry.call("PartyRepository.GetPartyByCode", function()
		return self._codeMap:GetAsync(code)
	end)
	if not success then
		return nil, index
	end
	if not index then
		return nil
	end

	local party, partyError = self:GetParty(index.partyId)
	if partyError then
		return nil, partyError
	end
	if
		not party
		or party.joinCode ~= code
		or party.leaderUserId == 0
		or not party.leaseUntil
		or party.leaseUntil <= os.time()
	then
		return nil
	end

	return party
end

function PartyRepository:SetUserParty(userId, partyId)
	local success, value = CloudRetry.call("PartyRepository.SetUserParty", function()
		return self._userMap:SetAsync(tostring(userId), {
			partyId = partyId,
			jobId = game.JobId,
			refreshedAt = os.time(),
		}, Config.PresenceLifetime)
	end)

	return success, value
end

function PartyRepository:GetUserPartyId(userId)
	local success, value = CloudRetry.call("PartyRepository.GetUserPartyId", function()
		return self._userMap:GetAsync(tostring(userId))
	end)
	if not success then
		return nil, value
	end

	return value and value.partyId or nil
end

function PartyRepository:RemoveUserParty(userId, expectedPartyId)
	local success, value = CloudRetry.call("PartyRepository.RemoveUserParty", function()
		return self._userMap:UpdateAsync(tostring(userId), function(current)
			if not current or current.partyId ~= expectedPartyId then
				return nil
			end

			return {
				removed = true,
			}
		end, 1)
	end)

	return success, value
end

function PartyRepository:RefreshParty(partyId)
	local party, partyError = self:UpdateParty(partyId, function(current)
		if not current then
			return nil
		end

		local refreshed = table.clone(current)
		refreshed.leaseUntil = os.time() + Config.PresenceLifetime
		return refreshed
	end)
	if not party then
		return nil, partyError
	end

	CloudRetry.call("PartyRepository.RefreshCode", function()
		return self._codeMap:UpdateAsync(party.joinCode, function(current)
			if current == nil or current.partyId == partyId then
				return {
					partyId = partyId,
				}
			end

			return nil
		end, Config.PartyRecordLifetime)
	end)

	return party
end

function PartyRepository:DeleteParty(party)
	local success, value = CloudRetry.call("PartyRepository.DeleteParty", function()
		return self._partyMap:RemoveAsync(party.partyId)
	end)
	if not success then
		return false, value
	end

	local codeSuccess, index = CloudRetry.call("PartyRepository.ReadCodeForDelete", function()
		return self._codeMap:GetAsync(party.joinCode)
	end)
	if codeSuccess and index and index.partyId == party.partyId then
		CloudRetry.call("PartyRepository.DeleteCode", function()
			return self._codeMap:RemoveAsync(party.joinCode)
		end)
	end

	return true
end

return PartyRepository
