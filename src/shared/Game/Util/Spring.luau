-- Description: Damped spring for presentation feel, pure number maths with deterministic steps and a clamped timestep so frame hitches cannot destabilize it.

--!strict

local Spring = {}

export type Spring = {
	position: number,
	velocity: number,
	target: number,
}

local MAX_STEP = 1 / 30
local SAFE_OMEGA_STEP = 0.35
local MAX_SUBSTEPS = 12

function Spring.new(position: number?): Spring
	local p = position or 0
	return { position = p, velocity = 0, target = p }
end

function Spring.impulse(spring: Spring, velocityDelta: number)
	spring.velocity += velocityDelta
end

function Spring.step(spring: Spring, frequencyHz: number, dampingRatio: number, dt: number)
	local h = math.min(dt, MAX_STEP)
	if h <= 0 then
		return
	end
	local omega = 2 * math.pi * math.max(frequencyHz, 0)
	local substeps = math.clamp(math.ceil(omega * h / SAFE_OMEGA_STEP), 1, MAX_SUBSTEPS)
	local subDt = h / substeps
	for _ = 1, substeps do
		local accel = -omega * omega * (spring.position - spring.target) - 2 * dampingRatio * omega * spring.velocity
		spring.velocity += accel * subDt
		spring.position += spring.velocity * subDt
	end
end

return Spring
