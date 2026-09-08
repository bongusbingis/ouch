-- Description: Computes and renders the predicted throw trajectory while charging, sweeping the arc against world geometry and characters to find the impact point and driving the aiming field-of-view change.

--!strict

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local AimAssist = require(Config:WaitForChild("Gameplay"):WaitForChild("AimAssist"))
local Combat = require(Config:WaitForChild("Gameplay"):WaitForChild("Combat"))
local MobileInput = require(Config:WaitForChild("Interface"):WaitForChild("MobileInput"))
local ThrowUX = require(Config:WaitForChild("Interface"):WaitForChild("ThrowUX"))
local SharedGame = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
local Adapters = SharedGame:WaitForChild("Adapters")
local Sim = SharedGame:WaitForChild("Sim")
local CollisionWorld = require(Sim:WaitForChild("CollisionWorld"))
local Intercept = require(Sim:WaitForChild("Intercept"))
local ProjectileTrajectory = require(Sim:WaitForChild("ProjectileTrajectory"))
local DodgeballRelease = require(Adapters:WaitForChild("DodgeballRelease"))
local AimDirector = require(script.Parent.Parent.Input.AimDirector)
local AssistConfig = require(script.Parent.Parent.Input.AssistConfig)
local CombatState = require(script.Parent.CombatState)

local ChargeAim = {}

export type Dot = { position: Vector2, size: number, transparency: number, visible: boolean }
export type Snapshot = { active: boolean, chargeAlpha: number, points: { Dot }, endpoint: Vector2? }

type Vec = vector
type HomingTarget = { position: Vec, velocity: Vec }
type CollisionCharacter = {
	position: Vec,
	velocity: Vec,
	halfAxis: number,
	radius: number,
}

local POINT_COUNT = math.max(Combat.Dodgeball.Preview.Segments, 2)
local TOTAL_QUERY_BUDGET = math.max(Combat.Dodgeball.Preview.ImpactSamples, 2)
local PATH_QUERY_BUDGET = math.max(TOTAL_QUERY_BUDGET - 1, 1)
local EMPTY: Snapshot = { active = false, chargeAlpha = 0, points = {}, endpoint = nil }
local activePoints: { Dot } = {}
for index = 1, POINT_COUNT do
	activePoints[index] = { position = Vector2.zero, size = 0, transparency = 1, visible = false }
end
local activeSnapshot: Snapshot = { active = true, chargeAlpha = 0, points = activePoints, endpoint = nil }

local started = false
local connection: RBXScriptConnection? = nil
local renderer: ((Snapshot) -> ())? = nil
local physicsAccumulated = 0
local displayAccumulated = 0
local renderedActive = false
local activeCamera: Camera? = nil
local chargeBaseFov: number? = nil
local lastCamera: Camera? = nil
local pathCharacter: Model? = nil
local pathTarget: Model? = nil
local pathValid = false
local displayPointCount = 0
local lastScreenPoints: { [number]: Vector2 } = {}
local simulationPoints: { Vec } = {}
local displayWorldPoints: { Vec } = {}
local arcDistances: { number } = {}

local latestLaunchVelocity: Vector3? = nil
local latestRawAim: Vector3? = nil
local latestCharge = 0
local latestLaunchAt = 0

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.RespectCanCollide = true
local exclusions: { Instance } = {}
local collisionCharacters: { CollisionCharacter } = {}
local homingTarget: HomingTarget = { position = vector.zero, velocity = vector.zero }
local sampleParams: ProjectileTrajectory.SampleParams = {
	origin = vector.zero,
	velocity = vector.zero,
	gravity = vector.zero,
	duration = 0,
	radius = 1,
	sampleCount = POINT_COUNT,
	target = nil,
	turnRateRad = nil,
	breakAngleRad = nil,
}

local function toVec(value: Vector3): Vec
	return vector.create(value.X, value.Y, value.Z)
end

local function toVector3(value: Vec): Vector3
	return Vector3.new(value.x, value.y, value.z)
end

local function renderEmpty()
	table.clear(lastScreenPoints)
	renderedActive = false
	if renderer then
		renderer(EMPTY)
	end
end

