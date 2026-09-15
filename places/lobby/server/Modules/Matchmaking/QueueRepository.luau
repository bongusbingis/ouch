-- Description: Persistence for the matchmaking queue in the shared memory store: enqueue, refresh, remove, and read the current candidate tickets.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))
local CloudRetry = require(script.Parent.CloudRetry)

local QueueRepository = {}
QueueRepository.__index = QueueRepository

local function queueName(queueId)
	return Config.MemoryStoreNamespace .. ":Queue:" .. queueId
end

function QueueRepository.new(queueId)
	return setmetatable({
		_map = MemoryStoreService:GetSortedMap(queueName(queueId)),
	}, QueueRepository)
end

function QueueRepository:Enqueue(ticket)
	local success, value = CloudRetry.call("QueueRepository.Enqueue", function()
		return self._map:SetAsync(ticket.partyId, ticket, Config.QueueRecordLifetime, ticket.enqueuedAt)
	end)

	return success, value
end

function QueueRepository:Refresh(ticket)
	return self:Enqueue(ticket)
end

function QueueRepository:Remove(partyId)
	local success, value = CloudRetry.call("QueueRepository.Remove", function()
		return self._map:RemoveAsync(partyId)
	end)

	return success, value
end

function QueueRepository:GetCandidates()
	local success, items = CloudRetry.call("QueueRepository.GetCandidates", function()
		return self._map:GetRangeAsync(Enum.SortDirection.Ascending, Config.QueueCandidateLimit)
	end)
	if not success then
		return nil, items
	end

	return items
end

return QueueRepository
