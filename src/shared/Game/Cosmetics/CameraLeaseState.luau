--!strict

-- Pure priority ordering for camera leases. Tokens, rather than reason strings,
-- identify ownership so stale cleanup cannot release a replacement.

local CameraLeaseState = {}

export type Token = { priority: number, sequence: number, reason: string }
export type State = { leases: { [Token]: boolean }, sequence: number }

function CameraLeaseState.new(): State
	return { leases = {}, sequence = 0 }
end

function CameraLeaseState.acquire(state: State, reason: string, priority: number): Token
	state.sequence += 1
	local token = { reason = reason, priority = priority, sequence = state.sequence }
	state.leases[token] = true
	return token
end

function CameraLeaseState.release(state: State, token: Token)
	state.leases[token] = nil
end

function CameraLeaseState.current(state: State): Token?
	local selected: Token? = nil
	for token in state.leases do
		if
			selected == nil
			or token.priority > selected.priority
			or (token.priority == selected.priority and token.sequence > selected.sequence)
		then
			selected = token
		end
	end
	return selected
end

return CameraLeaseState
