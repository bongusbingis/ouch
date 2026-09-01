-- Name: BallVisuals.luau
-- Author: Jack C.
-- Description: Renders every dodgeball in the world: clones the equipped ball cosmetic, smooths replicated ball positions, drives held/windup/flight/bounce effects and squash-stretch springs, and predicts the local player's own throws.
-- Created: 2026-07-12

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local ProjectileTrajectory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Sim")
		:WaitForChild("ProjectileTrajectory")
)
local CosmeticVisualFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CosmeticVisualFactory")
)
local ChargeAim = require(script.Parent.ChargeAim)
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local Util = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Util")
local Spring = require(Util:WaitForChild("Spring"))
local CharacterRig = require(script.Parent.CharacterRig)
local CombatState = require(script.Parent.CombatState)
local EquippedWeapon = require(script.Parent.EquippedWeapon)
local WorldAudio = require(script.Parent.WorldAudio)

local BallVisuals = {}

local HELD_PHASE = 0
local IN_FLIGHT_PHASE = 2
local FREE_PHASE = 5
local TRAIL_ACTIVE_PHASES = {
	[2] = true,
	[3] = true,
	[4] = true,
}

type PredictedThrow = {
	ball: BasePart,
	position: Vector3,
	velocity: Vector3,
	elapsed: number,
}

type FeelState = {
	spring: Spring.Spring,
	baseSize: Vector3,
	impactNormal: Vector3?,
	spinAngle: number,
	elapsed: number,
}

type RestPulseState = {
	highlight: Highlight,
	elapsed: number,
}

local visuals: { [BasePart]: BasePart } = {}
local appliedAssets: { [BasePart]: string } = {}
local restPulses: { [BasePart]: RestPulseState } = {}
local feelStates: { [BasePart]: FeelState } = {}
local trailEnabled: { [BasePart]: boolean } = {}
local seen = EventDedup.new(4096)
local predicted: PredictedThrow? = nil
local lastReleaseRevision = 0

local function cframeOffset(offset: Vector3): CFrame
	return CFrame.new(offset.x, offset.y, offset.z)
end

local function characterForPlayerId(playerId: string?): Model?
	local player = PlayerIds.fromId(playerId)
	return player and player.Character
end

local function heldVisualCFrame(ball: BasePart): CFrame?
	local character = characterForPlayerId(ball:GetAttribute("hb") :: string?)
	local grip = CharacterRig.dodgeballGripCFrame(character)
	if grip then
		return grip
	end
	local hand = CharacterRig.rightHand(character)
	if hand then
		return hand.CFrame * cframeOffset(Combat.Dodgeball.HeldVisualHandOffset)
	end
	local root = CharacterRig.rootPart(character)
	if root then
		return root.CFrame
	end
	return nil
end

local function setEnabled(root: Instance, className: string, enabled: boolean)
	for _, child in root:GetDescendants() do
		if child:IsA(className) then
			(child :: any).Enabled = enabled
		end
	end
end

local function ownerFor(ball: BasePart): Player?
	return PlayerIds.fromId(ball:GetAttribute("ow") :: string?)
end

local SOUNDLESS_EFFECTS = { Throw = true, Bounce = true }

local function playOptional(ball: BasePart, name: string, intensity: number?)
	local strength = intensity or 1
	if not SOUNDLESS_EFFECTS[name] then
		WorldAudio.play(
			"Dodgeball",
			name,
			ball,
			math.clamp(strength, 0.65, 1.35),
			0.96 + math.clamp(strength, 0, 1.5) * 0.08
		)
	end
	local emitter = ball:FindFirstChild(name, true)
	if emitter and emitter:IsA("ParticleEmitter") then
		local count = (emitter:GetAttribute("BurstCount") :: number?) or 8
		emitter:Emit(math.max(2, math.floor(count * strength + 0.5)))
	end
end

local function destroyRestPulse(ball: BasePart)
	local state = restPulses[ball]
	if state then
		state.highlight:Destroy()
	end
	restPulses[ball] = nil
end

