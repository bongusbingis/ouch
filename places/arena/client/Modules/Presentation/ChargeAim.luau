--!strict

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Combat = require(Config:WaitForChild("Combat"))
local ThrowUX = require(Config:WaitForChild("ThrowUX"))
local AimDirector = require(script.Parent.Parent.Input.AimDirector)
local CombatState = require(script.Parent.CombatState)

local ChargeAim = {}

export type Dot = { position: Vector2, size: number, transparency: number, visible: boolean }
export type Snapshot = { active: boolean, chargeAlpha: number, points: { Dot }, endpoint: Vector2? }

local GRAVITY = Vector3.new(0, -Combat.Dodgeball.Gravity, 0)
local EMPTY: Snapshot = { active = false, chargeAlpha = 0, points = {}, endpoint = nil }
local started = false
local connection: RBXScriptConnection? = nil
local renderer: ((Snapshot) -> ())? = nil
local lastScreenPoints: { [number]: Vector2 } = {}
local accumulated = 0
local activeCamera: Camera? = nil
local chargeBaseFov: number? = nil

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.RespectCanCollide = true

local function releaseOrigin(character: Model): Vector3?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local offset = Combat.Dodgeball.OverhandReleaseRootOffset
	return (root.CFrame * CFrame.new(offset.x, offset.y, offset.z)).Position
end

local function positionAt(origin: Vector3, velocity: Vector3, time: number): Vector3
	return origin + velocity * time + 0.5 * GRAVITY * (time * time)
end

local function timeToImpact(origin: Vector3, velocity: Vector3, character: Model): number
	local preview = Combat.Dodgeball.Preview
	local maxTime = Combat.Dodgeball.MaxFlightTime
	local samples = math.max(preview.ImpactSamples, 2)
	local step = maxTime / samples
	raycastParams.FilterDescendantsInstances = { character }
	local previous = origin
	for index = 1, samples do
		local time = step * index
		local point = positionAt(origin, velocity, time)
		local segment = point - previous
		if segment.Magnitude > 1e-4 then
			local hit = Workspace:Raycast(previous, segment, raycastParams)
			if hit then
				local fraction = (hit.Position - previous).Magnitude / segment.Magnitude
				return step * (index - 1) + step * math.clamp(fraction, 0, 1)
			end
		end
		previous = point
	end
	return maxTime
end

local function renderEmpty()
	table.clear(lastScreenPoints)
	if renderer then
		renderer(EMPTY)
	end
end

local function updateFov(camera: Camera, charging: boolean, chargeAlpha: number, dt: number)
	charging = charging and not GuiService.ReducedMotionEnabled
	if camera ~= activeCamera then
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

local function buildSnapshot(camera: Camera, character: Model, chargeAlpha: number): Snapshot?
	local origin = releaseOrigin(character)
	local rawAim = AimDirector.currentAim()
	if origin == nil or rawAim.Magnitude <= 1e-6 then
		return nil
	end
	local speed = Combat.Dodgeball.ThrowSpeed * (1 + (Combat.Dodgeball.Charge.MaxSpeedScale - 1) * chargeAlpha)
	local velocity = rawAim.Unit * speed
	local flight = timeToImpact(origin, velocity, character)
	local pointCount = math.max(2, Combat.Dodgeball.Preview.Segments)
	local points: { Dot } = {}
	local endpoint: Vector2? = nil
	local viewport = camera.ViewportSize
	local opacity = ThrowUX.Trajectory.MinimumOpacity
		+ (ThrowUX.Trajectory.MaximumOpacity - ThrowUX.Trajectory.MinimumOpacity) * chargeAlpha
	for index = 1, pointCount do
		local time = ((index - 1) / (pointCount - 1)) * flight
		local projected, onScreen = camera:WorldToViewportPoint(positionAt(origin, velocity, time))
		local display = Vector2.new(projected.X, projected.Y)
		local previous = lastScreenPoints[index]
		if previous then
			display = previous:Lerp(display, ThrowUX.Trajectory.ScreenSmoothing)
		end
		lastScreenPoints[index] = display
		local pathAlpha = (index - 1) / (pointCount - 1)
		local size = ThrowUX.Trajectory.MinimumDotPixels
			+ (ThrowUX.Trajectory.MaximumDotPixels - ThrowUX.Trajectory.MinimumDotPixels)
				* pathAlpha
				* (0.65 + 0.35 * chargeAlpha)
		local visible = onScreen and projected.Z > 0
		table.insert(points, {
			position = Vector2.new(math.clamp(display.X, 0, viewport.X), math.clamp(display.Y, 0, viewport.Y)),
			size = size,
			transparency = 1 - opacity * (0.5 + pathAlpha * 0.5),
			visible = visible,
		})
		if index == pointCount and visible then
			endpoint = display
		end
	end
	return { active = true, chargeAlpha = chargeAlpha, points = points, endpoint = endpoint }
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local state = CombatState.getSnapshot()
	local charging = state.state == "Charging" and state.weapon == "Dodgeball" and state.holdsBall
	updateFov(camera, charging, state.chargeAlpha, dt)
	if not charging then
		if #lastScreenPoints > 0 then
			renderEmpty()
		end
		return
	end
	accumulated += dt
	if accumulated < 1 / ThrowUX.UpdateHz then
		return
	end
	accumulated %= 1 / ThrowUX.UpdateHz
	local character = Players.LocalPlayer.Character
	if renderer and character then
		renderer(buildSnapshot(camera, character, state.chargeAlpha) or EMPTY)
	end
end

function ChargeAim.setRenderer(value: ((Snapshot) -> ())?): () -> ()
	renderer = value
	return function()
		if renderer == value then
			renderer = nil
		end
	end
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
	renderEmpty()
	local camera = Workspace.CurrentCamera
	if camera and chargeBaseFov then
		camera.FieldOfView = chargeBaseFov
	end
	chargeBaseFov = nil
	activeCamera = nil
end

return ChargeAim
