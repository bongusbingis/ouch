local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Matchmaking.Config)
local CloudRetry = require(script.Parent.CloudRetry)

local QueueRepository = {}
QueueRepository.__index = QueueRepository

local function queueName(mode)
	return Config.MemoryStoreNamespace .. ":Queue:" .. mode
end

function QueueRepository.new()
	local maps = {}
	for _, mode in Config.GameModes do
		maps[mode] = MemoryStoreService:GetSortedMap(queueName(mode))
	end

	return setmetatable({
		_maps = maps,
	}, QueueRepository)
end

function QueueRepository:Enqueue(ticket)
	local success, value = CloudRetry.call("QueueRepository.Enqueue", function()
		return self._maps[ticket.mode]:SetAsync(ticket.partyId, ticket, Config.QueueRecordLifetime, ticket.enqueuedAt)
	end)

	return success, value
end

function QueueRepository:Refresh(ticket)
	return self:Enqueue(ticket)
end

function QueueRepository:Remove(mode, partyId)
	local success, value = CloudRetry.call("QueueRepository.Remove", function()
		return self._maps[mode]:RemoveAsync(partyId)
	end)

	return success, value
end

function QueueRepository:GetCandidates(mode)
	local success, items = CloudRetry.call("QueueRepository.GetCandidates", function()
		return self._maps[mode]:GetRangeAsync(Enum.SortDirection.Ascending, Config.QueueCandidateLimit)
	end)
	if not success then
		return nil, items
	end

	return items
end

return QueueRepository
