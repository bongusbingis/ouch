--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local CosmeticVisualFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CosmeticVisualFactory")
)
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local Util = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Util")
local Spring = require(Util:WaitForChild("Spring"))
local CharacterRig = require(script.Parent.CharacterRig)
local TrailVisuals = require(script.Parent.TrailVisuals)
local WorldAudio = require(script.Parent.WorldAudio)

local BallVisuals = {}

local FREE_PHASE = 5
local TRAIL_ACTIVE_PHASES = {
	[2] = true,
	[3] = true,
	[4] = true,
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
local appliedTrails: { [BasePart]: string } = {}
local trailHandles: { [BasePart]: TrailVisuals.Handle } = {}
local restPulses: { [BasePart]: RestPulseState } = {}
local feelStates: { [BasePart]: FeelState } = {}
local seen = EventDedup.new(4096)

local function cframeOffset(offset: vector): CFrame
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
		if child:IsA(className) and child:GetAttribute("ProceduralTrailCosmetic") ~= true then
			(child :: any).Enabled = enabled
		end
	end
end

local function ownerFor(ball: BasePart): Player?
	return PlayerIds.fromId(ball:GetAttribute("ow") :: string?)
end

local function playOptional(ball: BasePart, name: string, intensity: number?)
	local strength = intensity or 1
	WorldAudio.play(
		"Dodgeball",
		name,
		ball,
		math.clamp(strength, 0.65, 1.35),
		0.96 + math.clamp(strength, 0, 1.5) * 0.08
	)
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
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
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

-- The ball keeps its last owner's equipped asset after release and settlement.
-- Recovery clears ownership, returning genuinely neutral balls to the default.
local function effectiveAssetId(ball: BasePart): string
	local owner = ownerFor(ball)
	if owner == nil then
		return ""
	end
	local itemId = (owner:GetAttribute("Equip_BallAssets") :: string?) or ""
	local item = Cosmetics.Items[itemId]
	return if item and item.Category == "BallAssets" and item.Visual ~= nil then itemId else ""
end

local function effectiveTrailId(ball: BasePart): (string, string?)
	local owner = ownerFor(ball)
	if owner == nil then
		return "", nil
	end
	local itemId = (owner:GetAttribute("Equip_TrailAssets") :: string?) or ""
	local item = Cosmetics.Items[itemId]
	if item == nil or item.Category ~= "TrailAssets" or item.EffectId == nil then
		return "", nil
	end
	return itemId, item.EffectId
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
	elseif typeof(value) == "vector" then
		return Vector3.new(value.x, value.y, value.z)
	end
	return nil
end

local function destroyTrail(ball: BasePart)
	local handle = trailHandles[ball]
	if handle then
		handle:destroy()
	end
	trailHandles[ball] = nil
	appliedTrails[ball] = nil
end

local function refreshTrail(ball: BasePart, force: boolean?)
	local itemId, effectId = effectiveTrailId(ball)
	if not force and appliedTrails[ball] == itemId then
		return
	end
	destroyTrail(ball)
	appliedTrails[ball] = itemId
	local visual = visuals[ball]
	if visual and effectId then
		trailHandles[ball] = TrailVisuals.mount(visual, effectId)
	end
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
	refreshTrail(ball, true)
end

local function removeBall(ball: BasePart)
	destroyRestPulse(ball)
	destroyTrail(ball)
	local visual = visuals[ball]
	if visual then
		visual:Destroy()
	end
	visuals[ball] = nil
	appliedAssets[ball] = nil
	feelStates[ball] = nil
end

local function refreshAsset(ball: BasePart)
	local assetId = effectiveAssetId(ball)
	if appliedAssets[ball] == assetId then
		return
	end
	local previous = visuals[ball]
	destroyRestPulse(ball)
	destroyTrail(ball)
	local visual = buildVisual(ball, assetId)
	if previous then
		visual.CFrame = previous.CFrame
		previous:Destroy()
	end
	visuals[ball] = visual
	appliedAssets[ball] = assetId
	feelStates[ball] = nil
	feelFor(ball, visual)
	refreshTrail(ball, true)
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

	RunService.RenderStepped:Connect(function(dt)
		local alpha = 1 - math.exp(-Combat.Dodgeball.RemoteSmoothing * dt)
		local localId = PlayerIds.toId(Players.LocalPlayer)
		local feelConfig = Combat.Dodgeball.BallFeel
		for ball, visual in visuals do
			if ball.Parent == nil then
				removeBall(ball)
				continue
			end
			refreshAsset(ball)
			refreshTrail(ball)
			visual = visuals[ball] :: BasePart
			local phase = ball:GetAttribute("ph")
			local heldCFrame = if phase == 0 or phase == 1 then heldVisualCFrame(ball) else nil
			local immediate = ball:GetAttribute("hb") == localId or phase == 1
			local state = feelFor(ball, visual)
			local velocity = ball:GetAttribute("vel")
			local velocityVector = if typeof(velocity) == "Vector3" then velocity else Vector3.zero
			local speed = velocityVector.Magnitude

			state.elapsed += dt
			if phase == 2 then
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
			visual.Size =
				Vector3.new(state.baseSize.X * scale.X, state.baseSize.Y * scale.Y, state.baseSize.Z * scale.Z)

			local targetCFrame = heldCFrame or ball.CFrame
			if heldCFrame == nil and speed > 0.05 then
				local direction = velocityVector.Unit
				if stretch < -0.015 and state.impactNormal then
					direction = state.impactNormal.Unit
				elseif stretch >= -0.015 then
					state.impactNormal = nil
				end
				state.spinAngle = (state.spinAngle + speed / math.max(Combat.Dodgeball.Radius, 0.01) * dt)
					% (math.pi * 2)
				targetCFrame = CFrame.lookAt(ball.Position, ball.Position + direction)
					* CFrame.Angles(0, 0, state.spinAngle)
			end
			visual.CFrame = if immediate then targetCFrame else visual.CFrame:Lerp(targetCFrame, alpha)

			updateRestPulse(ball, visual, phase == FREE_PHASE, dt)
			local trailActive = TRAIL_ACTIVE_PHASES[phase] == true
			setEnabled(visual, "Trail", trailActive)
			local trailHandle = trailHandles[ball]
			if trailHandle then
				trailHandle:setEnabled(trailActive)
			end
		end
	end)
end

return BallVisuals
