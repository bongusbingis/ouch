--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local AimDirector = require(script.Parent.Parent.Input.AimDirector)
local CombatState = require(script.Parent.CombatState)

-- The arc shown while a throw is charging.
--
-- It predicts the same parabola the sim will fly, from the same root-relative
-- release origin the server launches from, so what the player sees is what they
-- get. Nothing reads it back: this is presentation, and the ball's real path is
-- decided server-side.
--
-- Three things keep it steady, and each was a visible problem before:
--
--   * The aim it draws from is smoothed, not the raw camera look vector. A beam
--     rebuilt every frame from unfiltered aim shimmers with each pixel of mouse
--     or finger noise, which reads as a broken effect rather than a noisy input.
--   * The arc stops where the ball would actually hit something, rather than
--     always running the full maximum flight time and burying itself in the
--     ground.
--   * Its instances are built once and reused. Destroying and recreating the
--     beam per press popped on every throw.
--
-- Charge comes from CombatState, so the arc is drawn for the throw that will
-- actually happen. It used to time its own hold and, below the tap threshold,
-- drew a lob -- an arc that then jumped discontinuously to the charged one part
-- way through every hold. There is no lob any more, and that jump is gone.

local ChargeAim = {}

local GRAVITY = Vector3.new(0, -Combat.Dodgeball.Gravity, 0)

local started = false
local camera: Camera? = nil
local previewGui: ScreenGui? = nil
local arcDots: { Frame } = {}

local baseFov: number? = nil
local lastScreenPoints: { [number]: Vector2 } = {}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.RespectCanCollide = true

local function build()
	if previewGui ~= nil and previewGui.Parent ~= nil then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChargeAimPreview"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	previewGui = gui

	for index = 1, Combat.Dodgeball.Preview.Segments do
		local dot = Instance.new("Frame")
		dot.Name = "ArcDot" .. index
		dot.Size = UDim2.fromOffset(8, 8)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		dot.BackgroundTransparency = 0.15
		dot.BorderSizePixel = 0
		dot.Visible = false
		dot.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 20, 20)
		stroke.Transparency = 0.5
		stroke.Thickness = 1
		stroke.Parent = dot

		local shine = Instance.new("Frame")
		shine.Name = "Shine"
		shine.Size = UDim2.fromScale(1, 1)
		shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		shine.BackgroundTransparency = 0.8
		shine.BorderSizePixel = 0
		shine.Parent = dot

		table.insert(arcDots, dot)
	end
end

local function releaseOrigin(character: Model): Vector3?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	-- The same offset the server launches from, so the preview cannot promise a
	-- path the throw will not take.
	local offset = Combat.Dodgeball.OverhandReleaseRootOffset
	return (root.CFrame * CFrame.new(offset.x, offset.y, offset.z)).Position
end

local function positionAt(origin: Vector3, velocity: Vector3, t: number): Vector3
	return origin + velocity * t + 0.5 * GRAVITY * (t * t)
end

-- How long the ball flies before it hits something, found by walking the
-- parabola in straight pieces. Exact enough for an aiming aid and far cheaper
-- than a swept test, and it is what stops the arc from disappearing through the
-- floor into the void below the map.
local function timeToImpact(origin: Vector3, velocity: Vector3, character: Model): number
	local config = Combat.Dodgeball.Preview
	local maxTime = Combat.Dodgeball.MaxFlightTime
	local samples = math.max(config.ImpactSamples, 2)
	local step = maxTime / samples

	raycastParams.FilterDescendantsInstances = { character }

	local previous = origin
	for index = 1, samples do
		local t = step * index
		local point = positionAt(origin, velocity, t)
		local segment = point - previous
		if segment.Magnitude > 1e-4 then
			local hit = Workspace:Raycast(previous, segment, raycastParams)
			if hit then
				-- Interpolate within the piece that hit so the endpoint sits on
				-- the surface rather than snapping to the sample boundary, which
				-- would make the arc length visibly quantise as the player aims.
				local fraction = (hit.Position - previous).Magnitude / segment.Magnitude
				return step * (index - 1) + step * math.clamp(fraction, 0, 1)
			end
		end
		previous = point
	end
	return maxTime
