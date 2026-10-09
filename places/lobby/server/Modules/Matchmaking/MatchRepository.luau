-- Description: Persistence for match records in the shared memory store, including creation, lookup, removal, party membership checks, and the lease that keeps one server responsible for a match.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))
local CloudRetry = require(script.Parent.CloudRetry)

local MatchRepository = {}
MatchRepository.__index = MatchRepository

local function mapName(suffix)
	return Config.MemoryStoreNamespace .. ":" .. suffix
end

function MatchRepository.new()
	return setmetatable({
		_matchMap = MemoryStoreService:GetHashMap(mapName("MatchById")),
		_leaseMap = MemoryStoreService:GetHashMap(mapName("WorkerLease")),
	}, MatchRepository)
end

function MatchRepository:GetMatch(matchId)
	local success, value = CloudRetry.call("MatchRepository.GetMatch", function()
		return self._matchMap:GetAsync(matchId)
	end)
	if not success then
		return nil, value
	end

	return value
end

function MatchRepository:SetMatch(matchRecord)
	local success, value = CloudRetry.call("MatchRepository.SetMatch", function()
		return self._matchMap:SetAsync(matchRecord.matchId, matchRecord, Config.MatchRecordLifetime)
	end)

	return success, value
end

function MatchRepository:RemoveMatch(matchId)
	local success, value = CloudRetry.call("MatchRepository.RemoveMatch", function()
		return self._matchMap:RemoveAsync(matchId)
	end)

	return success, value
end

function MatchRepository:ContainsParty(matchRecord, partyId)
	for _, party in matchRecord.parties do
		if party.partyId == partyId then
			return true
		end
	end

	return false
end

function MatchRepository:AcquireLease(queueId)
	local now = os.time()
	local leaseKey = "Worker:" .. queueId
	local success, lease = CloudRetry.call("MatchRepository.AcquireLease", function()
		return self._leaseMap:UpdateAsync(leaseKey, function(current)
			if current and current.ownerJobId ~= game.JobId and current.expiresAt > now then
				return nil
			end

			return {
				ownerJobId = game.JobId,
				expiresAt = now + Config.WorkerLeaseLifetime,
			}
		end, Config.WorkerLeaseLifetime * 2)
	end)
	if not success then
		return false
	end

	return lease ~= nil and lease.ownerJobId == game.JobId
end

function MatchRepository:ReleaseLease(queueId)
	local leaseKey = "Worker:" .. queueId
	local success = CloudRetry.call("MatchRepository.ReleaseLease", function()
		return self._leaseMap:UpdateAsync(leaseKey, function(current)
			if not current or current.ownerJobId ~= game.JobId then
				return nil
			end

			return {
				ownerJobId = game.JobId,
				expiresAt = 0,
			}
		end, 1)
	end)

	return success
end

return MatchRepository
