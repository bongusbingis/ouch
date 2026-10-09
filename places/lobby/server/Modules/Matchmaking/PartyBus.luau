-- Description: Cross-server party messaging: subscribes to each party's topic, publishes snapshot and deletion messages, and manages subscription lifetimes as members join and leave a server.

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Config"))
local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Protocol"))
local CloudRetry = require(script.Parent.CloudRetry)

local PartyBus = {}
PartyBus.__index = PartyBus

function PartyBus.new()
	return setmetatable({
		_subscriptions = {},
	}, PartyBus)
end

function PartyBus:_topic(partyId)
	return Config.PartyTopicPrefix .. partyId
end

function PartyBus:_subscribe(partyId, entry)
	if entry.connection then
		return true
	end

	local success, connection = CloudRetry.call("PartyBus.Subscribe", function()
		return MessagingService:SubscribeAsync(self:_topic(partyId), function(message)
			if Protocol.isPartyMessage(message.Data, partyId) then
				entry.callback(message.Data)
			end
		end)
	end)
	if success then
		entry.connection = connection
	end

	return success
end

function PartyBus:Acquire(partyId, callback)
	local entry = self._subscriptions[partyId]
	if entry then
		entry.count += 1
		entry.callback = callback
		return self:_subscribe(partyId, entry)
	end

	entry = {
		count = 1,
		callback = callback,
		connection = nil,
	}
	self._subscriptions[partyId] = entry
	return self:_subscribe(partyId, entry)
end

function PartyBus:Ensure(partyId)
	local entry = self._subscriptions[partyId]
	if not entry then
		return false
	end

	return self:_subscribe(partyId, entry)
end

function PartyBus:Release(partyId)
	local entry = self._subscriptions[partyId]
	if not entry then
		return
	end

	entry.count -= 1
	if entry.count > 0 then
		return
	end

	if entry.connection then
		entry.connection:Disconnect()
	end
	self._subscriptions[partyId] = nil
end

function PartyBus:Publish(party, reason, actorUserId)
	local message = Protocol.partyMessage(party, reason, actorUserId)
	local success = CloudRetry.call("PartyBus.Publish", function()
		return MessagingService:PublishAsync(self:_topic(party.partyId), message)
	end)

	return success
end

function PartyBus:PublishDeleted(partyId, revision, actorUserId)
	local message = Protocol.deletedMessage(partyId, revision, actorUserId)
	local success = CloudRetry.call("PartyBus.PublishDeleted", function()
		return MessagingService:PublishAsync(self:_topic(partyId), message)
	end)

	return success
end

function PartyBus:Destroy()
	for partyId, entry in self._subscriptions do
		if entry.connection then
			entry.connection:Disconnect()
		end
		self._subscriptions[partyId] = nil
	end
end

return PartyBus
