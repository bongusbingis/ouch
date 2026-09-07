-- Pure displacement budgets tolerate replication bursts while rejecting sustained impossible movement.
--!strict

local Budget = {}

function Budget.finite(v: vector, limit: number): boolean
	return v.x == v.x
		and v.y == v.y
		and v.z == v.z
		and math.abs(v.x) <= limit
		and math.abs(v.y) <= limit
		and math.abs(v.z) <= limit
end

function Budget.step(
	state: any,
	position: vector,
	now: number,
	horizontal: number,
	upward: number,
	burst: number
): boolean
	local dt = math.clamp(now - state.time, 0, 1)
	local delta = position - state.position
	local distance = vector.magnitude(vector.create(delta.x, 0, delta.z))
	local horizontalCredit = math.min(burst, state.horizontal + dt * horizontal)
	local verticalCredit = math.min(burst, state.vertical + dt * upward)
	state.time = now
	if distance > horizontalCredit or math.max(delta.y, 0) > verticalCredit then
		state.horizontal = horizontalCredit
		state.vertical = verticalCredit
		return false
	end
	state.horizontal = horizontalCredit - distance
	state.vertical = verticalCredit - math.max(delta.y, 0)
	state.position = position
	return true
end

function Budget.new(position: vector, now: number, burst: number)
	return { position = position, time = now, horizontal = burst, vertical = burst }
end

return Budget
