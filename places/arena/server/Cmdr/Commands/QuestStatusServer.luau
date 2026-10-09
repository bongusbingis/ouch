-- Description: Server implementation of sb-quest-status, listing a player's active daily quests with their progress, targets, and claim state.

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local QuestService = require(Server:WaitForChild("Modules"):WaitForChild("QuestService"))

return function(context: any, player: Player?): string
	local target = player or context.Executor
	local state = QuestService.stateForAdmin(target)
	if state == nil then
		return `{target.Name}: profile not ready`
	end

	local resetSeconds = math.max(math.floor(state.resetAt - os.time()), 0)
	local lines = { `{target.Name} | Daily {state.dailyKey} | Resets in {resetSeconds}s` }
	for _, quest in state.quests do
		local status = if quest.claimed then "claimed" elseif quest.completed then "ready" else "active"
		table.insert(lines, `{quest.slot}. {quest.questId}: {quest.progress}/{quest.goal} ({status})`)
	end
	if #state.quests == 0 then
		table.insert(lines, "No active quests")
	end
	return table.concat(lines, "\n")
end