local function updateFov(camera: Camera, charging: boolean, chargeAlpha: number, dt: number)
	charging = charging and not GuiService.ReducedMotionEnabled
	if camera ~= activeCamera then
		if activeCamera ~= nil and chargeBaseFov ~= nil then
			activeCamera.FieldOfView = chargeBaseFov
		end
		activeCamera = camera
		chargeBaseFov = nil
	end
	if charging and chargeBaseFov == nil then
		chargeBaseFov = camera.FieldOfView
	end
	local base = chargeBaseFov
	if base == nil then
		return
	end
	local target = if charging
		then math.clamp(base + Combat.Dodgeball.Preview.FovAtFullCharge * chargeAlpha, 1, 120)
		else base
	local blend = 1 - math.exp(-dt * Combat.Dodgeball.Preview.FovFrequency)
	camera.FieldOfView += (target - camera.FieldOfView) * blend
	if not charging and math.abs(camera.FieldOfView - base) < 0.05 then
		camera.FieldOfView = base
		chargeBaseFov = nil
	end
end

local function refreshExclusions()
	table.clear(exclusions)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(exclusions, character)
		end
	end
	local balls = Workspace:FindFirstChild("Balls")
	if balls ~= nil then
		table.insert(exclusions, balls)
	end
	raycastParams.FilterDescendantsInstances = exclusions
end

local function staticSweep(origin: Vec, displacement: Vec): (number?, Vec?, Vec?)
	local distance = vector.magnitude(displacement)
	if distance <= 1e-6 then
		return nil, nil, nil
	end
	local result =
		Workspace:Spherecast(toVector3(origin), Combat.Dodgeball.Radius, toVector3(displacement), raycastParams)
	if result == nil then
		return nil, nil, nil
	end
	local fraction = math.clamp(result.Distance / distance, 0, 1)
	return fraction, origin + displacement * fraction, toVec(result.Normal)
end

local function refreshCollisionCharacters(localCharacter: Model): number
	local count = 0
	local localTeamId = localCharacter:GetAttribute("TeamId")
	local capsule = Combat.CharacterCapsule
	local halfAxis = math.max(capsule.Height / 2 - capsule.Radius, 0)
	for _, player in Players:GetPlayers() do
		if player == Players.LocalPlayer then
			continue
		end
		local admission = player:GetAttribute("ArenaAdmission")
		if (admission ~= "Direct" and admission ~= "Matched") or player:GetAttribute("ArenaReady") ~= true then
			continue
		end
		local character = player.Character
		if
			character == nil
			or character:GetAttribute("CombatAlive") == false
			or character:GetAttribute("minv") == true
			or (localTeamId ~= nil and character:GetAttribute("TeamId") == localTeamId)
		then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		count += 1
		local row = collisionCharacters[count]
		if row == nil then
			row = { position = vector.zero, velocity = vector.zero, halfAxis = halfAxis, radius = capsule.Radius }
			collisionCharacters[count] = row
		end
		row.position = toVec(root.Position)
		row.velocity = toVec(root.AssemblyLinearVelocity)
		row.halfAxis = halfAxis
		row.radius = capsule.Radius
	end
	for index = #collisionCharacters, count + 1, -1 do
		collisionCharacters[index] = nil
	end
	return count
end

local function characterSweep(
	from: Vec,
	to: Vec,
	startTime: number,
	endTime: number,
	characterCount: number,
	effectiveRadius: number
): (number?, Vec?)
	local bestFraction = math.huge
	local bestPosition: Vec? = nil
	for index = 1, characterCount do
		local character = collisionCharacters[index]
		local startCenter = character.position + character.velocity * startTime
		local endCenter = character.position + character.velocity * endTime
		local capOffset = vector.create(0, character.halfAxis, 0)
		local hit = CollisionWorld.sweptSphereVsCapsule(
			from - startCenter,
			to - endCenter,
			effectiveRadius + character.radius,
			-capOffset,
			capOffset
		)
		if hit ~= nil and hit.fraction < bestFraction then
			bestFraction = hit.fraction
			bestPosition = from + (to - from) * hit.fraction
		end
	end
	return if bestPosition ~= nil then bestFraction else nil, bestPosition
end

local function segmentImpact(
	from: Vec,
	to: Vec,
	startTime: number,
	endTime: number,
	characterCount: number,
	effectiveRadius: number
): (number?, Vec?, Vec?)
	local staticFraction, staticPosition, staticNormal = staticSweep(from, to - from)
	local characterFraction, characterPosition =
		characterSweep(from, to, startTime, endTime, characterCount, effectiveRadius)
	if characterFraction ~= nil and (staticFraction == nil or characterFraction <= staticFraction) then
		return characterFraction, characterPosition, nil
	end
	return staticFraction, staticPosition, staticNormal
