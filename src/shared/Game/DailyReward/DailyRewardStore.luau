-- Description: Client-side projection of daily reward state, exposing snapshot/subscribe for React and a claim action that round-trips to the server.
--!strict

local ReplicatedStore = require(script.Parent.Parent.Data.ReplicatedStore)

type PublicState = {
	canClaim: boolean,
	currentDay: number,
	nextDay: number,
	days: { any },
	totalClaimed: number,
}
local store: ReplicatedStore.Store<PublicState> = ReplicatedStore.new({
	tag = "DailyRewardStore",
	changedRemote = "DailyRewardStateChanged",
	fetchRemote = "GetDailyRewardState",
})

local DailyRewardStore = {
	start = store.start,
	stop = store.stop,
	snapshot = store.snapshot,
	subscribe = store.subscribe,
}

function DailyRewardStore.claim(): (PublicState?, string?)
	local callOk, result, detail = store.request("ClaimDailyReward", function(nextState)
		return nextState
	end)
	if not callOk then
		return nil, result
	end
	return result, detail
end

return DailyRewardStore
