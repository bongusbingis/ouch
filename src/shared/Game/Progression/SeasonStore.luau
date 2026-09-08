-- Description: Client-side projection of the replicated season/battle pass state, exposing snapshot/subscribe for the splash screen season status card.
--!strict

local ReplicatedStore = require(script.Parent.Parent.Data.ReplicatedStore)

local store: ReplicatedStore.Store<any> = ReplicatedStore.new({
	tag = "SeasonStore",
	changedRemote = "SeasonPassStateChanged",
	fetchRemote = "GetSeasonPassState",
})

local SeasonStore = {
	start = store.start,
	stop = store.stop,
	snapshot = store.snapshot,
	subscribe = store.subscribe,
}

function SeasonStore.claimAll(): (any?, string?)
	local callOk, result, detail = store.request("ClaimAllSeasonTiers", function(nextState)
		return nextState
	end)
	if not callOk then
		return nil, result
	end
	return result, detail
end

return SeasonStore