end

local function timeForPoint(index: number, count: number, duration: number): number
	return ((index - 1) / (count - 1)) * duration
end

local function traceImpact(count: number, duration: number, characterCount: number, effectiveRadius: number)
	local intervals = math.min(PATH_QUERY_BUDGET, count - 1)
	for interval = 1, intervals do
		local startIndex = math.floor(((interval - 1) * (count - 1)) / intervals) + 1
		local endIndex = math.floor((interval * (count - 1)) / intervals) + 1
		local startTime = timeForPoint(startIndex, count, duration)
		local endTime = timeForPoint(endIndex, count, duration)
		local fraction, position, normal = segmentImpact(
			simulationPoints[startIndex],
			simulationPoints[endIndex],
			startTime,
			endTime,
			characterCount,
			effectiveRadius
		)
		if fraction ~= nil then
			return startTime + (endTime - startTime) * fraction, position, normal
		end
	end
	return duration, nil, nil
end

local function targetMotion(target: Model?): (HomingTarget?, number)
	if target == nil then
		return nil, 0
	end
	local root = target:FindFirstChild("HumanoidRootPart")
	local velocity, consistency = AimDirector.targetMotion(target)
	if root == nil or not root:IsA("BasePart") or velocity == nil then
		return nil, 0
	end
	homingTarget.position = toVec(root.Position)
	homingTarget.velocity = toVec(velocity)
	return homingTarget, consistency
end

local function samplePath(
	origin: Vec,
	velocity: Vec,
	duration: number,
	target: HomingTarget?,
	turnRateRad: number?,
	breakAngleRad: number?
): number
	sampleParams.origin = origin
	sampleParams.velocity = velocity
	sampleParams.gravity = vector.create(0, -Combat.Dodgeball.Gravity, 0)
	sampleParams.duration = duration
	sampleParams.radius = Combat.Dodgeball.Radius
	sampleParams.sampleCount = POINT_COUNT
	sampleParams.target = target
	sampleParams.turnRateRad = turnRateRad
	sampleParams.breakAngleRad = breakAngleRad
	return ProjectileTrajectory.sampleInto(sampleParams, simulationPoints)
end

local function resampleForDistance(sourceCount: number): number
	table.clear(arcDistances)
	arcDistances[1] = 0
	local totalDistance = 0
	for index = 2, sourceCount do
		totalDistance += vector.magnitude(simulationPoints[index] - simulationPoints[index - 1])
		arcDistances[index] = totalDistance
	end
	if sourceCount == 1 or totalDistance <= 1e-6 then
		displayWorldPoints[1] = simulationPoints[1]
		return 1
	end

	local settings = ThrowUX.Trajectory
	local spacing = settings.WorldDotSpacingStuds
	local minimumDots = math.min(settings.MinimumVisibleDots, POINT_COUNT)
	local minimumSpan = spacing * (minimumDots - 1)
	local regularSegments = math.floor(totalDistance / spacing)
	local remainder = totalDistance - regularSegments * spacing
	local hasEndpointRemainder = remainder > 1e-4
	local desired = if totalDistance < minimumSpan
		then minimumDots
		else math.min(regularSegments + 1 + (if hasEndpointRemainder then 1 else 0), POINT_COUNT)
	local sourceIndex = 2
	for index = 1, desired do
		local distance = if totalDistance < minimumSpan
			then totalDistance * ((index - 1) / (desired - 1))
			elseif index == desired and (hasEndpointRemainder or desired == POINT_COUNT) then totalDistance
			else math.min((index - 1) * spacing, totalDistance)
		while sourceIndex < sourceCount and arcDistances[sourceIndex] < distance do
			sourceIndex += 1
		end
		local previousIndex = math.max(sourceIndex - 1, 1)
		local before = arcDistances[previousIndex]
		local after = arcDistances[sourceIndex]
		local alpha = if after > before then math.clamp((distance - before) / (after - before), 0, 1) else 0
		displayWorldPoints[index] = simulationPoints[previousIndex]
			+ (simulationPoints[sourceIndex] - simulationPoints[previousIndex]) * alpha
	end
	for index = #displayWorldPoints, desired + 1, -1 do
		displayWorldPoints[index] = nil
	end
	return desired
end

