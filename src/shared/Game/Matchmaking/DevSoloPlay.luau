-- Description: Developer-only gate shared by the lobby's hidden solo-play path and the arena's match skip, checking group rank so either server can authorize a request only a tester may make.

--!strict

local DevSoloPlay = {}

local GROUP_ID = 291738800
local MIN_RANK = 254

function DevSoloPlay.canUse(player: any): boolean
	if typeof(player) ~= "Instance" and typeof(player) ~= "table" then
		return false
	end

	local success, rank = pcall(player.GetRankInGroup, player, GROUP_ID)
	return success and typeof(rank) == "number" and rank >= MIN_RANK
end

return table.freeze(DevSoloPlay)
