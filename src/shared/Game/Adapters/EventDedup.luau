--!strict

-- Dedup guard for sim/match event consumers: the same event can be observed
-- more than once (rollback re-dispatch, multiple feeds into one handler), so
-- consumers gate side effects behind markSeen. Sim ticks only grow, so a
-- capped instance may clear its history without re-admitting a live event;
-- an uncapped instance is for per-match lifetimes — call clear() at match
-- boundaries.

local EventDedup = {}

export type Event = { [string]: any }
export type Dedup = {
	markSeen: (event: Event) -> boolean,
	clear: () -> (),
}

function EventDedup.key(event: Event): string
	return `{event.kind}:{event.tick or ""}:{event.projectileId or ""}:{event.playerId or ""}:{event.sourceId or ""}:{event.targetId or ""}`
end

function EventDedup.new(maxEntries: number?): Dedup
	local seen: { [string]: boolean } = {}
	local count = 0

	local function markSeen(event: Event): boolean
		local key = EventDedup.key(event)
		if seen[key] then
			return false
		end
		if maxEntries ~= nil and count >= maxEntries then
			table.clear(seen)
			count = 0
		end
		seen[key] = true
		count += 1
		return true
	end

	local function clear()
		table.clear(seen)
		count = 0
	end

	return { markSeen = markSeen, clear = clear }
end

return EventDedup
