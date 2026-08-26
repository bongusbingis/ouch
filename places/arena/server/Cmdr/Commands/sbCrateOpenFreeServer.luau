-- Name: sbCrateOpenFreeServer.luau
-- Author: Jack C.
-- Description: Server implementation of sb-crate-open-free, rolling and granting a crate without a currency charge while still firing the reveal event the client renders.
-- Created: 2026-07-15

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Modules = Server:WaitForChild("Modules")
local CrateService = require(Modules:WaitForChild("CrateService"))

local function describe(result): string
	if result.isDupe then
		return `{result.itemId} ({result.rarity}, duplicate, +{result.bonksRefund} Bonks)`
	end
	return `{result.itemId} ({result.rarity}, new)`
end

return function(_context, players: { Player }, crateId: string): string
	local targets = table.clone(players)
	table.sort(targets, function(a, b)
		return a.UserId < b.UserId
	end)

	local output = {}
	for _, player in targets do
		local result, reason = CrateService.openForTesting(player, crateId)
		if result then
			table.insert(output, `{player.Name}: {describe(result)}`)
		else
			table.insert(output, `{player.Name}: failed ({reason or "unknown"})`)
		end
	end
	return table.concat(output, "\n")
end