end

local function hide()
	if previewGui ~= nil then
		previewGui.Enabled = false
	end
	for _, dot in ipairs(arcDots) do
		dot.Visible = false
	end
end

local function update(dt: number)
	local current = Workspace.CurrentCamera
	camera = current
	if current == nil then
		return
	end

	if previewGui == nil then
		build()
	end
	if previewGui ~= nil then
		previewGui.Enabled = true
	end

	local config = Combat.Dodgeball.Preview
	if baseFov == nil then
		baseFov = current.FieldOfView
	end

	local snapshot = CombatState.getSnapshot()
	local charging = snapshot.state == "Charging" and snapshot.weapon == "Dodgeball"

	-- Default FOV is 90 and aim-down-sight is a relative -15 offset from the
	-- current camera view. The blend is tiny and only handles the visual delta,
	-- so the camera motion remains responsive while the view does not chatter.
	local hitFov = if charging then -15 else 0
	local resolvedBase = baseFov or 90
	local targetFov = math.clamp(resolvedBase + hitFov, 1, 120)
	local fovBlend = 1 - math.exp(-dt * 18)
	current.FieldOfView = current.FieldOfView + (targetFov - current.FieldOfView) * fovBlend

	local character = Players.LocalPlayer.Character
	if not charging or character == nil then
		hide()
		return
	end

	local origin = releaseOrigin(character)
	local rawAim = AimDirector.currentAim()
	if origin == nil or typeof(rawAim) ~= "Vector3" or rawAim.Magnitude <= 1e-6 then
		hide()
		return
	end
	rawAim = rawAim.Unit

	if rawAim.Magnitude <= 1e-4 then
		hide()
		return
	end
	local aim = rawAim.Unit

	local speed = Combat.Dodgeball.ThrowSpeed * (1 + (Combat.Dodgeball.Charge.MaxSpeedScale - 1) * snapshot.chargeAlpha)
	local velocity = aim * speed
	local flight = timeToImpact(origin, velocity, character)

	local predicted = {}
	local sampleCount = math.max(2, #arcDots)
	for index = 0, sampleCount - 1 do
		local t = (index / (sampleCount - 1)) * flight
		local point = positionAt(origin, velocity, t)
		table.insert(predicted, point)
	end

	for index, point in ipairs(predicted) do
		local dot = arcDots[index]
		if dot == nil then
			break
		end

		local screenPoint = current:WorldToScreenPoint(point)
		if screenPoint.Z < 0 then
			dot.Visible = false
			continue
		end

		local previous = lastScreenPoints[index]
		local displayPoint = screenPoint
		if previous ~= nil then
			displayPoint = previous:Lerp(screenPoint, 0.45)
		end
		lastScreenPoints[index] = displayPoint

		local viewport = current.ViewportSize
		local clampedX = math.clamp(displayPoint.X, 0, viewport.X)
		local clampedY = math.clamp(displayPoint.Y, 0, viewport.Y)
		local alpha = 0.25 + ((index - 1) / math.max(1, #predicted - 1)) * 0.75
		local size = 4 + alpha * 8

		dot.Position = UDim2.fromOffset(clampedX, clampedY)
		dot.Size = UDim2.fromOffset(size, size)
		dot.BackgroundTransparency = math.clamp(1 - alpha, 0.1, 0.9)
		dot.Visible = true
	end

	for index = #predicted + 1, #arcDots do
		arcDots[index].Visible = false
	end
	for index = #predicted + 1, #lastScreenPoints do
		lastScreenPoints[index] = nil
	end
end

function ChargeAim.start()
	if started then
		return
	end
	started = true

	build()
	RunService.RenderStepped:Connect(update)
end

function ChargeAim.stop()
	hide()
end

return ChargeAim
