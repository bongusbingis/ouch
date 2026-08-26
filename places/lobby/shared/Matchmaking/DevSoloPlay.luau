-- Name: DevSoloPlay.luau
-- Author: Jack C.
-- Description: Developer-only gate for the hidden solo-play path, checking group rank so the server can authorize a single-player match request.
-- Created: 2026-08-20

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