local function updateRestPulse(ball: BasePart, visual: BasePart, active: boolean, dt: number)
	if not active then
		destroyRestPulse(ball)
		return
	end

	local config = Combat.Dodgeball.RestPulse
	local state = restPulses[ball]
	if state == nil or state.highlight.Parent ~= visual then
		destroyRestPulse(ball)
		local highlight = Instance.new("Highlight")
		highlight.Name = "RestGoldPulse"
		highlight.Adornee = visual
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = config.FillColor
		highlight.OutlineColor = config.OutlineColor
		highlight.Parent = visual
		state = {
			highlight = highlight,
			elapsed = 0,
		}
		restPulses[ball] = state
	end

	state.elapsed += dt
	local wave = (math.sin(state.elapsed * config.CyclesPerSecond * math.pi * 2 - math.pi * 0.5) + 1) * 0.5
	state.highlight.FillTransparency = config.DimFillTransparency
		+ (config.BrightFillTransparency - config.DimFillTransparency) * wave
	state.highlight.OutlineTransparency = config.DimOutlineTransparency
		+ (config.BrightOutlineTransparency - config.DimOutlineTransparency) * wave
end

local function effectiveAssetId(ball: BasePart): string
	local owner = ownerFor(ball)
	if owner == nil then
		return ""
	end
	local itemId = (owner:GetAttribute("Equip_BallAssets") :: string?) or ""
	local item = Cosmetics.Items[itemId]
	return if item and item.Category == "BallAssets" and item.Visual ~= nil then itemId else ""
end

local function feelFor(ball: BasePart, visual: BasePart): FeelState
	local state = feelStates[ball]
	if state == nil then
		state = {
			spring = Spring.new(0),
			baseSize = visual.Size,
			impactNormal = nil,
			spinAngle = 0,
			elapsed = 0,
		}
		feelStates[ball] = state
	end
	return state
end

local function deformationScale(stretch: number): Vector3
	local along = math.max(1 + stretch, 0.58)
	local cross = math.pow(along, -0.5)
	return Vector3.new(cross, cross, along)
end

local function eventVector(value: any): Vector3?
	if typeof(value) == "Vector3" then
		return value
	elseif typeof(value) == "Vector3" then
		return Vector3.new(value.x, value.y, value.z)
	end
	return nil
end

local function buildVisual(ball: BasePart, assetId: string): BasePart
	local visual = CosmeticVisualFactory.create("BallAssets", if assetId == "" then nil else assetId)
	visual.Name = `{ball.Name}_Visual`
	visual.Anchored = true
	visual.LocalTransparencyModifier = 0
	visual.CanCollide = false
	visual.CanQuery = false
	visual.CanTouch = false
	visual.Parent = Workspace.CurrentCamera
	return visual
end

local function addBall(ball: BasePart)
	if visuals[ball] then
		return
	end
	local assetId = effectiveAssetId(ball)
	local visual = buildVisual(ball, assetId)
	ball.LocalTransparencyModifier = 1
	visuals[ball] = visual
	appliedAssets[ball] = assetId
	feelFor(ball, visual)
end

local function removeBall(ball: BasePart)
	destroyRestPulse(ball)
	local visual = visuals[ball]
	if visual then
		visual:Destroy()
	end
	visuals[ball] = nil
	appliedAssets[ball] = nil
	feelStates[ball] = nil
	trailEnabled[ball] = nil
end

local function refreshAsset(ball: BasePart)
	local assetId = effectiveAssetId(ball)
	if appliedAssets[ball] == assetId then
		return
	end
	local previous = visuals[ball]
	destroyRestPulse(ball)
	local visual = buildVisual(ball, assetId)
	if previous then
		visual.CFrame = previous.CFrame
		previous:Destroy()
	end
	visuals[ball] = visual
	appliedAssets[ball] = assetId
	feelStates[ball] = nil
	trailEnabled[ball] = nil
	feelFor(ball, visual)
end

