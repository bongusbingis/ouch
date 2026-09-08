-- Description: One-slot input buffer that holds an action arriving during a cooldown and fires it the instant it becomes legal, so late touch inputs are not silently dropped.

--!strict

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