local function rebuildWorldPath(character: Model, chargeAlpha: number): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	local rawAim = AimDirector.currentAim()
	if root == nil or not root:IsA("BasePart") or rawAim.Magnitude <= 1e-6 then
		return false
	end
	refreshExclusions()
	local characterCount = refreshCollisionCharacters(character)
	local deviceClass = AimDirector.deviceClass()
	local row = AimAssist[deviceClass] or AimAssist.Mouse
	local targetModel = if AssistConfig.strength("ConeSnap", deviceClass) > 0
		then AimDirector.currentTrajectoryTarget()
		else nil
	local target, consistency = targetMotion(targetModel)
	if target == nil then
		targetModel = nil
	end
	local aim = toVec(rawAim.Unit)
	local aimOrigin = toVec(root.Position + rawAim.Unit * 2)
	if target ~= nil then
		local leadStrength = AssistConfig.strength("Lead", deviceClass)
		if leadStrength > 0 then
			local intercept = Intercept.solve(aimOrigin, target.position, target.velocity, Combat.Dodgeball.ThrowSpeed)
			aim = Intercept.biasAim(
				aim,
				aimOrigin,
				intercept,
				leadStrength * consistency,
				math.rad(MobileInput.Assist.MaxLeadAngleDeg)
			)
		end
	end

	local releaseBase = toVec(DodgeballRelease.position(character, root, Combat.Dodgeball.OverhandReleaseRootOffset))
	local releaseDisplacement = aim * Combat.Dodgeball.ReleaseForwardOffset
	local _, blockedPosition, blockedNormal = staticSweep(releaseBase, releaseDisplacement)
	local origin = if blockedPosition ~= nil and blockedNormal ~= nil
		then blockedPosition + blockedNormal * Combat.Dodgeball.ContactSeparation
		else releaseBase + releaseDisplacement
	local velocity =
		ProjectileTrajectory.launchVelocity(Combat.Dodgeball, aim, toVec(root.AssemblyLinearVelocity), chargeAlpha)
	local turnRateRad = if target ~= nil
		then math.rad(Combat.Dodgeball.HomingTurnRateDeg) * row.HomingTurnScale
		else nil
	local breakAngleRad = if target ~= nil then math.rad(Combat.Dodgeball.HomingBreakAngleDeg) else nil

	if character ~= pathCharacter or targetModel ~= pathTarget then
		table.clear(lastScreenPoints)
	end
	pathCharacter = character
	pathTarget = targetModel
	latestLaunchVelocity = toVector3(velocity)
	latestRawAim = rawAim.Unit
	latestCharge = chargeAlpha
	latestLaunchAt = os.clock()

	local count = samplePath(origin, velocity, Combat.Dodgeball.MaxFlightTime, target, turnRateRad, breakAngleRad)
	local effectiveRadius = Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness + row.MagnetismRadius
	local impactTime, impactPosition, impactNormal =
		traceImpact(count, Combat.Dodgeball.MaxFlightTime, characterCount, effectiveRadius)
	if impactPosition ~= nil then
		count = samplePath(origin, velocity, impactTime, target, turnRateRad, breakAngleRad)
		if impactNormal ~= nil then
			impactPosition += impactNormal * Combat.Dodgeball.ContactSeparation
		end
		simulationPoints[count] = impactPosition
	end
	displayPointCount = resampleForDistance(count)
	pathValid = true
	return true
end

local function localGap(index: number): number
	local distance = 0
	local sides = 0
	if index > 1 then
		distance += vector.magnitude(displayWorldPoints[index] - displayWorldPoints[index - 1])
		sides += 1
	end
	if index < displayPointCount then
		distance += vector.magnitude(displayWorldPoints[index + 1] - displayWorldPoints[index])
		sides += 1
	end
	return if sides > 0 then distance / sides else 0
end

