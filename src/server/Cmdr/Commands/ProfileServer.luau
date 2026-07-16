--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local PlayerData = require(Server:WaitForChild("Modules"):WaitForChild("PlayerData"))

local function sortedEquips(equipped: any): { string }
	local entries = {}
	for slot, itemId in equipped do
		table.insert(entries, `{slot}={itemId}`)
	end
	table.sort(entries)
	return entries
end

local function ownedCount(owned: any): number
	local count = 0
	for _, isOwned in owned do
		if isOwned then
			count += 1
		end
	end
	return count
end

return function(context: any, player: Player?): string
	local target = player or context.Executor
	local data = PlayerData.get(target)
	if data == nil then
		return `{target.Name}: profile not ready`
	end

	local progression = data.Progression
	local cosmetics = data.Cosmetics
	local equips = sortedEquips(cosmetics.Equipped)
	local equipSummary = if #equips > 0 then table.concat(equips, ", ") else "none"
	return string.format(
		"%s | Cash %d | XP %d | E/D/C %d/%d/%d | W/L %d/%d | Matches %d | KDR %.2f | Cosmetics %d | Equipped %s",
		target.Name,
		data.Cash,
		data.Level.Points,
		progression.Elims,
		progression.Deaths,
		progression.Catches,
		progression.Wins,
		progression.Losses,
		progression.MatchesPlayed,
		progression.KDR,
		ownedCount(cosmetics.Owned),
		equipSummary
	)
end
