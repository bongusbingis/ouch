--!strict

local Players = game:GetService("Players")

-- Single owner of the sim player-id convention: UserId rendered as a string.
-- Sim state, codec attributes ("hb"/"ow"), and event playerId/sourceId/
-- targetId fields all carry these ids; every translation to or from a Player
-- goes through here so the convention cannot drift per call site.

local PlayerIds = {}

-- Memoised because the sim, the codec, and the presentation loops all convert the
-- same players every tick, and tostring allocates each time. Weak keys, so a
-- departed player's entry is collected without a lifecycle hook.
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
