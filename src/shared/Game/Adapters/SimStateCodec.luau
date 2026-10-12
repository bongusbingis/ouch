-- Description: Encodes and decodes simulation state to and from the attributes on ball and character instances; only attributes the client reads or the spawn-time decode needs are replicated.

--!strict

local SimTypes = require(script.Parent.Parent.Sim.SimTypes)
local WeaponRegistry = require(script.Parent.Parent.Sim.WeaponRegistry)
local Combat = require(script.Parent.Parent.Parent.Parent.Config.Gameplay.Combat)

type SimState = SimTypes.SimState
type ProjectileState = SimTypes.ProjectileState

local SimStateCodec = {}

SimStateCodec.EquippedAttribute = "wpn"

local PHASE_TO_NUMBER: { [SimTypes.ProjectilePhase]: number } = {
	Held = 0,
	Windup = 1,
	InFlight = 2,
	Bouncing = 3,
	Rolling = 4,
	Free = 5,
}
local NUMBER_TO_PHASE: { [number]: SimTypes.ProjectilePhase } = {
	[0] = "Held",
	[1] = "Windup",
	[2] = "InFlight",
	[3] = "Bouncing",
	[4] = "Rolling",
	[5] = "Free",
}

local DEFAULT_EFFECTIVE_RADIUS = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness

local function setAttributeIfChanged(instance: Instance, name: string, value: any)
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

function SimStateCodec.numberToPhase(number: number): SimTypes.ProjectilePhase
	return NUMBER_TO_PHASE[number] or "Free"
end

function SimStateCodec.phaseToNumber(phase: SimTypes.ProjectilePhase): number
	return PHASE_TO_NUMBER[phase] or 5
end

function SimStateCodec.decodeProjectile(ball: Instance): ProjectileState?
	if not ball:IsA("BasePart") then
		return nil
	end
	local velocity = ball:GetAttribute("vel")
	local hasVelocity = typeof(velocity) == "Vector3" or typeof(velocity) == "vector"
	return {
		id = ball.Name,
		archetype = "Dodgeball",
		ownerId = ball:GetAttribute("ow") :: string?,
		heldBy = ball:GetAttribute("hb") :: string?,
		phase = NUMBER_TO_PHASE[(ball:GetAttribute("ph") :: number?) or 5] or "Free",
		position = ball.CFrame.Position,
		velocity = if hasVelocity then velocity else vector.zero,
		effectiveRadius = (ball:GetAttribute("er") :: number?) or DEFAULT_EFFECTIVE_RADIUS,
		flightTime = (ball:GetAttribute("ft") :: number?) or 0,
		windupRemaining = 0,
		bounceCount = 0,
	}
end

function SimStateCodec.decode(ballsFolder: Instance, characterModels: { [string]: Model }): SimState
	local state = SimTypes.newState()

	for _, ball in ballsFolder:GetChildren() do
		local decoded = SimStateCodec.decodeProjectile(ball)
		if decoded then
			state.projectiles[ball.Name] = decoded
		end
	end

	for playerId, model in characterModels do
		state.players[playerId] = {
			id = playerId,
			equipped = (model:GetAttribute(SimStateCodec.EquippedAttribute) :: string?) or WeaponRegistry.defaultKind(),
			heldBallLastTick = false,
			weapons = {
				Dodgeball = {
					throwCooldown = (model:GetAttribute("dbTc") :: number?) or 0,
					catchCooldown = (model:GetAttribute("dbCc") :: number?) or 0,
					catchRemaining = 0,
				},
				Hammer = {
					cooldown = (model:GetAttribute("hmCd") :: number?) or 0,
					activeRemaining = 0,
					recoveryRemaining = 0,
					stunRemaining = 0,
				},
			},
		}
	end

	return state
end

function SimStateCodec.encode(state: SimState, ballsFolder: Instance, characterModels: { [string]: Model })
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
		local targetCFrame = CFrame.new(projectile.position) * rotation
		if ball.CFrame ~= targetCFrame then
			ball.CFrame = targetCFrame
		end
		setAttributeIfChanged(ball, "ph", PHASE_TO_NUMBER[projectile.phase])
		setAttributeIfChanged(ball, "ow", projectile.ownerId)
		setAttributeIfChanged(ball, "hb", projectile.heldBy)
		setAttributeIfChanged(ball, "er", projectile.effectiveRadius)
		setAttributeIfChanged(ball, "ft", projectile.flightTime)
		local velocity = projectile.velocity
		if projectile.phase ~= "InFlight" and projectile.phase ~= "Bouncing" and projectile.phase ~= "Rolling" then
			velocity = vector.zero
		end
		setAttributeIfChanged(ball, "vel", velocity)
	end

	for playerId, model in characterModels do
		local player = state.players[playerId]
		if player == nil then
			continue
		end
		setAttributeIfChanged(model, SimStateCodec.EquippedAttribute, player.equipped)
		local kitState = player.weapons.Dodgeball
		setAttributeIfChanged(model, "dbTc", kitState.throwCooldown)
		setAttributeIfChanged(model, "dbCc", kitState.catchCooldown)
		local hammerState = player.weapons.Hammer
		setAttributeIfChanged(model, "hmCd", hammerState.cooldown)
	end
end

return SimStateCodec