local function projectSnapshot(camera: Camera, character: Model, chargeAlpha: number)
	if not pathValid or character ~= pathCharacter or displayPointCount == 0 then
		renderEmpty()
		return
	end
	if camera ~= lastCamera then
		table.clear(lastScreenPoints)
		lastCamera = camera
	end

	local settings = ThrowUX.Trajectory
	local opacity = settings.MinimumOpacity + (settings.MaximumOpacity - settings.MinimumOpacity) * chargeAlpha
	local endpoint: Vector2? = nil
	local viewport = camera.ViewportSize
	for index = 1, displayPointCount do
		local projected, onScreen = camera:WorldToViewportPoint(toVector3(displayWorldPoints[index]))
		local rawDisplay = Vector2.new(projected.X, projected.Y)
		local display = rawDisplay
		local previous = lastScreenPoints[index]
		if previous ~= nil and (rawDisplay - previous).Magnitude <= settings.MaximumSmoothingDistancePixels then
			display = previous:Lerp(rawDisplay, settings.ScreenSmoothing)
		end
		lastScreenPoints[index] = display
		local pathAlpha = if displayPointCount > 1 then (index - 1) / (displayPointCount - 1) else 0
		local gapScale = math.clamp(localGap(index) / settings.WorldDotSpacingStuds, 0.75, 1.15)
		local point = activePoints[index]
		point.position = Vector2.new(math.clamp(display.X, 0, viewport.X), math.clamp(display.Y, 0, viewport.Y))
		point.size = (
			settings.MinimumDotPixels
			+ (settings.MaximumDotPixels - settings.MinimumDotPixels) * pathAlpha * (0.65 + 0.35 * chargeAlpha)
		) * (0.92 + 0.08 * gapScale)
		point.transparency = 1 - opacity * (0.5 + pathAlpha * 0.5)
		point.visible = onScreen and projected.Z > 0
		if index == displayPointCount and point.visible then
			endpoint = rawDisplay
		end
	end
	for index = displayPointCount + 1, POINT_COUNT do
		activePoints[index].visible = false
		lastScreenPoints[index] = nil
	end
	activeSnapshot.chargeAlpha = chargeAlpha
	activeSnapshot.endpoint = endpoint
	renderedActive = true
	if renderer then
		renderer(activeSnapshot)
	end
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		if renderedActive then
			renderEmpty()
		end
		return
	end
	local state = CombatState.getSnapshot()
	local charging = state.state == "Charging" and state.weapon == "Dodgeball" and state.holdsBall
	updateFov(camera, charging, state.chargeAlpha, dt)
	if not charging then
		pathValid = false
		physicsAccumulated = 0
		displayAccumulated = 0
		if renderedActive then
			renderEmpty()
		end
		return
	end

	local character = Players.LocalPlayer.Character
	if renderer == nil or character == nil then
		if renderedActive then
			renderEmpty()
		end
		return
	end
	physicsAccumulated += dt
	displayAccumulated += dt
	local physicsPeriod = 1 / ThrowUX.Trajectory.PhysicsUpdateHz
	local displayPeriod = 1 / ThrowUX.UpdateHz
	local rebuilt = false
	if not pathValid or physicsAccumulated >= physicsPeriod then
		physicsAccumulated %= physicsPeriod
		pathValid = rebuildWorldPath(character, state.chargeAlpha)
		rebuilt = pathValid
	end
	if not pathValid then
		if renderedActive then
			renderEmpty()
		end
		return
	end
	if rebuilt or displayAccumulated >= displayPeriod then
		displayAccumulated %= displayPeriod
		projectSnapshot(camera, character, state.chargeAlpha)
	end
end

function ChargeAim.setRenderer(value: ((Snapshot) -> ())?): () -> ()
	renderer = value
	pathValid = false
	return function()
		if renderer == value then
			renderer = nil
		end
	end
end

function ChargeAim.recentLaunchVelocity(rawAim: Vector3, charge: number?): Vector3?
	local cachedAim = latestRawAim
	local cachedVelocity = latestLaunchVelocity
	if cachedAim == nil or cachedVelocity == nil or os.clock() - latestLaunchAt > 0.12 or rawAim.Magnitude <= 1e-6 then
		return nil
	end
	if cachedAim:Dot(rawAim.Unit) < math.cos(math.rad(4)) then
		return nil
	end
	if math.abs(latestCharge - math.clamp(charge or 0, 0, 1)) > 0.1 then
		return nil
	end
	return cachedVelocity
end

function ChargeAim.start()
	if started then
		return
	end
	started = true
	connection = RunService.RenderStepped:Connect(update)
end

function ChargeAim.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	started = false
	pathValid = false
	displayPointCount = 0
	renderEmpty()
	if activeCamera ~= nil and chargeBaseFov ~= nil then
		activeCamera.FieldOfView = chargeBaseFov
	end
	chargeBaseFov = nil
	activeCamera = nil
	lastCamera = nil
	pathCharacter = nil
	pathTarget = nil
	latestLaunchVelocity = nil
	latestRawAim = nil
end

return ChargeAim
