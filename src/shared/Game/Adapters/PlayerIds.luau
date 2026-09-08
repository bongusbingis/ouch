-- Description: Single owner of the simulation player-id convention, translating between players and the string ids used throughout sim state and events.

--!strict

local Players = game:GetService("Players")

local PlayerIds = {}

local idCache: { [Player]: string } = setmetatable({}, { __mode = "k" }) :: any

function PlayerIds.toId(player: Player): string
	local cached = idCache[player]
	if cached == nil then
		cached = tostring(player.UserId)
		idCache[player] = cached
	end
	return cached
end

function PlayerIds.fromId(id: string?): Player?
	local userId = if id then tonumber(id) else nil
	if userId == nil then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

function PlayerIds.fromEvent(event: { [string]: any }): Player?
	return PlayerIds.fromId(event.playerId or event.sourceId)
end

return PlayerIds
