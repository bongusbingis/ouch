-- Description: Server implementation of sb-crate-open-free, rolling and granting a crate without a currency charge while still firing the reveal event the client renders.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Modules = Server:WaitForChild("Modules")
local CrateService = require(Modules:WaitForChild("CrateService"))

local function describeEntry(entry): string
	if entry.isDupe then
		return `{entry.itemId} ({entry.rarity}, duplicate, +{entry.bonksRefund} Bonks)`
	end
	return `{entry.itemId} ({entry.rarity}, new)`
end

local function describe(result): string
	local parts = {}
	for _, entry in result.results do
		table.insert(parts, describeEntry(entry))
	end
	return table.concat(parts, ", ")
end

return function(_context, players: { Player }, crateId: string): string
	local targets = table.clone(players)
	table.sort(targets, function(a, b)
		return a.UserId < b.UserId
	end)

	local output = {}
	for _, player in targets do
		local result, reason = CrateService.openForAdmin(player, crateId)
		if result then
			table.insert(output, `{player.Name}: {describe(result)}`)
		else
			table.insert(output, `{player.Name}: failed ({reason or "unknown"})`)
		end
	end
	return table.concat(output, "\n")
end
