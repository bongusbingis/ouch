--!strict

local SimTypes = require(script.Parent.Parent.Sim.SimTypes)
local Combat = require(script.Parent.Parent.Parent.Parent.Config.Combat)

type SimState = SimTypes.SimState
type ProjectileState = SimTypes.ProjectileState

-- Attributes on predicted instances are the between-tick source of truth: the
-- engine rolls them back on misprediction, so the adapter decodes a fresh
-- SimState every simulation step and encodes the result back. Names are kept
-- short for the replication limits (first 64 attributes, <=50-char names).
--
-- Ball position is NOT an attribute — it lives in the part's CFrame, which
-- has Simulation Access and is predicted natively.

local SimStateCodec = {}

local PHASE_TO_NUMBER: { [SimTypes.ProjectilePhase]: number } = {
	Held = 0,
	Windup = 1,
	InFlight = 2,
	Bouncing = 3,
	Recalling = 4,
	Free = 5,
}
local NUMBER_TO_PHASE: { [number]: SimTypes.ProjectilePhase } = {
	[0] = "Held",
	[1] = "Windup",
	[2] = "InFlight",
	[3] = "Bouncing",
	[4] = "Recalling",
	[5] = "Free",
}

local DEFAULT_EFFECTIVE_RADIUS = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness

local function setAttributeIfChanged(instance: Instance, name: string, value: any)
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

function SimStateCodec.decode(ballsFolder: Instance, characterModels: { [string]: Model }): SimState
	local state = SimTypes.newState()
	state.tick = (ballsFolder:GetAttribute("tk") :: number?) or 0
	state.nextProjectileSeq = (ballsFolder:GetAttribute("sq") :: number?) or 1

	for _, ball in ballsFolder:GetChildren() do
		if not ball:IsA("BasePart") then
			continue
		end
		local velocity = ball:GetAttribute("vel")
		state.projectiles[ball.Name] = {
			id = ball.Name,
			archetype = "Dodgeball",
			ownerId = ball:GetAttribute("ow") :: string?,
			heldBy = ball:GetAttribute("hb") :: string?,
			phase = NUMBER_TO_PHASE[(ball:GetAttribute("ph") :: number?) or 5] or "Free",
			position = ball.CFrame.Position,
			velocity = if typeof(velocity) == "Vector3" then velocity else vector.zero,
			targetId = ball:GetAttribute("tg") :: string?,
			effectiveRadius = (ball:GetAttribute("er") :: number?) or DEFAULT_EFFECTIVE_RADIUS,
			flightTime = (ball:GetAttribute("ft") :: number?) or 0,
			windupRemaining = (ball:GetAttribute("wu") :: number?) or 0,
			bounceCount = (ball:GetAttribute("bc") :: number?) or 0,
			spinAngle = (ball:GetAttribute("sa") :: number?) or 0,
			spinRate = (ball:GetAttribute("sr") :: number?) or 0,
			releaseAim = ball:GetAttribute("ra") :: Vector3?,
			releaseTargetId = ball:GetAttribute("rt") :: string?,
			releaseDeviceClass = ball:GetAttribute("rd") :: string?,
		}
	end

	for playerId, model in characterModels do
		state.players[playerId] = {
			id = playerId,
			weapons = {
				Dodgeball = {
					throwCooldown = (model:GetAttribute("dbTc") :: number?) or 0,
					recallCooldown = (model:GetAttribute("dbRc") :: number?) or 0,
				},
			},
		}
	end

	return state
end

function SimStateCodec.encode(state: SimState, ballsFolder: Instance, characterModels: { [string]: Model })
	setAttributeIfChanged(ballsFolder, "tk", state.tick)
	setAttributeIfChanged(ballsFolder, "sq", state.nextProjectileSeq)
	for _, ball in ballsFolder:GetChildren() do
		if not ball:IsA("BasePart") then
			continue
		end
		local projectile = state.projectiles[ball.Name]
		if projectile == nil then
			continue
		end
		local authoredRotation = ball:GetAttribute("ar")
		local rotation = if typeof(authoredRotation) == "CFrame" then authoredRotation else CFrame.identity
		local targetCFrame = CFrame.new(projectile.position) * rotation * CFrame.Angles(projectile.spinAngle, 0, 0)
		if ball.CFrame ~= targetCFrame then
			ball.CFrame = targetCFrame
		end
		setAttributeIfChanged(ball, "ph", PHASE_TO_NUMBER[projectile.phase])
		setAttributeIfChanged(ball, "ow", projectile.ownerId)
		setAttributeIfChanged(ball, "hb", projectile.heldBy)
		setAttributeIfChanged(ball, "tg", projectile.targetId)
		setAttributeIfChanged(ball, "er", projectile.effectiveRadius)
		setAttributeIfChanged(ball, "ft", projectile.flightTime)
		setAttributeIfChanged(ball, "wu", projectile.windupRemaining)
		setAttributeIfChanged(ball, "bc", projectile.bounceCount)
		setAttributeIfChanged(ball, "sa", projectile.spinAngle)
		setAttributeIfChanged(ball, "sr", projectile.spinRate)
		setAttributeIfChanged(ball, "ra", projectile.releaseAim)
		setAttributeIfChanged(ball, "rt", projectile.releaseTargetId)
		setAttributeIfChanged(ball, "rd", projectile.releaseDeviceClass)
		local velocity = projectile.velocity
		if projectile.phase ~= "InFlight" and projectile.phase ~= "Recalling" then
			velocity = vector.zero
		end
		setAttributeIfChanged(ball, "vel", velocity)
	end

	for playerId, model in characterModels do
		local player = state.players[playerId]
		if player == nil then
			continue
		end
		local kitState = player.weapons.Dodgeball
		setAttributeIfChanged(model, "dbTc", kitState.throwCooldown)
		setAttributeIfChanged(model, "dbRc", kitState.recallCooldown)
	end
end

return SimStateCodec
