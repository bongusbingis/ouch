-- Description: Server implementation of sb-crate-open-bonks, charging Bonks and running the normal crate roll and grant so the paid path can be exercised end to end.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Modules = Server:WaitForChild("Modules")
local CrateService = require(Modules:WaitForChild("CrateService"))
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Crates = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Economy"):WaitForChild("Crates"))

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
	local crate = Crates[crateId]
	local targets = table.clone(players)
	table.sort(targets, function(a, b)
		return a.UserId < b.UserId
	end)

	local output = {}
	for _, player in targets do
		local result, reason = CrateService.openWithBonks(player, crateId)
		if result then
			local data = PlayerData.get(player)
			local balance = if data then data.Bonks else "unavailable"
			table.insert(
				output,
				`{player.Name}: {describe(result)} | cost={(crate.BonksPrice or 0) * result.count} balance={balance}`
			)
		else
			table.insert(output, `{player.Name}: failed ({reason or "unknown"})`)
		end
	end
	return table.concat(output, "\n")
end
