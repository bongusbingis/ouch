-- Description: The only writer of walk speed: composes named multiplicative modifiers over each character's captured base speed and applies them during the synchronized simulation step.

--!strict

local RunService = game:GetService("RunService")

local Combat = require(script.Parent.Parent.Parent.Parent.Config.Gameplay.Combat)
local PlayerIds = require(script.Parent.PlayerIds)
local MovementGuard = require(script.Parent.MovementGuard)

local MovementSpeedService = {}

local BASE_SPEED_ATTRIBUTE = "mvBs"
local EXTERNAL_SCALE_ATTRIBUTE = "mvEx"

local externalModifiers: { [Player]: { [string]: number } } = {}
local dirtyExternal: { [Player]: boolean } = {}

local function setAttributeIfChanged(instance: Instance, name: string, value: any)
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

local function rootFor(player: Player?): BasePart?
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function eventDirection(event: any): Vector3?
	local direction = event.direction
	if typeof(direction) == "Vector3" then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		return if flat.Magnitude > 1e-6 then flat.Unit else nil
	elseif typeof(direction) == "vector" then
		local flat = Vector3.new(direction.x, 0, direction.z)
		return if flat.Magnitude > 1e-6 then flat.Unit else nil
	end
	return nil
end

local function applyHammerMotion(events: { any })
	for _, event in events do
		local direction = eventDirection(event)
		if direction == nil then
			continue
		end

		if event.kind == "HammerSwing" then
			local root = rootFor(PlayerIds.fromEvent(event))
			if root then
				local velocity = root.AssemblyLinearVelocity
				local forwardSpeed = Vector3.new(velocity.X, 0, velocity.Z):Dot(direction)
				local dashSpeed = (event.magnitude :: number?) or Combat.Hammer.DashSpeed
				local deltaSpeed = math.max(dashSpeed - forwardSpeed, 0)
				MovementGuard.allow(
					root,
					"Hammer",
					Combat.Hammer.ActiveDuration + Combat.Hammer.HitRecovery + 0.5,
					dashSpeed * 1.3,
					0
				)
				root:ApplyImpulse(direction * root.AssemblyMass * deltaSpeed)
			end
		elseif event.kind == "HammerHit" and event.targetId ~= nil then
			local root = rootFor(PlayerIds.fromId(event.targetId))
			if root then
				local current = root.AssemblyLinearVelocity
				local target = Vector3.new(
					direction.X * Combat.Hammer.KnockbackSpeed,
					Combat.Hammer.KnockbackUpSpeed,
					direction.Z * Combat.Hammer.KnockbackSpeed
				)
				root:ApplyImpulse((target - current) * root.AssemblyMass)
			end
		end
	end
end

local function applyWalkSpeed(state: any, characterModels: { [string]: Model })
	for playerId, model in characterModels do
		local player = PlayerIds.fromId(playerId)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if player == nil or humanoid == nil then
			continue
		end

		if RunService:IsServer() and dirtyExternal[player] then
			local externalScale = 1
			for _, modifier in externalModifiers[player] or {} do
				externalScale *= modifier
			end
			setAttributeIfChanged(model, EXTERNAL_SCALE_ATTRIBUTE, if externalScale ~= 1 then externalScale else nil)
			dirtyExternal[player] = nil
		end

		local baseSpeed = model:GetAttribute(BASE_SPEED_ATTRIBUTE)
		if typeof(baseSpeed) ~= "number" then
			baseSpeed = humanoid.WalkSpeed
			setAttributeIfChanged(model, BASE_SPEED_ATTRIBUTE, baseSpeed)
		end

		local scale = (model:GetAttribute(EXTERNAL_SCALE_ATTRIBUTE) :: number?) or 1
		local combatState = state.players[playerId]
		local hammerState = combatState and combatState.weapons.Hammer
		if hammerState and hammerState.stunRemaining > 0 then
			scale *= Combat.Hammer.MissStunWalkSpeedScale
		end
		local targetSpeed = baseSpeed * scale
		if humanoid.WalkSpeed ~= targetSpeed then
			humanoid.WalkSpeed = targetSpeed
		end
	end
end

function MovementSpeedService.setModifier(player: Player, name: string, scale: number)
	local modifiers = externalModifiers[player]
	if modifiers == nil then
		modifiers = {}
		externalModifiers[player] = modifiers
	end
	modifiers[name] = scale
	dirtyExternal[player] = true
end

function MovementSpeedService.clearModifier(player: Player, name: string)
	local modifiers = externalModifiers[player]
	if modifiers then
		modifiers[name] = nil
		if next(modifiers) == nil then
			externalModifiers[player] = nil
		end
	end
	dirtyExternal[player] = true
end

function MovementSpeedService.forget(player: Player)
	externalModifiers[player] = nil
	dirtyExternal[player] = nil
end

function MovementSpeedService.step(state: any, characterModels: { [string]: Model }, events: { any })
	applyHammerMotion(events)
	applyWalkSpeed(state, characterModels)
end

return MovementSpeedService
