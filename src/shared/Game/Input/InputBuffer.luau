--!strict

-- One-slot input buffer. A throw or swing that arrives during a cooldown tail
-- or a non-actionable state waits a short window and fires the instant the
-- action becomes legal, instead of being silently dropped.
--
-- Mobile touch latency plus a lower framerate means taps land late; without
-- this they feel like the game missed them. One slot only: a newer input
-- replaces an older one, because the player's latest intent is the real one.

local InputBuffer = {}

export type Buffer = {
	action: string?,
	queuedAt: number,
}

function InputBuffer.new(): Buffer
	return { action = nil, queuedAt = 0 }
end

function InputBuffer.push(buffer: Buffer, action: string, now: number)
	buffer.action = action
	buffer.queuedAt = now
end

function InputBuffer.clear(buffer: Buffer)
	buffer.action = nil
	buffer.queuedAt = 0
end

-- Returns the buffered action if one is still within its window, clearing it.
-- An expired entry is dropped silently rather than firing late.
function InputBuffer.take(buffer: Buffer, now: number, windowSeconds: number): string?
	local action = buffer.action
	if action == nil then
		return nil
	end
	local queuedAt = buffer.queuedAt
	InputBuffer.clear(buffer)
	if now - queuedAt > windowSeconds then
		return nil
	end
	return action
end

function InputBuffer.peek(buffer: Buffer, now: number, windowSeconds: number): string?
	if buffer.action == nil or now - buffer.queuedAt > windowSeconds then
		return nil
	end
	return buffer.action
end

return table.freeze(InputBuffer)