function BallVisuals.onEvent(event: any)
	if not seen.markSeen(event) then
		return
	end
	local folder = Workspace:FindFirstChild("Balls")
	local ball = folder and event.projectileId and folder:FindFirstChild(event.projectileId)
	if ball == nil or not ball:IsA("BasePart") then
		return
	end
	if event.kind == "BallSettled" then
		refreshAsset(ball)
	elseif event.kind == "BallBounced" then
		local visual = visuals[ball]
		if visual then
			local state = feelFor(ball, visual)
			state.impactNormal = eventVector(event.normal)
			local magnitude = math.max((event.magnitude :: number?) or 0, 0)
			local impulse = math.min(
				magnitude * Combat.Dodgeball.BallFeel.ImpactImpulseScale,
				Combat.Dodgeball.BallFeel.MaxImpactSquash * 18
			)
			Spring.impulse(state.spring, -impulse)
		end
	end
	local visual = visuals[ball]
	if visual == nil then
		return
	end
	local effectNames = {
		BallWindup = "Windup",
		BallReleased = "Throw",
		BallBounced = "Bounce",
		BallSettled = "Landing",
		BallPickedUp = "Pickup",
		BallCaught = "Pickup",
	}
	local effect = effectNames[event.kind]
	if effect then
		local intensity = 1
		if event.kind == "BallBounced" then
			local magnitude = (event.magnitude :: number?) or 0
			intensity = math.clamp(magnitude * (1 / Combat.Dodgeball.BallFeel.HeavyImpactSpeed), 0.35, 1.35)
		end
		playOptional(visual, effect, intensity)
	end
end

local function beginPrediction(snapshot: CombatState.Snapshot, localId: string)
	predicted = nil
	local aim = snapshot.releaseAim
	if aim == nil then
		return
	end
	local thrown: BasePart? = nil
	for candidate in visuals do
		if candidate:GetAttribute("hb") == localId and candidate:GetAttribute("ph") == HELD_PHASE then
			thrown = candidate
			break
		end
	end
	if thrown == nil then
		return
	end
	local cfg = Combat.Dodgeball
	local root = CharacterRig.rootPart(Players.LocalPlayer.Character)
	local inherited = if root then root.AssemblyLinearVelocity * cfg.MomentumInheritance else Vector3.zero
	local launchVelocity = ChargeAim.recentLaunchVelocity(aim, snapshot.releaseCharge)
		or aim * ProjectileTrajectory.launchSpeed(cfg, snapshot.releaseCharge) + inherited
	predicted = {
		ball = thrown,
		position = (visuals[thrown] :: BasePart).Position,
		velocity = launchVelocity,
		elapsed = 0,
	}
end

local function stepPrediction(dt: number)
	local active = predicted
	if active == nil then
		return
	end
	active.elapsed += dt
	if
		active.ball.Parent == nil
		or active.ball:GetAttribute("ph") ~= HELD_PHASE
		or active.elapsed > Combat.Dodgeball.Prediction.MaxSeconds
	then
		predicted = nil
		return
	end
	active.velocity -= Vector3.new(0, Combat.Dodgeball.Gravity * dt, 0)
	active.position += active.velocity * dt
end

