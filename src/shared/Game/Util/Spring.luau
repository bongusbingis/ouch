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
-- Semi-implicit Euler only stays stable while omega * h is small. Past roughly
-- 1 it oscillates, and past 2 it diverges outright -- the position runs away to
-- infinity within a handful of frames and never recovers, because there is no
-- restoring force strong enough to pull an infinite value back. A spring at
-- 14Hz crosses that line at 60fps, so the integration is substepped to keep
-- each step well inside the stable region rather than trusting callers to pick
-- timid frequencies.
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
