-- Description: Client-side projection of quest state, exposing snapshot/subscribe for the splash screen quest panel and a claim action.
--!strict

local ReplicatedStore = require(script.Parent.Parent.Data.ReplicatedStore)

type QuestState = {
	dailyKey: string,
	resetAt: number,
	quests: { any },
}
local store: ReplicatedStore.Store<QuestState> = ReplicatedStore.new({
	tag = "QuestStore",
	changedRemote = "QuestStateChanged",
	fetchRemote = "GetQuestState",
})

local QuestStore = {
	start = store.start,
	stop = store.stop,
	snapshot = store.snapshot,
	subscribe = store.subscribe,
}

function QuestStore.claim(questId: string): (boolean, any)
	local callOk, result, detail = store.request("ClaimQuest", function(accepted, nextState)
		return if accepted then nextState else nil
	end, questId)
	if not callOk then
		return false, result
	end
	return result, detail
end

return QuestStore
