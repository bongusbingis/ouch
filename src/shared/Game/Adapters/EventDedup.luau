-- Name: EventDedup.luau
-- Author: Jack C.
-- Description: Shared dedup guard for simulation and match event consumers, so a broadcast event observed more than once cannot apply a side effect twice.
-- Created: 2026-07-16

--!strict

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
