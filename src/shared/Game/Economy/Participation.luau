-- Tracks server-observed participation and limits repeat-opponent reward payouts per match.
--!strict
local Participation = {}
function Participation.new()
	return { activeSeconds = 0, lastAction = -math.huge, position = nil, payouts = {}, totals = {} }
end
function Participation.sample(state: any, position: vector?, now: number, dt: number, config: any)
	local moved = position ~= nil
		and state.position ~= nil
		and vector.magnitude(position - state.position) >= config.MinimumMovementStuds
	if moved or now - state.lastAction <= config.ActionWindowSeconds then
		state.activeSeconds += math.clamp(dt, 0, 1)
	end
	state.position = position
end
function Participation.action(state: any, now: number)
	state.lastAction = now
end
function Participation.payout(state: any, kind: string, opponent: string?, config: any): boolean
	local cap = config.PerOpponent[kind]
	local key = kind .. ":" .. (opponent or "world")
	local count = state.payouts[key] or 0
	local total = state.totals[kind] or 0
	if count >= cap or total >= config.PerMatch[kind] then
		return false
	end
	state.payouts[key] = count + 1
	state.totals[kind] = total + 1
	return true
end
function Participation.eligible(state: any, progress: any, config: any): boolean
	return state.activeSeconds >= config.MinimumActiveSeconds
		or progress.Elims > 0
		or progress.Catches >= config.QualifyingCatches
end
return Participation
