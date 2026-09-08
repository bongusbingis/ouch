-- Description: Small observable store holding the latest replicated party snapshot and notifying subscribers when it changes.

local PartyStore = {}
PartyStore.__index = PartyStore

function PartyStore.new()
	return setmetatable({
		_snapshot = nil,
		_listeners = {},
		_nextListenerId = 0,
	}, PartyStore)
end

function PartyStore:GetSnapshot()
	return self._snapshot
end

function PartyStore:ApplySnapshot(snapshot, reason)
	if typeof(snapshot) ~= "table" or typeof(snapshot.partyId) ~= "string" or typeof(snapshot.revision) ~= "number" then
		return false
	end
	if
		self._snapshot
		and self._snapshot.partyId == snapshot.partyId
		and self._snapshot.revision > snapshot.revision
	then
		return false
	end

	local previous = self._snapshot
	self._snapshot = snapshot
	for _, listener in self._listeners do
		listener(snapshot, previous, reason)
	end

	return true
end

function PartyStore:Subscribe(listener)
	self._nextListenerId += 1
	local listenerId = self._nextListenerId
	self._listeners[listenerId] = listener

	if self._snapshot then
		listener(self._snapshot, nil, "Subscribed")
	end

	return function()
		self._listeners[listenerId] = nil
	end
end

return PartyStore
