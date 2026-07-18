--!strict

-- Damped spring for presentation feel (squash/stretch, wobble). Pure number
-- math with deterministic semi-implicit Euler steps so it runs headlessly
-- under Lune. dt is clamped so frame hitches cannot destabilize the
-- integration.

local Spring = {}

export type Spring = {
	position: number,
	velocity: number,
	target: number,
}

local MAX_STEP = 1 / 30

function Spring.new(position: number?): Spring
	local p = position or 0
	return { position = p, velocity = 0, target = p }
end

function Spring.impulse(spring: Spring, velocityDelta: number)
	spring.velocity += velocityDelta
end

function Spring.step(spring: Spring, frequencyHz: number, dampingRatio: number, dt: number)
	local h = math.min(dt, MAX_STEP)
	local omega = 2 * math.pi * frequencyHz
	local accel = -omega * omega * (spring.position - spring.target) - 2 * dampingRatio * omega * spring.velocity
	spring.velocity += accel * h
	spring.position += spring.velocity * h
end

return Spring