function BallVisuals.start()
	local folder = Workspace:WaitForChild("Balls")
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			addBall(child)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			addBall(child)
		end
	end)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			removeBall(child)
		end
	end)

	RunService:BindToRenderStep("BallVisuals", Enum.RenderPriority.Character.Value + 2, function(dt)
		local alpha = 1 - math.exp(-Combat.Dodgeball.RemoteSmoothing * dt)
		local lead = math.min(
			Players.LocalPlayer:GetNetworkPing() + 1 / Combat.Dodgeball.RemoteSmoothing,
			Combat.Dodgeball.MaxLatencyExtrapolation
		)
		local localId = PlayerIds.toId(Players.LocalPlayer)
		local feelConfig = Combat.Dodgeball.BallFeel
		local snapshot = CombatState.getSnapshot()
		if snapshot.releaseRevision ~= lastReleaseRevision then
			lastReleaseRevision = snapshot.releaseRevision
			beginPrediction(snapshot, localId)
		end
		stepPrediction(dt)
		for ball, visual in visuals do
			if ball.Parent == nil then
				removeBall(ball)
				continue
			end
			refreshAsset(ball)
			visual = visuals[ball] :: BasePart
			local activePrediction = if predicted ~= nil and predicted.ball == ball then predicted else nil
			local phase = if activePrediction then IN_FLIGHT_PHASE else ball:GetAttribute("ph")
			local isLocalHeld = ball:GetAttribute("hb") == localId
			local isChargeAiming = snapshot.state == "Charging" and snapshot.weapon == "Dodgeball" and isLocalHeld
			local holder = PlayerIds.fromId(ball:GetAttribute("hb") :: string?)
			local stowed = phase == HELD_PHASE and holder ~= nil and not EquippedWeapon.isShowing(holder, "Dodgeball")
			visual.Transparency = if stowed then 1 elseif isChargeAiming then feelConfig.ChargeAimTransparency else 0
			local heldCFrame = if phase == 0 or phase == 1 then heldVisualCFrame(ball) else nil
			local immediate = ball:GetAttribute("hb") == localId or phase == 1
			local state = feelFor(ball, visual)
			local heldBlend = if isLocalHeld then 1 - math.exp(-dt * 22) else 1
			local velocity = ball:GetAttribute("vel")
			local velocityVector = if activePrediction
				then activePrediction.velocity
				elseif typeof(velocity) == "Vector3" then velocity
				else Vector3.zero
			local speed = velocityVector.Magnitude

			state.elapsed += dt
			if isChargeAiming then
				state.spring.target = -snapshot.chargeAlpha * feelConfig.ChargeSquash
			elseif phase == 2 then
				state.spring.target = math.min(speed * feelConfig.FlightStretchPerSpeed, feelConfig.MaxFlightStretch)
			elseif phase == 4 then
				state.spring.target = math.sin(state.elapsed * feelConfig.RollWobbleHz * math.pi * 2)
					* feelConfig.RollWobbleScale
			else
				state.spring.target = 0
			end
			Spring.step(state.spring, feelConfig.SpringFrequencyHz, feelConfig.SpringDampingRatio, dt)
			local stretch = math.clamp(state.spring.position, -feelConfig.MaxImpactSquash, feelConfig.MaxFlightStretch)
			local scale = deformationScale(stretch)
			local restingSize = Vector3.new(4, 4, 4)
			local visualSize = if phase == FREE_PHASE
				then restingSize
				else Vector3.new(
					state.baseSize.X * scale.X,
					state.baseSize.Y * scale.Y,
					state.baseSize.Z * scale.Z
				)
			visual.Size = visualSize

			local renderPosition = if activePrediction
				then activePrediction.position
				elseif phase == IN_FLIGHT_PHASE then ball.Position + velocityVector * lead
				else ball.Position
			local targetCFrame = heldCFrame or (ball.CFrame.Rotation + renderPosition)
			if phase == FREE_PHASE then
				local extraY = (restingSize.Y - state.baseSize.Y) / 2
				targetCFrame = CFrame.new(renderPosition + Vector3.new(0, extraY, 0)) * ball.CFrame.Rotation
			end
			if heldCFrame == nil and speed > 0.05 then
				local direction = velocityVector.Unit
				if stretch < -0.015 and state.impactNormal then
					direction = state.impactNormal.Unit
				elseif stretch >= -0.015 then
					state.impactNormal = nil
				end
				state.spinAngle = (state.spinAngle + speed / math.max(Combat.Dodgeball.Radius, 0.01) * dt)
					% (math.pi * 2)
				targetCFrame = CFrame.lookAt(renderPosition, renderPosition + direction)
					* CFrame.Angles(0, 0, state.spinAngle)
			end
			if activePrediction then
				visual.CFrame = targetCFrame
			elseif isLocalHeld then
				visual.CFrame = visual.CFrame:Lerp(targetCFrame, heldBlend)
			else
				visual.CFrame = if immediate then targetCFrame else visual.CFrame:Lerp(targetCFrame, alpha)
			end

			updateRestPulse(ball, visual, phase == FREE_PHASE, dt)
			local trailActive = TRAIL_ACTIVE_PHASES[phase] == true
			if trailEnabled[ball] ~= trailActive then
				trailEnabled[ball] = trailActive
				setEnabled(visual, "Trail", trailActive)
			end
		end
	end)
end

return BallVisuals
