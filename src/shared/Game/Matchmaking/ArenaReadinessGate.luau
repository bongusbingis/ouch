-- Description: Pure readiness gate for an arriving arena session, releasing once every expected player is ready or the deadline passes with at least one ready player, and never opening an empty one.

--!strict

local ArenaReadinessGate = {}

export type Kind = "Matched" | "Direct"

export type State = {
	kind: Kind,
	expectedPlayerCount: number,
	deadlineAt: number,
	arrivedByUserId: { [number]: boolean },
	readyByUserId: { [number]: boolean },
	gateReleased: boolean,
	releaseReason: string?,
}

export type Snapshot = {
	expectedPlayerCount: number,
	arrivedPlayerCount: number,
	readyPlayerCount: number,
	deadlineAt: number,
	gateReleased: boolean,
}

local function count(values: { [number]: boolean }): number
	local total = 0
	for _ in values do
		total += 1
	end
	return total
end

function ArenaReadinessGate.new(kind: Kind, expectedPlayerCount: number, deadlineAt: number): State
	assert(expectedPlayerCount % 1 == 0 and expectedPlayerCount >= 1, "expectedPlayerCount must be a positive integer")
	assert(deadlineAt == deadlineAt and deadlineAt >= 0 and deadlineAt < math.huge, "deadlineAt must be finite")
	return {
		kind = kind,
		expectedPlayerCount = expectedPlayerCount,
		deadlineAt = deadlineAt,
		arrivedByUserId = {},
		readyByUserId = {},
		gateReleased = false,
		releaseReason = nil,
	}
end

function ArenaReadinessGate.arrive(state: State, userId: number): boolean
	if state.arrivedByUserId[userId] then
		return false
	end
	state.arrivedByUserId[userId] = true
	return true
end

function ArenaReadinessGate.leave(state: State, userId: number): boolean
	if not state.arrivedByUserId[userId] then
		return false
	end
	state.arrivedByUserId[userId] = nil
	state.readyByUserId[userId] = nil
	return true
end

function ArenaReadinessGate.markReady(state: State, userId: number): boolean
	if not state.arrivedByUserId[userId] or state.readyByUserId[userId] then
		return false
	end
	state.readyByUserId[userId] = true
	return true
end

function ArenaReadinessGate.evaluate(state: State, now: number): (boolean, string?)
	if state.gateReleased then
		return false, state.releaseReason
	end

	local readyPlayerCount = count(state.readyByUserId)
	local releaseReason: string? = nil
	if readyPlayerCount >= state.expectedPlayerCount then
		releaseReason = "all_ready"
	elseif state.kind == "Direct" and readyPlayerCount > 0 then
		releaseReason = "direct_ready"
	elseif now >= state.deadlineAt and readyPlayerCount > 0 then
		releaseReason = "deadline"
	end

	if releaseReason == nil then
		return false, nil
	end
	state.gateReleased = true
	state.releaseReason = releaseReason
	return true, releaseReason
end

function ArenaReadinessGate.isReady(state: State, userId: number): boolean
	return state.readyByUserId[userId] == true
end

function ArenaReadinessGate.snapshot(state: State): Snapshot
	return {
		expectedPlayerCount = state.expectedPlayerCount,
		arrivedPlayerCount = count(state.arrivedByUserId),
		readyPlayerCount = count(state.readyByUserId),
		deadlineAt = state.deadlineAt,
		gateReleased = state.gateReleased,
	}
end

return table.freeze(ArenaReadinessGate)
