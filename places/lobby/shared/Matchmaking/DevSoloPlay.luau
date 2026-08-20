--!strict
-- Developer-only gate for the hidden solo-play debug path. The server owns the
-- check; the client only counts taps and asks once.

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
