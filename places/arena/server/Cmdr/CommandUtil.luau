--!strict

local CommandUtil = {}

export type PlayerAction = (player: Player) -> (boolean, string?)

function CommandUtil.runForPlayers(players: { Player }, action: PlayerAction): string
	local targets = table.clone(players)
	table.sort(targets, function(a, b)
		return a.UserId < b.UserId
	end)

	local succeeded = {}
	local failed = {}
	for _, player in targets do
		local ok, reason = action(player)
		if ok then
			table.insert(succeeded, player.Name)
		else
			table.insert(failed, `{player.Name} ({reason or "failed"})`)
		end
	end

	local output = `Succeeded {#succeeded}/{#targets}`
	if #succeeded > 0 then
		output ..= `: {table.concat(succeeded, ", ")}`
	end
	if #failed > 0 then
		output ..= ` | Failed: {table.concat(failed, ", ")}`
	end
	return output
end

return CommandUtil
