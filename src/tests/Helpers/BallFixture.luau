--!strict
-- Pure ProjectileState builders for sim specs: full field set with sensible
-- defaults so specs only state what a scenario cares about. Mirrors the
-- archetype defaults in Config.Combat.Dodgeball.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))

local BallFixture = {}

function BallFixture.make(fields: { [string]: any }): any
	return {
		id = fields.id or "ball_0001",
		archetype = "Dodgeball",
		ownerId = fields.ownerId,
		heldBy = fields.heldBy,
		phase = fields.phase or "InFlight",
		position = fields.position or vector.zero,
		velocity = fields.velocity or vector.zero,
		targetId = fields.targetId,
		effectiveRadius = fields.effectiveRadius or (Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness),
		flightTime = fields.flightTime or 0,
		windupRemaining = fields.windupRemaining or 0,
		bounceCount = fields.bounceCount or 0,
		spinAngle = fields.spinAngle or 0,
		spinRate = fields.spinRate or 0,
		releaseAim = fields.releaseAim,
		releaseTargetId = fields.releaseTargetId,
		releaseDeviceClass = fields.releaseDeviceClass,
	}
end

function BallFixture.held(id: string, ownerId: string, position: vector): any
	return BallFixture.make({
		id = id,
		ownerId = ownerId,
		heldBy = ownerId,
		phase = "Held",
		position = position,
	})
end

function BallFixture.insert(state: any, fields: { [string]: any }): any
	local ball = BallFixture.make(fields)
	state.projectiles[ball.id] = ball
	return ball
end

return BallFixture
